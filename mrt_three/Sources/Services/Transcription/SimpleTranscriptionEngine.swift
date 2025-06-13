import Foundation

/// Erros de transcrição
enum TranscriptionError: Error {
    case pipelineExecutionFailed(String)
    case processLaunchFailed(String)
    case taskCancelled
}

/// Motor de transcrição simplificado que chama o executável diretamente
class SimpleTranscriptionEngine {
    
    private let logger = LoggingService.shared
    private let fileManager = FileManager.default
    
    // Caminhos para o backend de transcrição
    private let backendBasePath: String
    private let executablePath: String
    
    // Cancellation support
    private var currentProcess: Process?
    private var cancellationTokens: [UUID: Bool] = [:]
    
    init() {
        // Determinar caminhos do backend baseado na estrutura do projeto
        let bundlePath = Bundle.main.bundlePath
        logger.debug("Bundle path: \(bundlePath)", category: .general)
        
        // Para swift run, o bundle path é .build/arm64-apple-macosx/debug/MacOSApp
        // Para app bundle, seria /path/to/App.app/Contents/MacOS
        if bundlePath.contains(".build") {
            // Modo desenvolvimento - buscar Resources no diretório do projeto
            let projectRoot = bundlePath.components(separatedBy: "/.build").first ?? ""
            self.backendBasePath = (projectRoot as NSString).appendingPathComponent("Resources/Transcription/Backend")
        } else {
            // Modo produção - buscar Resources no bundle
            let projectRoot = bundlePath.replacingOccurrences(of: "/Contents/MacOS", with: "")
            self.backendBasePath = (projectRoot as NSString).appendingPathComponent("../Resources/Transcription/Backend")
        }
        
        self.executablePath = (backendBasePath as NSString).appendingPathComponent("src/pipeline-optimized-small")
        
        logger.info("SimpleTranscriptionEngine initialized", category: .general)
        logger.debug("Backend path: \(backendBasePath)", category: .general)
        logger.debug("Executable: \(executablePath)", category: .general)
        logger.debug("Backend path set to: \(backendBasePath)", category: .general)
        logger.debug("Executable path set to: \(executablePath)", category: .general)
    }
    
    /// Cancela uma tarefa de transcrição em andamento
    /// - Parameter taskId: ID da tarefa a cancelar
    func cancelTask(_ taskId: UUID) {
        logger.info("Cancelling transcription task: \(taskId.uuidString)", category: .general)
        
        // Marcar tarefa como cancelada
        cancellationTokens[taskId] = true
        
        // Terminar processo atual se estiver rodando
        if let process = currentProcess, process.isRunning {
            logger.debug("Terminating current transcription process", category: .general)
            process.terminate()
            
            // Forçar encerramento após timeout se necessário
            DispatchQueue.global().asyncAfter(deadline: .now() + 2.0) {
                if process.isRunning {
                    self.logger.warning("Force killing transcription process", category: .general)
                    process.interrupt()
                }
            }
        }
    }
    
    /// Verifica se uma tarefa foi cancelada
    /// - Parameter taskId: ID da tarefa
    /// - Returns: true se foi cancelada
    private func isTaskCancelled(_ taskId: UUID) -> Bool {
        return cancellationTokens[taskId] == true
    }
    
    /// Limpa token de cancelamento
    /// - Parameter taskId: ID da tarefa
    private func clearCancellationToken(_ taskId: UUID) {
        cancellationTokens.removeValue(forKey: taskId)
    }
    
    /// Executa transcrição de um arquivo WAV
    /// - Parameters:
    ///   - audioFile: Caminho do arquivo WAV
    ///   - taskId: ID da tarefa (para logging)
    ///   - progressCallback: Callback para reportar progresso
    /// - Returns: Resultado da transcrição ou nil se falhar
    func transcribe(
        audioFile: String,
        taskId: UUID,
        progressCallback: @escaping (Double) -> Void
    ) async throws -> TranscriptionResult? {
        
        print("[CONSOLE] 🎯 SimpleTranscriptionEngine.transcribe() INICIADO")
        logger.info("Starting transcription for task \(taskId.uuidString) with file: \(audioFile)", category: .general)
        logger.debug("Starting transcription for task \(taskId.uuidString)", category: .general)
        logger.debug("Audio file: \(audioFile)", category: .general)
        print("[CONSOLE] Task ID: \(taskId.uuidString)")
        print("[CONSOLE] Audio file: \(audioFile)")
        
        // Limpar token de cancelamento anterior se existir
        clearCancellationToken(taskId)
        
        // Verificar se já foi cancelada antes de começar
        print("[CONSOLE] 🔍 Verificando cancelamento...")
        if isTaskCancelled(taskId) {
            print("[CONSOLE] ❌ Task já cancelada antes de começar")
            logger.info("Task was cancelled before starting: \(taskId.uuidString)", category: .general)
            throw TranscriptionError.taskCancelled
        }
        print("[CONSOLE] ✅ Task não cancelada")
        
        // Verificar se arquivo de áudio existe
        print("[CONSOLE] 🔍 Verificando se arquivo de áudio existe...")
        logger.debug("Checking if audio file exists...", category: .general)
        guard fileManager.fileExists(atPath: audioFile) else {
            print("[CONSOLE] ❌ ARQUIVO DE ÁUDIO NÃO EXISTE: \(audioFile)")
            logger.error("Audio file does not exist: \(audioFile)", category: .general)
            logger.debug("ERROR: Audio file does not exist", category: .general)
            return nil
        }
        print("[CONSOLE] ✅ Arquivo de áudio existe")
        logger.debug("Audio file exists", category: .general)
        
        // Verificar se backend existe
        print("[CONSOLE] 🔍 Validando backend setup...")
        logger.debug("Validating backend setup...", category: .general)
        guard validateBackendSetup() else {
            print("[CONSOLE] ❌ BACKEND VALIDATION FALHOU")
            logger.error("Backend validation failed", category: .general)
            logger.debug("ERROR: Backend validation failed", category: .general)
            return nil
        }
        print("[CONSOLE] ✅ Backend validation bem-sucedida")
        logger.debug("Backend validation successful", category: .general)
        
        do {
            // Verificar cancelamento antes de copiar arquivo
            print("[CONSOLE] 🔍 Verificando cancelamento antes de copiar...")
            if isTaskCancelled(taskId) {
                print("[CONSOLE] ❌ Task cancelada durante setup")
                logger.info("Task cancelled during setup: \(taskId.uuidString)", category: .general)
                throw TranscriptionError.taskCancelled
            }
            print("[CONSOLE] ✅ Task não cancelada, prosseguindo...")
            
            // Copiar arquivo para o caminho hardcoded no backend E criar estrutura correta
            let targetDir = "/Users/rafaelaredes/Documents/sherpa-onnx"
            let targetAudioPath = "\(targetDir)/audio_pt_test.wav"
            // O executável espera os modelos em /Users/rafaelaredes/Documents/sherpa-onnx/pipeline_swift/src/../models
            // que resolve para /Users/rafaelaredes/Documents/sherpa-onnx/pipeline_swift/models
            let pipelineDir = "\(targetDir)/pipeline_swift"
            let pipelineSrcDir = "\(pipelineDir)/src"
            let targetModelsDir = "\(pipelineDir)/models"
            print("[CONSOLE] 📁 Target directory: \(targetDir)")
            print("[CONSOLE] 🎵 Target audio path: \(targetAudioPath)")
            print("[CONSOLE] 📁 Pipeline directory: \(pipelineDir)")
            print("[CONSOLE] 📁 Pipeline src directory: \(pipelineSrcDir)")
            print("[CONSOLE] 📁 Target models directory: \(targetModelsDir)")
            
            // Criar diretórios se não existirem
            print("[CONSOLE] 🔨 Criando diretórios se necessário...")
            try fileManager.createDirectory(atPath: targetDir, withIntermediateDirectories: true, attributes: nil)
            try fileManager.createDirectory(atPath: pipelineDir, withIntermediateDirectories: true, attributes: nil)
            try fileManager.createDirectory(atPath: pipelineSrcDir, withIntermediateDirectories: true, attributes: nil)
            
            // Copiar modelos se não existirem
            let sourceModelsDir = "\(backendBasePath)/models"
            print("[CONSOLE] 📋 Verificando se precisa copiar modelos...")
            if !fileManager.fileExists(atPath: targetModelsDir) {
                print("[CONSOLE] 📋 Copiando modelos de \(sourceModelsDir) para \(targetModelsDir)...")
                // Copiar toda a pasta de modelos
                try fileManager.copyItem(atPath: sourceModelsDir, toPath: targetModelsDir)
                print("[CONSOLE] ✅ Modelos copiados com sucesso!")
            } else {
                print("[CONSOLE] ✅ Modelos já existem")
            }
            print("[CONSOLE] ✅ Estrutura de diretórios configurada")
            
            // Remover arquivo existente se houver
            print("[CONSOLE] 🗑️ Verificando arquivo existente...")
            if fileManager.fileExists(atPath: targetAudioPath) {
                print("[CONSOLE] 🗑️ Removendo arquivo existente...")
                try fileManager.removeItem(atPath: targetAudioPath)
                print("[CONSOLE] ✅ Arquivo existente removido")
            } else {
                print("[CONSOLE] ✅ Nenhum arquivo existente para remover")
            }
            
            print("[CONSOLE] 📋 Copiando arquivo de áudio...")
            try fileManager.copyItem(atPath: audioFile, toPath: targetAudioPath)
            print("[CONSOLE] ✅ Arquivo copiado com sucesso!")
            
            defer {
                // Limpar arquivo copiado
                try? fileManager.removeItem(atPath: targetAudioPath)
                // Nota: Não removemos os modelos pois podem ser reutilizados em outras transcrições
                // Limpar referência do processo
                self.currentProcess = nil
                // Limpar token de cancelamento
                self.clearCancellationToken(taskId)
            }
            
            // Verificar cancelamento antes de executar
            print("[CONSOLE] 🔍 Verificando cancelamento antes de executar pipeline...")
            if isTaskCancelled(taskId) {
                print("[CONSOLE] ❌ Task cancelada antes da execução do pipeline")
                logger.info("Task cancelled before pipeline execution: \(taskId.uuidString)", category: .general)
                throw TranscriptionError.taskCancelled
            }
            print("[CONSOLE] ✅ Task não cancelada, executando pipeline...")
            
            // Executar pipeline
            print("[CONSOLE] 📊 Reportando progresso inicial (0.1)...")
            progressCallback(0.1)
            print("[CONSOLE] 🚀 Chamando executeTranscriptionPipeline...")
            let pipelineOutput = try await executeTranscriptionPipeline(
                taskId: taskId,
                progressCallback: progressCallback
            )
            print("[CONSOLE] ✅ executeTranscriptionPipeline retornou!")
            
            // Verificar cancelamento após pipeline
            print("[CONSOLE] 🔍 Verificando cancelamento após pipeline...")
            if isTaskCancelled(taskId) {
                print("[CONSOLE] ❌ Task cancelada após execução do pipeline")
                logger.info("Task cancelled after pipeline execution: \(taskId.uuidString)", category: .general)
                throw TranscriptionError.taskCancelled
            }
            print("[CONSOLE] ✅ Task não cancelada após pipeline")
            
            print("[CONSOLE] 📊 Reportando progresso (0.9)...")
            progressCallback(0.9)
            
            // Processar saída do pipeline
            print("[CONSOLE] 🔄 Processando saída do pipeline...")
            print("[CONSOLE] 📝 Pipeline output length: \(pipelineOutput.count) characters")
            guard let result = parseTranscriptionOutput(pipelineOutput, taskId: taskId) else {
                print("[CONSOLE] ❌ FALHA AO PROCESSAR SAÍDA DO PIPELINE")
                logger.error("Failed to parse transcription output", category: .general)
                return nil
            }
            print("[CONSOLE] ✅ Saída do pipeline processada com sucesso!")
            
            print("[CONSOLE] 📊 Reportando progresso final (1.0)...")
            progressCallback(1.0)
            print("[CONSOLE] ✅ TRANSCRIÇÃO CONCLUÍDA COM SUCESSO!")
            print("[CONSOLE] 📊 Segmentos: \(result.segments.count), Duração: \(result.summary.totalDuration)s")
            logger.info("Transcription completed successfully for task \(taskId.uuidString): \(result.segments.count) segments, \(result.summary.totalDuration)s duration", category: .general)
            
            return result
            
        } catch TranscriptionError.taskCancelled {
            print("[CONSOLE] ⏹️ TranscriptionError.taskCancelled capturado")
            logger.info("Transcription task cancelled: \(taskId.uuidString)", category: .general)
            throw TranscriptionError.taskCancelled
        } catch {
            print("[CONSOLE] ❌ ERRO DURANTE TRANSCRIÇÃO: \(error)")
            logger.error("Transcription failed", error: error, category: .general)
            throw error
        }
    }
    
    // MARK: - Private Methods
    
    private func validateBackendSetup() -> Bool {
        logger.debug("validateBackendSetup() called", category: .general)
        logger.debug("Backend path: \(backendBasePath)", category: .general)
        logger.debug("Executable path: \(executablePath)", category: .general)
        
        // Verificar se diretório do backend existe
        logger.debug("Checking if backend directory exists...", category: .general)
        guard fileManager.fileExists(atPath: backendBasePath) else {
            logger.error("Backend directory not found: \(backendBasePath)", category: .general)
            logger.debug("ERROR: Backend directory not found", category: .general)
            return false
        }
        logger.debug("Backend directory exists", category: .general)
        
        // Verificar se executável existe
        logger.debug("Checking if executable exists...", category: .general)
        guard fileManager.fileExists(atPath: executablePath) else {
            logger.error("Executable not found: \(executablePath)", category: .general)
            logger.debug("ERROR: Executable not found", category: .general)
            return false
        }
        logger.debug("Executable exists", category: .general)
        
        // Verificar se executável tem permissões
        logger.debug("Checking executable permissions...", category: .general)
        guard fileManager.isExecutableFile(atPath: executablePath) else {
            logger.error("Executable does not have execute permissions: \(executablePath)", category: .general)
            logger.debug("ERROR: Executable does not have execute permissions", category: .general)
            return false
        }
        logger.debug("Executable has permissions", category: .general)
        logger.debug("Backend validation completed successfully", category: .general)
        
        logger.info("Backend validation completed successfully", category: .general)
        return true
    }
    
    private func executeTranscriptionPipeline(
        taskId: UUID,
        progressCallback: @escaping (Double) -> Void
    ) async throws -> String {
        
        print("[CONSOLE] 🎯 executeTranscriptionPipeline() INICIADO")
        print("[CONSOLE] Task ID: \(taskId.uuidString)")
        print("[CONSOLE] Executable path: \(executablePath)")
        print("[CONSOLE] Backend base path: \(backendBasePath)")
        
        return try await withCheckedThrowingContinuation { continuation in
            print("[CONSOLE] 🔧 Configurando Process...")
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executablePath)
            process.arguments = [] // Sem argumentos, usa configuração hardcoded
            process.currentDirectoryURL = URL(fileURLWithPath: backendBasePath)
            print("[CONSOLE] ✅ Process configurado")
            print("[CONSOLE] Executable URL: \(process.executableURL?.path ?? "nil")")
            print("[CONSOLE] Arguments: \(process.arguments ?? [])")
            print("[CONSOLE] Working directory: \(process.currentDirectoryURL?.path ?? "nil")")
            
            // Armazenar referência do processo para cancelamento
            print("[CONSOLE] 📝 Armazenando referência do processo...")
            self.currentProcess = process
            
            print("[CONSOLE] 🔧 Configurando pipes...")
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            
            let outputHandle = pipe.fileHandleForReading
            var outputData = Data()
            print("[CONSOLE] ✅ Pipes configurados")
            
            // Configurar monitoramento de saída
            outputHandle.readabilityHandler = { handle in
                // Verificar cancelamento durante execução
                if self.isTaskCancelled(taskId) {
                    process.terminate()
                    return
                }
                
                let data = handle.availableData
                if !data.isEmpty {
                    outputData.append(data)
                    
                    // Tentar extrair progresso da saída
                    if let output = String(data: data, encoding: .utf8) {
                        self.extractProgressFromOutput(output, callback: progressCallback)
                    }
                }
            }
            
            // Configurar handler de término
            print("[CONSOLE] 🔧 Configurando termination handler...")
            process.terminationHandler = { process in
                print("[CONSOLE] 🏁 Process termination handler executado")
                print("[CONSOLE] Termination status: \(process.terminationStatus)")
                outputHandle.readabilityHandler = nil
                
                // Ler dados finais
                print("[CONSOLE] 📖 Lendo dados finais...")
                let finalData = outputHandle.readDataToEndOfFile()
                outputData.append(finalData)
                print("[CONSOLE] 📝 Total output data: \(outputData.count) bytes")
                
                // Verificar se foi cancelamento
                if self.isTaskCancelled(taskId) {
                    print("[CONSOLE] ❌ Process terminado por cancelamento")
                    self.logger.info("Process terminated due to cancellation: \(taskId.uuidString)", category: .general)
                    continuation.resume(throwing: TranscriptionError.taskCancelled)
                    return
                }
                
                if process.terminationStatus == 0 {
                    print("[CONSOLE] ✅ Process terminado com sucesso (status 0)")
                    let output = String(data: outputData, encoding: .utf8) ?? ""
                    print("[CONSOLE] 📝 Output length: \(output.count) characters")
                    continuation.resume(returning: output)
                } else if process.terminationStatus == 15 { // SIGTERM
                    print("[CONSOLE] ⏹️ Process terminado por SIGTERM (cancelamento)")
                    self.logger.info("Process terminated by cancellation signal", category: .general)
                    continuation.resume(throwing: TranscriptionError.taskCancelled)
                } else {
                    print("[CONSOLE] ❌ Process FALHOU com status: \(process.terminationStatus)")
                    let errorOutput = String(data: outputData, encoding: .utf8) ?? "Unknown error"
                    print("[CONSOLE] 📝 Error output: \(errorOutput)")
                    self.logger.error("Pipeline execution failed with status \(process.terminationStatus): \(errorOutput)", category: .general)
                    continuation.resume(throwing: TranscriptionError.pipelineExecutionFailed(errorOutput))
                }
            }
            
            // Executar processo
            print("[CONSOLE] 🚀 Tentando executar o processo...")
            do {
                try process.run()
                print("[CONSOLE] ✅ Processo iniciado com sucesso!")
                print("[CONSOLE] Process ID: \(process.processIdentifier)")
                print("[CONSOLE] Is running: \(process.isRunning)")
            } catch {
                print("[CONSOLE] ❌ FALHA AO INICIAR PROCESSO: \(error)")
                continuation.resume(throwing: TranscriptionError.processLaunchFailed(error.localizedDescription))
            }
        }
    }
    
    private func extractProgressFromOutput(_ output: String, callback: @escaping (Double) -> Void) {
        // Extrair progresso baseado em padrões conhecidos do pipeline
        let lines = output.components(separatedBy: .newlines)
        
        for line in lines {
            // Buscar indicadores de progresso conhecidos
            if line.contains("ETAPA 1/3") {
                callback(0.2)
            } else if line.contains("ETAPA 2/3") {
                callback(0.4)
            } else if line.contains("ETAPA 3/3") {
                callback(0.6)
            } else if line.contains("Transcrevendo") {
                callback(0.8)
            }
        }
    }
    
    private func parseTranscriptionOutput(_ output: String, taskId: UUID) -> TranscriptionResult? {
        logger.debug("Parsing transcription output", category: .general)
        
        let lines = output.components(separatedBy: .newlines)
        
        var segments: [TranscriptionResult.TranscriptionSegment] = []
        var totalDuration: Double = 0
        var speakerIds: Set<Int> = []
        var totalWords = 0
        
        // Padrão para detectar segmentos: [XX] [00.00s-00.00s] Speaker X
        let segmentPattern = #"\[(\d+)\] \[(\d+\.\d+)s-(\d+\.\d+)s\] Speaker (\d+)"#
        let regex = try? NSRegularExpression(pattern: segmentPattern, options: [])
        
        var currentSegment: (speaker: Int, start: Double, end: Double, text: String)?
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Verificar se é linha de segmento
            if let match = regex?.firstMatch(in: trimmedLine, options: [], range: NSRange(location: 0, length: trimmedLine.count)) {
                
                // Salvar segmento anterior se existir
                if let segment = currentSegment {
                    let transcriptionSegment = TranscriptionResult.TranscriptionSegment(
                        speakerId: segment.speaker,
                        start: segment.start,
                        end: segment.end,
                        text: segment.text.trimmingCharacters(in: .whitespacesAndNewlines),
                        confidence: nil
                    )
                    segments.append(transcriptionSegment)
                    speakerIds.insert(segment.speaker)
                    totalWords += segment.text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count
                }
                
                // Extrair dados do novo segmento
                let startTime = Double((trimmedLine as NSString).substring(with: match.range(at: 2))) ?? 0
                let endTime = Double((trimmedLine as NSString).substring(with: match.range(at: 3))) ?? 0
                let speakerId = Int((trimmedLine as NSString).substring(with: match.range(at: 4))) ?? 0
                
                currentSegment = (speaker: speakerId, start: startTime, end: endTime, text: "")
                totalDuration = max(totalDuration, endTime)
                
            } else if trimmedLine.hasPrefix("📝") {
                // Linha de texto da transcrição
                let text = trimmedLine.replacingOccurrences(of: "📝", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                currentSegment?.text = text
            }
        }
        
        // Salvar último segmento
        if let segment = currentSegment {
            let transcriptionSegment = TranscriptionResult.TranscriptionSegment(
                speakerId: segment.speaker,
                start: segment.start,
                end: segment.end,
                text: segment.text.trimmingCharacters(in: .whitespacesAndNewlines),
                confidence: nil
            )
            segments.append(transcriptionSegment)
            speakerIds.insert(segment.speaker)
            totalWords += segment.text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count
        }
        
        guard !segments.isEmpty else {
            logger.error("No transcription segments found in output", category: .general)
            return nil
        }
        
        // Criar resultado
        let summary = TranscriptionResult.TranscriptionSummary(
            totalDuration: totalDuration,
            totalSpeakers: speakerIds.count,
            totalWords: totalWords,
            confidence: 0.8 // Estimativa padrão
        )
        
        let result = TranscriptionResult(
            taskId: taskId,
            meetingId: UUID(), // Será definido pelo caller
            segments: segments,
            summary: summary,
            createdAt: Date()
        )
        
        logger.info("Transcription parsing completed: \(segments.count) segments, \(speakerIds.count) speakers, \(totalWords) words, \(totalDuration)s duration", category: .general)
        
        return result
    }
}

