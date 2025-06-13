import Foundation
import Combine
import SwiftUI

// LoggingService for unified logging
private let logger = LoggingService.shared

@MainActor
class MeetingStore: ObservableObject {
    @Published var meetings: [Meeting] = []
    @Published var currentMeeting: Meeting?
    @Published var searchText = ""
    @Published var lastCompletedMeeting: Meeting? // Para navegação automática
    @Published var useCoreAudioTap: Bool = false // Core Audio Tap via XPC + Helper Tool
    @Published var helperToolStatus: HelperInstallationStatus? // Status da Helper Tool
    
    // MARK: - Audio State (Delegated to AudioRecordingCoordinator)
    // Estas propriedades são observadas do AudioRecordingCoordinator
    var isRecording: Bool { audioService?.isRecording ?? false }
    var isPaused: Bool { audioService?.isPaused ?? false }
    var currentDuration: TimeInterval { audioService?.currentDuration ?? 0 }
    var audioLevel: Float { audioService?.audioLevel ?? 0.0 }
    var errorMessage: String? { audioService?.errorMessage }
    var availableInputDevices: [AudioDevice] { audioService?.availableInputDevices ?? [] }
    var selectedInputDevice: AudioDevice? { audioService?.selectedInputDevice }
    var systemAudioAvailable: Bool { audioService?.systemAudioAvailable ?? false }
    var systemAudioEnabled: Bool { audioService?.systemAudioEnabled ?? true }
    
    private let dataManager = DataManager()
    
    // 🔧 CORREÇÃO: Usar instância injetada em vez de criar nova
    private var audioService: AudioRecordingCoordinator!
    
    // 🔧 NOVO: Gerenciador de transcrição
    private let transcriptionManager = TranscriptionManager()
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        logger.debug("🚀 MeetingStore init iniciado", category: .memory)
        
        // Não fazer nada pesado no init - deixar para onAppear ou initialize()
        logger.debug("✅ MeetingStore init concluído (sem carregamento)", category: .memory)
    }
    
    // MARK: - Initialization Methods
    
    /// Inicializar store de forma assíncrona e segura
    func initializeAsync() {
        logger.debug("🔄 MeetingStore inicialização assíncrona iniciada", category: .general)
        
        Task { @MainActor in
            loadMeetings()
            logger.debug("✅ MeetingStore inicialização assíncrona concluída", category: .general)
        }
    }
    
    // 🔧 NOVO: Método para injetar o audioService
    func setAudioService(_ audioService: AudioRecordingCoordinator) {
        self.audioService = audioService
        setupBindings()
        refreshAudioDevices()
        
        // Inicializar o audioService
        Task {
            await audioService.initialize()
        }
    }
    
    // MARK: - State Management (Simplified - Single Source of Truth)
    
    private func setupBindings() {
        guard let audioService = audioService else {
            logger.warning("audioService não está disponível para setupBindings", category: .general)
            return
        }
        
        // STATE MANAGEMENT PRINCIPAL: Debounce para evitar updates excessivos
        dataManager.$meetings
            .debounce(for: .milliseconds(100), scheduler: DispatchQueue.main)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newMeetings in
                guard let self = self else { return }
                
                // Comparar se realmente mudou antes de atualizar
                if !self.areMeetingsEqual(self.meetings, newMeetings) {
                    self.meetings = newMeetings
                    self.objectWillChange.send()
                }
            }
            .store(in: &cancellables)
        
        // 🔧 CORREÇÃO: Observar mudanças no AudioService para atualizar UI de forma segura
        audioService.$isRecording
            .debounce(for: .milliseconds(50), scheduler: DispatchQueue.main)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
        
        audioService.$currentDuration
            .debounce(for: .milliseconds(100), scheduler: DispatchQueue.main)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
        
        audioService.$errorMessage
            .receive(on: DispatchQueue.main)
            .removeDuplicates()
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }
    
    private func areMeetingsEqual(_ lhs: [Meeting], _ rhs: [Meeting]) -> Bool {
        guard lhs.count == rhs.count else { return false }
        
        for i in 0..<lhs.count {
            if lhs[i].id != rhs[i].id ||
               lhs[i].status != rhs[i].status ||
               lhs[i].audioFilePath != rhs[i].audioFilePath ||
               lhs[i].duration != rhs[i].duration {
                return false
            }
        }
        
        return true
    }
    
    private func loadMeetings() {
        // DataManager já carrega as reuniões automaticamente
    }
    
    // MARK: - Data Refresh
    
    func refreshData() {
        dataManager.refreshMeetings()
        refreshAudioDevices()
    }
    
    func refreshAudioDevices() {
        audioService?.loadAvailableDevices()
    }
    
    // MARK: - Audio Device Management
    
    func selectInputDevice(_ device: AudioDevice) {
        audioService?.selectInputDevice(device)
    }
    
    // MARK: - System Audio Control
    
    func setSystemAudioEnabled(_ enabled: Bool) {
        audioService?.setSystemAudioEnabled(enabled)
    }
    
    // MARK: - Recording Actions
    
    func startNewRecording() {
        let meeting = Meeting()
        currentMeeting = meeting
        dataManager.saveMeeting(meeting)
        
        Task {
            // Aplicar estratégia de captura baseada no checkbox
            applyAudioCaptureStrategy()
            
            let success = await audioService.startRecording(for: meeting)
            if success {
                updateMeetingStatus(meeting.id, status: .recording)
            } else {
                currentMeeting = nil
            }
        }
    }
    
    /// Iniciar nova gravação com workflow completo para UI
    /// - Parameters:
    ///   - onSuccess: Callback executado quando gravação inicia com sucesso
    ///   - onFailure: Callback executado quando gravação falha
    func startNewRecordingWorkflow(
        onSuccess: @escaping (Meeting) -> Void = { _ in },
        onFailure: @escaping () -> Void = {}
    ) {
        Task {
            // Criar nova reunião
            let meeting = Meeting()
            currentMeeting = meeting
            dataManager.saveMeeting(meeting)
            
            // Aplicar estratégia de captura baseada no checkbox
            applyAudioCaptureStrategy()
            
            // Aguardar reunião ser criada e tentar iniciar gravação
            for _ in 0..<50 {
                if let currentMeeting = currentMeeting {
                    let success = await audioService.startRecording(for: currentMeeting)
                    if success {
                        updateMeetingStatus(currentMeeting.id, status: .recording)
                        await MainActor.run {
                            onSuccess(currentMeeting)
                        }
                        return
                    } else {
                        // Falha ao iniciar gravação
                        self.currentMeeting = nil
                        await MainActor.run {
                            onFailure()
                        }
                        return
                    }
                }
                
                // Aguardar um pouco antes de tentar novamente
                try? await Task.sleep(nanoseconds: 100_000_000)
            }
            
            // Timeout - não conseguiu criar reunião
            currentMeeting = nil
            await MainActor.run {
                onFailure()
            }
        }
    }
    
    func pauseRecording() {
        guard let meeting = currentMeeting else { return }
        audioService.pauseRecording()
        updateMeetingStatus(meeting.id, status: .paused)
    }
    
    func resumeRecording() {
        guard let meeting = currentMeeting else { return }
        audioService.resumeRecording()
        updateMeetingStatus(meeting.id, status: .recording)
    }
    
    func stopRecording() async -> Meeting? {
        guard let meeting = currentMeeting else { return nil }
        
        let result = await audioService.stopRecording()
        
        // Atualizar reunião
        if let audioPath = result.audioPath {
            dataManager.updateMeetingAudioPath(for: meeting.id, audioPath: audioPath)
        }
        
        dataManager.updateMeetingDuration(for: meeting.id, duration: result.duration)
        updateMeetingStatus(meeting.id, status: .completed)
        
        currentMeeting = nil
        
        // NAVEGAÇÃO AUTOMÁTICA: Buscar reunião atualizada para navegação
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self else { return }
            
            if let updatedMeeting = self.meetings.first(where: { $0.id == meeting.id }) {
                self.lastCompletedMeeting = updatedMeeting
            }
        }
        
        // Retornar reunião temporária para navegação imediata
        var tempMeeting = meeting
        tempMeeting.status = .completed
        tempMeeting.duration = result.duration
        if let audioPath = result.audioPath {
            tempMeeting.audioFilePath = audioPath
        }
        
        return tempMeeting
    }
    
    // MARK: - Meeting Management
    
    func deleteMeeting(_ meeting: Meeting) async {
        if meeting.id == currentMeeting?.id {
            _ = await stopRecording()
        }
        dataManager.deleteMeeting(meeting)
    }
    
    func deleteAudioArtifacts(for meeting: Meeting) {
        dataManager.deleteAudioArtifacts(for: meeting)
    }
    
    func updateMeetingTitle(_ meetingId: UUID, newTitle: String) {
        dataManager.updateMeetingTitle(for: meetingId, newTitle: newTitle)
    }
    
    func updateMeetingNotes(_ meetingId: UUID, notes: String) {
        dataManager.updateMeetingNotes(for: meetingId, notes: notes)
    }
    
    private func updateMeetingStatus(_ meetingId: UUID, status: MeetingStatus) {
        dataManager.updateMeetingStatus(for: meetingId, status: status)
    }
    
    // MARK: - Search and Filtering
    
    var filteredMeetings: [Meeting] {
        if searchText.isEmpty {
            return meetings
        } else {
            return dataManager.searchMeetings(query: searchText)
        }
    }
    
    func getRecentMeetings(limit: Int = 5) -> [Meeting] {
        return dataManager.getRecentMeetings(limit: limit)
    }
    
    // MARK: - Export
    
    func exportMeeting(_ meeting: Meeting, to url: URL) throws {
        try dataManager.exportMeeting(meeting, to: url)
    }
    
    // MARK: - Utility
    
    func getAudioFileSize(for meeting: Meeting) -> String {
        return dataManager.getAudioFileSize(for: meeting)
    }
    
    func getTotalRecordingTime() -> TimeInterval {
        return dataManager.getTotalRecordingTime()
    }
    
    func getMeetingsCount() -> Int {
        return dataManager.getMeetingsCount()
    }
    
    var currentRecordingDurationFormatted: String {
        // 🔧 CORREÇÃO: Usar formatação centralizada do Meeting
        return TimeInterval.formatDuration(currentDuration)
    }
    
    var hasActiveRecording: Bool {
        return currentMeeting != nil && (isRecording || isPaused)
    }
    
    func clearError() {
        audioService?.errorMessage = nil
    }
    
    func clearLastCompletedMeeting() {
        lastCompletedMeeting = nil
    }
    
    // MARK: - Transcription Management
    
    /// Iniciar transcrição de uma reunião
    /// - Parameter meeting: Reunião para transcrever
    /// - Returns: ID da tarefa de transcrição
    @discardableResult
    func startTranscription(for meeting: Meeting) -> UUID? {
        print("[CONSOLE] === MÉTODO startTranscription CHAMADO ===")
        logger.debug("[MeetingStore] === MÉTODO startTranscription CHAMADO ===", category: .general)
        print("[CONSOLE] Meeting ID: \(meeting.id)")
        logger.debug("[MeetingStore] Meeting ID: \(meeting.id)", category: .general)
        print("[CONSOLE] Audio file path: \(meeting.audioFilePath ?? "nil")")
        logger.debug("[MeetingStore] Audio file path: \(meeting.audioFilePath ?? "nil")", category: .general)
        print("[CONSOLE] isTranscribing atual: \(isTranscribing)")
        logger.debug("[MeetingStore] isTranscribing atual: \(isTranscribing)", category: .general)
        print("[CONSOLE] transcriptionManager existe: SIM")
        print("[CONSOLE] transcriptionManager.tasks count: \(transcriptionManager.tasks.count)")
        
        // Debug: resetar estado se estiver travado sem tarefas ativas
        if isTranscribing && transcriptionManager.tasks.filter({ $0.isActive }).isEmpty {
            print("[CONSOLE] Estado travado detectado, resetando...")
            logger.debug("[MeetingStore] Estado travado detectado, resetando...", category: .general)
            transcriptionManager.resetProcessingState()
        }
        
        print("[CONSOLE] Verificando audioPath...")
        // Verificar se reunião tem áudio combinado (único formato aceito para transcrição)
        guard let audioPath = meeting.audioFilePath,
              audioPath.hasSuffix("_combined.m4a") else {
            print("[CONSOLE] ❌ GUARD FALHOU - audioPath inválido")
            print("[CONSOLE] audioFilePath: \(meeting.audioFilePath ?? "nil")")
            print("[CONSOLE] hasSuffix _combined.m4a: \(meeting.audioFilePath?.hasSuffix("_combined.m4a") ?? false)")
            logger.error("[MeetingStore] Reunião não possui arquivo de áudio combinado válido para transcrição. Arquivo atual: \(meeting.audioFilePath ?? "nil")", category: .general)
            logger.error("[MeetingStore] Apenas arquivos _combined.m4a podem ser transcritos", category: .general)
            return nil
        }
        
        print("[CONSOLE] ✅ AudioPath válido: \(audioPath)")
        
        logger.debug("[MeetingStore] Arquivo de áudio válido encontrado: \(audioPath)", category: .general)
        
        print("[CONSOLE] Verificando se já existe transcrição em andamento...")
        print("[CONSOLE] meeting.transcriptionTaskId: \(meeting.transcriptionTaskId?.uuidString ?? "nil")")
        
        // Verificar se já existe transcrição em andamento
        if let taskId = meeting.transcriptionTaskId,
           let task = transcriptionManager.tasks.first(where: { $0.id == taskId }),
           task.isActive {
            print("[CONSOLE] ⚠️ Transcrição já em andamento, retornando taskId existente")
            logger.warning("Transcrição já em andamento para esta reunião", category: .general)
            return taskId
        }
        
        print("[CONSOLE] Nenhuma transcrição em andamento, criando nova...")
        
        // Enfileirar nova transcrição
        print("[CONSOLE] Chamando transcriptionManager.enqueueTranscription...")
        logger.debug("[MeetingStore] Chamando transcriptionManager.enqueueTranscription", category: .general)
        let taskId = transcriptionManager.enqueueTranscription(
            for: meeting.id,
            audioFilePath: audioPath
        )
        print("[CONSOLE] ✅ Task ID criado: \(taskId.uuidString)")
        logger.debug("[MeetingStore] Task ID criado: \(taskId.uuidString)", category: .general)
        
        // Atualizar reunião com ID da tarefa
        var updatedMeeting = meeting
        updatedMeeting.transcriptionTaskId = taskId
        dataManager.saveMeeting(updatedMeeting)
        logger.debug("[MeetingStore] Meeting atualizado com task ID", category: .general)
        
        logger.info("[MeetingStore] Transcrição enfileirada para reunião: \(meeting.title)", category: .audio)
        logger.debug("[MeetingStore] === FINALIZANDO startTranscription ===", category: .general)
        return taskId
    }
    
    /// Cancelar transcrição de uma reunião
    /// - Parameter meeting: Reunião para cancelar transcrição
    func cancelTranscription(for meeting: Meeting) {
        guard let taskId = meeting.transcriptionTaskId else { return }
        
        transcriptionManager.cancelTask(taskId)
        
        // Limpar ID da tarefa
        var updatedMeeting = meeting
        updatedMeeting.transcriptionTaskId = nil
        dataManager.saveMeeting(updatedMeeting)
        
        logger.error("Transcrição cancelada para reunião: \(meeting.title)", category: .general)
    }
    
    /// Obter status da transcrição para uma reunião
    /// - Parameter meeting: Reunião
    /// - Returns: Status da transcrição
    func getTranscriptionStatus(for meeting: Meeting) -> TranscriptionStatus? {
        guard let taskId = meeting.transcriptionTaskId else { return nil }
        return transcriptionManager.tasks.first { $0.id == taskId }?.status
    }
    
    /// Obter progresso da transcrição para uma reunião
    /// - Parameter meeting: Reunião
    /// - Returns: Progresso (0.0 a 1.0)
    func getTranscriptionProgress(for meeting: Meeting) -> Double {
        guard let taskId = meeting.transcriptionTaskId else { return 0.0 }
        return transcriptionManager.tasks.first { $0.id == taskId }?.progress ?? 0.0
    }
    
    /// Verificar se reunião tem transcrição disponível
    /// - Parameter meeting: Reunião
    /// - Returns: True se tem transcrição
    func hasTranscription(for meeting: Meeting) -> Bool {
        return transcriptionManager.hasTranscription(for: meeting.id)
    }
    
    /// Obter resultado da transcrição
    /// - Parameter meeting: Reunião
    /// - Returns: Resultado da transcrição
    func getTranscriptionResult(for meeting: Meeting) -> TranscriptionResult? {
        logger.debug("MeetingStore.getTranscriptionResult() called for meeting: \(meeting.id)", category: .general)
        let result = transcriptionManager.getTranscriptionResult(for: meeting.id)
        if result != nil {
            logger.debug("Transcription result found in MeetingStore", category: .general)
        } else {
            logger.debug("ERROR: No transcription result found in MeetingStore", category: .general)
        }
        return result
    }
    
    /// Obter todas as tarefas de transcrição
    var transcriptionTasks: [TranscriptionTask] {
        return transcriptionManager.tasks
    }
    
    /// Verificar se há transcrições sendo processadas
    var isTranscribing: Bool {
        let isProcessing = transcriptionManager.isProcessing
        logger.debug("[MeetingStore] isTranscribing consultado: \(isProcessing), tasks ativas: \(transcriptionManager.tasks.filter { $0.isActive }.count)", category: .general)
        return isProcessing
    }
    
    /// Obter progresso da fila de transcrições
    var transcriptionQueueProgress: (current: Int, total: Int) {
        return transcriptionManager.queueProgress
    }
    
    // MARK: - Audio Capture Strategy
    
    /// Aplica a estratégia de captura de áudio baseada na configuração
    private func applyAudioCaptureStrategy() {
        let strategy: AudioCaptureStrategy = useCoreAudioTap ? .coreAudioTaps : .screenCaptureKit
        
        logger.info("Aplicando estratégia de captura: \(strategy.rawValue)", category: .audio)
        logger.debug("useCoreAudioTap: \(useCoreAudioTap)", category: .audio)
        
        // Se Core Audio Tap foi habilitado, verificar Helper Tool
        if useCoreAudioTap {
            Task {
                await checkHelperToolStatus()
            }
        }
        
        // Configurar o audioService com a estratégia escolhida
        audioService?.setAudioCaptureStrategy(strategy)
    }
    
    // MARK: - Helper Tool Management
    
    /// Verifica o status atual da Helper Tool
    func checkHelperToolStatus() async {
        guard useCoreAudioTap else { return }
        
        logger.debug("Verificando status da Helper Tool", category: .audio)
        
        let status = await CoreAudioTapService.getHelperToolStatus()
        
        await MainActor.run {
            self.helperToolStatus = status
            self.objectWillChange.send()
        }
        
        logger.debug("Status Helper Tool: instalada=\(status.isInstalled), versão=\(status.version ?? "N/A")", category: .audio)
    }
    
    /// Instala a Helper Tool se necessário
    func installHelperToolIfNeeded() async throws {
        logger.info("Verificando necessidade de instalar Helper Tool", category: .audio)
        
        let manager = HelperInstallationManager.shared
        let success = try await manager.installHelperIfNeeded()
        
        if success {
            logger.info("✅ Helper Tool instalada/verificada com sucesso", category: .audio)
            await checkHelperToolStatus()
        } else {
            logger.error("❌ Falha na instalação da Helper Tool", category: .audio)
            throw XPCError.installationFailed("Instalação da Helper Tool falhou")
        }
    }
    
    // MARK: - Cleanup
    
    func performMaintenance() {
        dataManager.cleanupOrphanedFiles()
    }
    
    deinit {
        logger.debug("🗑️ MeetingStore deinit iniciado", category: .memory)
        
        // Cancelar todos os observers
        cancellables.removeAll()
        logger.debug("✅ Observers cancelados", category: .memory)
        
        // Fechar janelas de transcrição abertas
        Task { @MainActor in
            TranscriptionWindowManager.shared.closeAllWindows()
        }
        logger.debug("✅ Janelas de transcrição fechadas", category: .memory)
        
        logger.debug("✅ MeetingStore deinit concluído", category: .memory)
    }
} 