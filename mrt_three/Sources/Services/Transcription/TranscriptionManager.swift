import Foundation
import Combine

/// Resultado do processamento de transcrição
private enum TranscriptionProcessResult {
    case success
    case failed
    case cancelled
}

/// Gerenciador principal de transcrições com sistema de fila FIFO
class TranscriptionManager: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var tasks: [TranscriptionTask] = []
    @Published var isProcessing: Bool = false
    @Published var currentTask: TranscriptionTask?
    
    // MARK: - Private Properties
    
    private let audioConverter = UnifiedAudioConverter()
    private let transcriptionEngine = SimpleTranscriptionEngine()
    private let logger = LoggingService.shared
    private let fileManager = FileManager.default
    
    // Queue management
    private let processingQueue = DispatchQueue(label: "transcription.processing", qos: .userInitiated)
    private var cancellables = Set<AnyCancellable>()
    
    // Configuration
    private let maxConcurrentTasks = 1 // Process one at a time for stability
    private let transcriptionResultsDirectory: String
    
    // MARK: - Initialization
    
    init() {
        // Setup results directory
        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
        transcriptionResultsDirectory = (documentsPath as NSString).appendingPathComponent("TranscriptionResults")
        createResultsDirectoryIfNeeded()
        
        logger.info("TranscriptionManager initialized", category: .general)
        setupTaskProcessing()
    }
    
    // MARK: - Public Methods
    
    /// Reset do estado de processamento (debug)
    func resetProcessingState() {
        logger.debug("Resetando estado de processamento (debug)", category: .general)
        DispatchQueue.main.async {
            self.isProcessing = false
            self.currentTask = nil
        }
    }
    
    /// Adiciona nova tarefa de transcrição à fila
    /// - Parameters:
    ///   - meetingId: ID da reunião
    ///   - audioFilePath: Caminho do arquivo de áudio (_combined.m4a)
    /// - Returns: ID da tarefa criada
    @discardableResult
    func enqueueTranscription(for meetingId: UUID, audioFilePath: String) -> UUID {
        print("[CONSOLE] 🔄 TranscriptionManager.enqueueTranscription CHAMADO")
        logger.info("Enqueuing transcription task", category: .general)
        print("[CONSOLE] Meeting ID: \(meetingId), Audio: \(audioFilePath)")
        logger.debug("Meeting ID: \(meetingId), Audio: \(audioFilePath)", category: .general)
        
        // Verificar se arquivo existe
        print("[CONSOLE] Verificando se arquivo existe: \(audioFilePath)")
        guard fileManager.fileExists(atPath: audioFilePath) else {
            print("[CONSOLE] ❌ ARQUIVO NÃO EXISTE!")
            logger.error("Audio file does not exist: \(audioFilePath)", category: .general)
            return UUID() // Retorna ID vazio para indicar falha
        }
        print("[CONSOLE] ✅ Arquivo existe")
        
        // Verificar se já existe tarefa para esta reunião
        print("[CONSOLE] Verificando tarefas existentes...")
        if let existingTask = tasks.first(where: { $0.meetingId == meetingId && $0.isActive }) {
            print("[CONSOLE] ⚠️ Tarefa já existe para esta reunião")
            logger.warning("Transcription task already exists for meeting: \(meetingId)", category: .general)
            return existingTask.id
        }
        
        print("[CONSOLE] Criando nova tarefa...")
        // Criar nova tarefa
        let task = TranscriptionTask(meetingId: meetingId, inputAudioPath: audioFilePath)
        
        print("[CONSOLE] Adicionando tarefa à lista...")
        DispatchQueue.main.async {
            self.tasks.append(task)
            self.objectWillChange.send()
            
            print("[CONSOLE] ✅ Tarefa adicionada à lista. Total de tarefas: \(self.tasks.count)")
            
            // Iniciar processamento se não estiver processando
            print("[CONSOLE] Verificando se deve iniciar processamento...")
            print("[CONSOLE] isProcessing: \(self.isProcessing)")
            if !self.isProcessing {
                print("[CONSOLE] 🚀 Iniciando processamento...")
                self.startProcessing()
            } else {
                print("[CONSOLE] ⏳ Já está processando, não iniciando novo processamento")
            }
        }
        
        print("[CONSOLE] ✅ Tarefa enfileirada: \(task.id.uuidString)")
        logger.info("Transcription task enqueued: \(task.id.uuidString) for meeting \(meetingId.uuidString)", category: .general)
        
        return task.id
    }
    
    /// Cancela tarefa de transcrição
    /// - Parameter taskId: ID da tarefa a cancelar
    func cancelTask(_ taskId: UUID) {
        logger.info("Cancelling transcription task: \(taskId)", category: .general)
        
        guard let index = tasks.firstIndex(where: { $0.id == taskId }) else {
            logger.warning("Task not found for cancellation: \(taskId)", category: .general)
            return
        }
        
        var task = tasks[index]
        
        if task.status == .processing {
            logger.info("Cancelling task currently being processed: \(taskId.uuidString)", category: .general)
            
            // Cancelar tarefa no motor de transcrição
            transcriptionEngine.cancelTask(taskId)
            
            // Marcar como cancelada - será atualizada quando o processamento terminar
            task.status = .cancelled
            task.completedAt = Date()
            
            DispatchQueue.main.async {
                self.tasks[index] = task
                self.objectWillChange.send()
            }
            
            logger.info("Processing task cancellation initiated: \(taskId.uuidString)", category: .general)
            return
        }
        
        task.status = .cancelled
        task.completedAt = Date()
        
        DispatchQueue.main.async {
            self.tasks[index] = task
            self.objectWillChange.send()
        }
        
        logger.info("Transcription task cancelled: \(taskId)", category: .general)
    }
    
    /// Remove tarefa concluída da lista
    /// - Parameter taskId: ID da tarefa a remover
    func removeTask(_ taskId: UUID) {
        guard let index = tasks.firstIndex(where: { $0.id == taskId }) else { return }
        
        let task = tasks[index]
        
        // Só remove se estiver concluída, falhada ou cancelada
        guard task.isCompleted else {
            logger.warning("Cannot remove active task: \(taskId)", category: .general)
            return
        }
        
        DispatchQueue.main.async {
            self.tasks.remove(at: index)
            self.objectWillChange.send()
        }
        
        logger.info("Transcription task removed: \(taskId)", category: .general)
    }
    
    /// Obter resultado de transcrição para uma reunião
    /// - Parameter meetingId: ID da reunião
    /// - Returns: Resultado da transcrição ou nil se não encontrado
    func getTranscriptionResult(for meetingId: UUID) -> TranscriptionResult? {
        logger.debug("TranscriptionManager.getTranscriptionResult() called for meeting: \(meetingId)", category: .general)
        let resultPath = getResultPath(for: meetingId)
        logger.debug("Looking for result at path: \(resultPath)", category: .general)
        
        guard fileManager.fileExists(atPath: resultPath) else {
            logger.debug("ERROR: Result file does not exist", category: .general)
            return nil
        }
        logger.debug("Result file exists, attempting to decode...", category: .general)
        
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: resultPath))
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(TranscriptionResult.self, from: data)
        } catch {
            logger.error("Failed to load transcription result", error: error, category: .general)
            return nil
        }
    }
    
    /// Verifica se existe transcrição para uma reunião
    /// - Parameter meetingId: ID da reunião
    /// - Returns: True se existe transcrição
    func hasTranscription(for meetingId: UUID) -> Bool {
        return getTranscriptionResult(for: meetingId) != nil
    }
    
    /// Obter progresso da fila de transcrições
    var queueProgress: (current: Int, total: Int) {
        let activeTasks = tasks.filter { $0.isActive }
        let currentIndex = activeTasks.firstIndex { $0.status == .processing } ?? 0
        return (currentIndex + 1, activeTasks.count)
    }
    
    // MARK: - Private Methods
    
    private func setupTaskProcessing() {
        // Monitor mudanças na fila para iniciar processamento
        $tasks
            .debounce(for: .milliseconds(100), scheduler: DispatchQueue.main)
            .sink { [weak self] tasks in
                self?.checkAndStartProcessing()
            }
            .store(in: &cancellables)
    }
    
    private func checkAndStartProcessing() {
        guard !isProcessing else { return }
        
        let queuedTasks = tasks.filter { $0.status == .queued }
        if !queuedTasks.isEmpty {
            startProcessing()
        }
    }
    
    private func startProcessing() {
        print("[CONSOLE] 🚀 startProcessing() CHAMADO")
        logger.debug("startProcessing() called, isProcessing: \(isProcessing)", category: .general)
        print("[CONSOLE] isProcessing atual: \(isProcessing)")
        guard !isProcessing else { 
            print("[CONSOLE] ⏸️ Já está processando, retornando")
            logger.debug("Already processing, returning", category: .general)
            return 
        }
        
        print("[CONSOLE] ✅ Definindo isProcessing = true")
        logger.debug("Setting isProcessing to true", category: .general)
        DispatchQueue.main.async {
            self.isProcessing = true
        }
        
        logger.debug("Dispatching processNextTask to processing queue", category: .general)
        print("[CONSOLE] 📤 Dispatching processNextTask para a fila de processamento")
        processingQueue.async {
            print("[CONSOLE] 🔄 processNextTask executando na fila de processamento")
            self.processNextTask()
        }
    }
    
    private func processNextTask() {
        print("[CONSOLE] 🎯 processNextTask() CHAMADO")
        logger.debug("processNextTask() called", category: .general)
        print("[CONSOLE] Current tasks count: \(tasks.count)")
        logger.debug("Current tasks count: \(tasks.count)", category: .general)
        
        // Encontrar próxima tarefa na fila
        print("[CONSOLE] 🔍 Procurando tarefas enfileiradas...")
        logger.debug("Looking for queued tasks...", category: .general)
        for (index, task) in tasks.enumerated() {
            print("[CONSOLE] Task \(index): id=\(task.id.uuidString.prefix(8)), status=\(task.status)")
            logger.debug("Task \(index): id=\(task.id.uuidString.prefix(8)), status=\(task.status)", category: .general)
        }
        
        guard let taskIndex = tasks.firstIndex(where: { $0.status == .queued }) else {
            print("[CONSOLE] ❌ Nenhuma tarefa enfileirada encontrada, parando processamento")
            logger.info("🔄 [DEBUG] No queued tasks found, stopping processing", category: .general)
            logger.debug("No queued tasks found, stopping processing", category: .general)
            DispatchQueue.main.async {
                self.isProcessing = false
                self.currentTask = nil
            }
            return
        }
        
        print("[CONSOLE] ✅ Tarefa enfileirada encontrada no índice: \(taskIndex)")
        
        logger.debug("Found queued task at index \(taskIndex)", category: .general)
        
        logger.info("🔄 [DEBUG] Found queued task at index: \(taskIndex)", category: .general)
        
        var task = tasks[taskIndex]
        print("[CONSOLE] 📝 Recuperando tarefa: \(task.id.uuidString.prefix(8))")
        logger.debug("Retrieved task: \(task.id.uuidString.prefix(8))", category: .general)
        
        // Marcar como processando
        print("[CONSOLE] 🔄 Marcando tarefa como 'processing'")
        task.status = .processing
        task.startedAt = Date()
        logger.debug("Marked task as processing", category: .general)
        
        DispatchQueue.main.async {
            self.tasks[taskIndex] = task
            self.currentTask = task
            self.objectWillChange.send()
        }
        logger.debug("Updated task status in main queue", category: .general)
        
        print("[CONSOLE] 🚀 Iniciando processamento da transcrição...")
        logger.info("Starting transcription processing for task \(task.id.uuidString), meeting \(task.meetingId.uuidString)", category: .general)
        logger.debug("Starting actual transcription processing...", category: .general)
        
        // Processar tarefa
        print("[CONSOLE] 📤 Criando Task assíncrona para processTranscriptionTask")
        Task {
            print("[CONSOLE] 🎯 processTranscriptionTask iniciando...")
            let result = await processTranscriptionTask(task)
            print("[CONSOLE] ✅ processTranscriptionTask concluído com resultado: \(result)")
            
            // Atualizar status baseado no resultado
            var updatedTask = self.tasks[taskIndex]
            updatedTask.completedAt = Date()
            
            switch result {
            case .success:
                updatedTask.status = .completed
                updatedTask.progress = 1.0
            case .cancelled:
                updatedTask.status = .cancelled
                updatedTask.progress = 0.0
                updatedTask.errorMessage = "Tarefa cancelada pelo usuário"
            case .failed:
                updatedTask.status = .failed
                updatedTask.progress = 0.0
            }
            
            DispatchQueue.main.async {
                self.tasks[taskIndex] = updatedTask
                self.objectWillChange.send()
            }
            
            // Processar próxima tarefa
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.processNextTask()
            }
        }
    }
    
    private func processTranscriptionTask(_ task: TranscriptionTask) async -> TranscriptionProcessResult {
        print("[CONSOLE] 🎯 processTranscriptionTask EXECUTANDO")
        logger.debug("processTranscriptionTask() called", category: .general)
        print("[CONSOLE] Task ID: \(task.id)")
        logger.info("🔄 [DEBUG] Processing transcription task: \(task.id)", category: .general)
        print("[CONSOLE] Input audio path: \(task.inputAudioPath)")
        logger.info("🔄 [DEBUG] Input audio path: \(task.inputAudioPath)", category: .general)
        logger.debug("Input audio path: \(task.inputAudioPath)", category: .general)
        
        // Etapa 1: Converter M4A para WAV
        print("[CONSOLE] 🔄 Iniciando conversão de áudio M4A → WAV")
        logger.info("🔄 [DEBUG] Starting audio conversion...", category: .general)
        logger.debug("Starting audio conversion...", category: .general)
        updateTaskProgress(task.id, progress: 0.1, message: "Convertendo áudio...")
        logger.debug("Task progress updated to 0.1", category: .general)
        
        print("[CONSOLE] 📞 Chamando audioConverter.convertM4AToWAV...")
        logger.debug("Calling audioConverter.convertM4AToWAV...", category: .general)
        let wavPath: String
        do {
            wavPath = try await audioConverter.convertM4AToWAV(
                inputPath: task.inputAudioPath,
                strategy: .ffmpeg
            )
            print("[CONSOLE] ✅ Conversão bem-sucedida: \(wavPath)")
            logger.debug("audioConverter.convertM4AToWAV returned: \(wavPath)", category: .general)
            logger.info("🔄 [DEBUG] Audio conversion successful: \(wavPath)", category: .general)
            logger.debug("Audio conversion successful, continuing to transcription...", category: .general)
        } catch {
            print("[CONSOLE] ❌ CONVERSÃO FALHOU: \(error)")
            logger.error("🔄 [DEBUG] Failed to convert audio file: \(error)", category: .general)
            logger.debug("ERROR: convertM4AToWAV failed with error: \(error)", category: .general)
            updateTaskError(task.id, error: "Falha na conversão do áudio: \(error.localizedDescription)")
            return .failed
        }
        
        defer {
            // Limpar arquivo temporário WAV
            try? FileManager.default.removeItem(atPath: wavPath)
        }
        
        print("[CONSOLE] 🎵 Arquivo WAV criado com sucesso: \(wavPath)")
        logger.info("Audio converted successfully: \(wavPath)", category: .general)
        logger.debug("Updating task progress to 0.2...", category: .general)
        updateTaskProgress(task.id, progress: 0.2, message: "Iniciando transcrição...")
        
        // Etapa 2: Executar transcrição
        print("[CONSOLE] 🤖 Iniciando transcrição com SimpleTranscriptionEngine...")
        logger.debug("Starting transcription with engine...", category: .general)
        
        let result: TranscriptionResult?
        do {
            print("[CONSOLE] 📞 Chamando transcriptionEngine.transcribe...")
            result = try await transcriptionEngine.transcribe(audioFile: wavPath, taskId: task.id, progressCallback: { [weak self] progress in
                // Callback de progresso (20% a 90%)
                let mappedProgress = 0.2 + (progress * 0.7)
                print("[CONSOLE] 📊 Progresso da transcrição: \(progress) -> \(mappedProgress)")
                self?.logger.debug("Transcription progress: \(progress) -> \(mappedProgress)", category: .general)
                self?.updateTaskProgress(task.id, progress: mappedProgress, message: "Transcrevendo áudio...")
            })
            print("[CONSOLE] ✅ Transcrição concluída com sucesso!")
        } catch TranscriptionError.taskCancelled {
            print("[CONSOLE] ⏹️ Transcrição cancelada")
            logger.info("Transcription task was cancelled during execution: \(task.id.uuidString)", category: .general)
            return .cancelled
        } catch {
            print("[CONSOLE] ❌ TRANSCRIÇÃO FALHOU: \(error)")
            logger.error("Transcription failed with error: \(error)", category: .general)
            updateTaskError(task.id, error: "Erro na transcrição: \(error.localizedDescription)")
            return .failed
        }
        
        guard let transcriptionResult = result else {
            logger.error("Transcription failed - engine returned nil", category: .general)
            logger.debug("ERROR: Transcription engine returned nil", category: .general)
            updateTaskError(task.id, error: "Falha na transcrição")
            return .failed
        }
        
        // Etapa 3: Salvar resultado
        logger.debug("Transcription successful, saving result...", category: .general)
        updateTaskProgress(task.id, progress: 0.95, message: "Salvando resultado...")
        
        let resultPath = getResultPath(for: task.meetingId)
        let success = saveTranscriptionResult(transcriptionResult, to: resultPath)
        
        if success {
            updateTaskProgress(task.id, progress: 1.0, message: "Concluído")
            logger.info("Transcription completed successfully for task \(task.id.uuidString): \(transcriptionResult.segments.count) segments, \(transcriptionResult.summary.totalDuration)s duration", category: .general)
            logger.debug("SUCCESS: Transcription task completed successfully", category: .general)
            return .success
        } else {
            logger.error("Failed to save transcription result", category: .general)
            logger.debug("ERROR: Failed to save transcription result", category: .general)
            updateTaskError(task.id, error: "Falha ao salvar resultado")
            return .failed
        }
    }
    
    private func updateTaskProgress(_ taskId: UUID, progress: Double, message: String? = nil) {
        DispatchQueue.main.async {
            if let index = self.tasks.firstIndex(where: { $0.id == taskId }) {
                self.tasks[index].progress = progress
                self.objectWillChange.send()
            }
        }
        
        if let message = message {
            logger.debug("Task \(taskId): \(message) (\(Int(progress * 100))%)", category: .general)
        }
    }
    
    private func updateTaskError(_ taskId: UUID, error: String) {
        DispatchQueue.main.async {
            if let index = self.tasks.firstIndex(where: { $0.id == taskId }) {
                self.tasks[index].errorMessage = error
                self.objectWillChange.send()
            }
        }
    }
    
    private func saveTranscriptionResult(_ result: TranscriptionResult, to path: String) -> Bool {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            
            let data = try encoder.encode(result)
            try data.write(to: URL(fileURLWithPath: path))
            
            logger.info("Transcription result saved: \(path)", category: .general)
            return true
        } catch {
            logger.error("Failed to save transcription result", error: error, category: .general)
            return false
        }
    }
    
    private func getResultPath(for meetingId: UUID) -> String {
        return (transcriptionResultsDirectory as NSString).appendingPathComponent("\(meetingId.uuidString).json")
    }
    
    private func createResultsDirectoryIfNeeded() {
        do {
            try fileManager.createDirectory(
                atPath: transcriptionResultsDirectory,
                withIntermediateDirectories: true,
                attributes: nil
            )
            logger.debug("Transcription results directory created: \(transcriptionResultsDirectory)", category: .general)
        } catch {
            logger.error("Failed to create results directory", error: error, category: .general)
        }
    }
}