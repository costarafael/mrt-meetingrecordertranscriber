import Foundation
import AVFoundation

/// Service especializado para gerenciamento de arquivos de áudio durante gravação
final class AudioFileService {
    private let audioFileManager: AudioFileManagerProtocol
    private let synchronizer: AudioSynchronizerProtocol
    private let logger = LoggingService.shared
    private let diagnostics = DiagnosticsService()
    
    // Thread-safe file writing
    private let fileWritingQueue = DispatchQueue(label: "audio.file.writing", qos: .userInitiated)
    
    // Current recording files
    private var microphoneFile: AVAudioFile?
    private var systemAudioFile: AVAudioFile?
    private var currentMeetingId: UUID?
    
    init(audioFileManager: AudioFileManagerProtocol, synchronizer: AudioSynchronizerProtocol) {
        self.audioFileManager = audioFileManager
        self.synchronizer = synchronizer
    }
    
    // MARK: - File Setup
    
    func setupAudioFiles(for meetingId: UUID, configuration: AudioConfiguration) async throws {
        logger.fileOperation("Setting up audio files for meeting", path: meetingId.uuidString)
        
        currentMeetingId = meetingId
        
        // Create microphone file
        microphoneFile = try audioFileManager.createAudioFile(
            for: meetingId,
            configuration: configuration,
            type: .microphone
        )
        
        // Create system audio file if enabled
        if configuration.systemAudioConfig != nil {
            systemAudioFile = try audioFileManager.createAudioFile(
                for: meetingId,
                configuration: configuration,
                type: .systemAudio
            )
            logger.fileOperation("System audio file created")
        } else {
            logger.fileOperation("System audio file not created - disabled")
        }
        
        logger.fileOperation("Audio files setup completed")
    }
    
    // MARK: - Audio Writing
    
    func writeMicrophoneAudio(_ buffer: AVAudioPCMBuffer) {
        guard buffer.frameLength > 0 else {
            logger.warning("Empty microphone buffer ignored", category: .audio)
            return
        }
        
        diagnostics.trackMicrophoneBuffer(buffer)
        
        fileWritingQueue.async { [weak self] in
            self?.performMicrophoneWrite(buffer)
        }
    }
    
    func writeSystemAudio(_ buffer: AVAudioPCMBuffer) {
        guard buffer.frameLength > 0 else {
            logger.warning("Empty system audio buffer ignored", category: .audio)
            return
        }
        
        diagnostics.trackSystemAudioBuffer(buffer)
        
        fileWritingQueue.async { [weak self] in
            self?.performSystemAudioWrite(buffer)
        }
    }
    
    // MARK: - File Processing
    
    func processRecordingFiles() async -> String? {
        logger.debug("[DEBUG] === INÍCIO processRecordingFiles ===", category: .general)
        guard let meetingId = currentMeetingId else {
            logger.error("No meeting ID available for file processing", category: .file)
            logger.debug("[DEBUG] currentMeetingId nil em processRecordingFiles", category: .general)
            return nil
        }
        
        let audioFiles = audioFileManager.listAudioFiles(for: meetingId)
        
        let microphoneFiles = audioFiles.filter { $0.type == .microphone }
        let systemFiles = audioFiles.filter { $0.type == .systemAudio }
        
        guard let micFile = microphoneFiles.first else {
            logger.error("Microphone file not found for processing", category: .file)
            logger.debug("[DEBUG] Nenhum arquivo de microfone encontrado em processRecordingFiles", category: .general)
            return nil
        }
        
        let startTime = CFAbsoluteTimeGetCurrent()
        logger.fileOperation("Processing files", path: micFile.path)
        print("[DEBUG] Iniciando processamento dos arquivos: mic = \(micFile.path), sys = \(systemFiles.first?.path ?? "<nenhum>")")
        
        defer {
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            logger.debug("[PERFORMANCE] Process recording files took \(String(format: "%.2f", duration))s", category: .performance)
        }
            
            // Check if system audio file exists and should be combined
            if let systemFile = systemFiles.first,
               audioFileManager.fileExists(at: systemFile.path) {
                
                // Verificar tamanho e validez dos arquivos
                guard let micSize = audioFileManager.getFileSize(at: micFile.path),
                      let sysSize = audioFileManager.getFileSize(at: systemFile.path) else {
                    logger.debug("[DEBUG] Não foi possível obter o tamanho de um dos arquivos", category: .general)
                    logger.error("Falha ao obter tamanho dos arquivos", category: .file)
                    return micFile.path
                }
                
                logger.debug("[DEBUG] Tamanho dos arquivos - mic: \(micSize) bytes, sys: \(sysSize) bytes", category: .general)
                
                // Verificar se os arquivos têm tamanho válido
                guard micSize > 0, sysSize > 0 else {
                    logger.debug("[DEBUG] Um dos arquivos está vazio - mic: \(micSize), sys: \(sysSize)", category: .general)
                    logger.error("Arquivos de áudio vazios", category: .file)
                    return micFile.path
                }
                
                // NOVA ABORDAGEM: Usar diretamente o método alternativo baseado em AVAsset
                // sem tentar usar AVAudioFile primeiro
                let outputPath = micFile.path.replacingOccurrences(of: "_mic.m4a", with: "_combined.m4a")
                logger.debug("[DEBUG] === INICIANDO combineAudioFilesSimple ===", category: .general)
                
                do {
                    let combinedPath = try await combineAudioFilesSimple(
                        micPath: micFile.path,
                        sysPath: systemFile.path,
                        outputPath: outputPath
                    )
                    logger.debug("[DEBUG] === COMBINAÇÃO CONCLUÍDA: \(combinedPath) ===", category: .general)
                    return combinedPath
                } catch {
                    logger.debug("[DEBUG] === COMBINAÇÃO FALHOU: \(error) ===", category: .general)
                    logger.error("Falha ao combinar arquivos com método alternativo", error: error, category: .file)
                    return micFile.path // Fallback
                }
                
            } else {
                if systemFiles.isEmpty {
                    logger.error("[LOG DIAGNÓSTICO] Nenhum arquivo de áudio do sistema encontrado para combinar. Apenas o arquivo do microfone será usado.", category: .file)
                    logger.debug("[DEBUG] Nenhum arquivo de áudio do sistema encontrado para combinar.", category: .general)
                } else {
                    logger.error("[LOG DIAGNÓSTICO] Arquivo de áudio do sistema existe na lista, mas não existe no disco.", category: .file)
                    logger.debug("[DEBUG] Arquivo de áudio do sistema existe na lista, mas não existe no disco.", category: .general)
                }
                logger.fileOperation("Using microphone-only recording")
                logger.debug("[DEBUG] Usando apenas o arquivo do microfone: \(micFile.path)", category: .general)
                logger.debug("[DEBUG] === FIM processRecordingFiles (microfone only) ===", category: .general)
                return micFile.path
            }
    }
    
    // Método simplificado para combinação de arquivos usando AVAssetExportSession
    // Esta versão usa APIs modernas do AVFoundation
    private func combineAudioFilesSimple(micPath: String, sysPath: String, outputPath: String) async throws -> String {
        logger.debug("[DEBUG] Iniciando combinação simplificada", category: .general)
        
        // Verificar explicitamente se os arquivos existem e são acessíveis
        guard FileManager.default.fileExists(atPath: micPath),
              FileManager.default.fileExists(atPath: sysPath) else {
            logger.debug("[DEBUG] Um dos arquivos não existe ou não é acessível", category: .general)
            throw NSError(domain: "AudioFileService", code: 5, userInfo: [NSLocalizedDescriptionKey: "Arquivos não existem ou não são acessíveis"])
        }
        
        // Verificar tamanho dos arquivos
        guard let micSize = audioFileManager.getFileSize(at: micPath),
              let sysSize = audioFileManager.getFileSize(at: sysPath),
              micSize > 0, sysSize > 0 else {
            logger.debug("[DEBUG] Um dos arquivos está vazio ou não pode ter seu tamanho determinado", category: .general)
            throw NSError(domain: "AudioFileService", code: 6, userInfo: [NSLocalizedDescriptionKey: "Arquivos vazios ou inacessíveis"])
        }
        
        logger.debug("[DEBUG] Verificação de arquivos OK - mic: \(micSize) bytes, sys: \(sysSize) bytes", category: .general)
        
        // Criar AVAssets a partir dos caminhos
        let micAsset = AVAsset(url: URL(fileURLWithPath: micPath))
        let sysAsset = AVAsset(url: URL(fileURLWithPath: sysPath))
        
        // Criar composição
        let composition = AVMutableComposition()
        guard let compositionTrack = composition.addMutableTrack(
            withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            throw NSError(domain: "AudioFileService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Não foi possível criar faixa de composição"])
        }
        
        // Adicionar faixa de microfone usando APIs modernas
        let micTracks: [AVAssetTrack]
        let micDuration: CMTime
        
        do {
            async let tracksLoad = micAsset.loadTracks(withMediaType: .audio)
            async let durationLoad = micAsset.load(.duration)
            micTracks = try await tracksLoad
            micDuration = try await durationLoad
        } catch {
            logger.debug("[DEBUG] Erro ao carregar informações do microfone: \(error)", category: .general)
            throw error
        }
        
        if let micTrack = micTracks.first {
            let timeRange = CMTimeRange(start: .zero, duration: micDuration)
            do {
                try compositionTrack.insertTimeRange(timeRange, of: micTrack, at: .zero)
                logger.debug("[DEBUG] Faixa de microfone adicionada à composição", category: .general)
            } catch {
                logger.debug("[DEBUG] Erro ao adicionar faixa de microfone: \(error)", category: .general)
                throw error
            }
        } else {
            logger.debug("[DEBUG] Microfone não possui faixas de áudio", category: .general)
            throw NSError(domain: "AudioFileService", code: 3, userInfo: [NSLocalizedDescriptionKey: "Microfone não tem faixas de áudio"])
        }
        
        // Adicionar faixa de sistema usando APIs modernas
        let sysTracks: [AVAssetTrack]
        let sysDuration: CMTime
        
        do {
            async let tracksLoad = sysAsset.loadTracks(withMediaType: .audio)
            async let durationLoad = sysAsset.load(.duration)
            sysTracks = try await tracksLoad
            sysDuration = try await durationLoad
        } catch {
            logger.debug("[DEBUG] Erro ao carregar informações do sistema: \(error)", category: .general)
            throw error
        }
        
        if let sysTrack = sysTracks.first {
            if let compositionTrack2 = composition.addMutableTrack(
                withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) {
                do {
                    let timeRange = CMTimeRange(start: .zero, duration: sysDuration)
                    try compositionTrack2.insertTimeRange(timeRange, of: sysTrack, at: .zero)
                    logger.debug("[DEBUG] Faixa de sistema adicionada à composição", category: .general)
                } catch {
                    logger.debug("[DEBUG] Erro ao adicionar faixa de sistema: \(error)", category: .general)
                    throw error
                }
            }
        } else {
            logger.debug("[DEBUG] Sistema não possui faixas de áudio", category: .general)
            throw NSError(domain: "AudioFileService", code: 3, userInfo: [NSLocalizedDescriptionKey: "Sistema não tem faixas de áudio"])
        }
        
        // Exportar composição
        let outputURL = URL(fileURLWithPath: outputPath)
        
        // Remover arquivo existente se necessário
        if FileManager.default.fileExists(atPath: outputPath) {
            try FileManager.default.removeItem(at: URL(fileURLWithPath: outputPath))
        }
        
        guard let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetAppleM4A) else {
            throw NSError(domain: "AudioFileService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Não foi possível criar sessão de exportação"])
        }
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .m4a
        exportSession.audioMix = try await createAudioMixSimple(micAsset: micAsset, sysAsset: sysAsset)
        
        logger.debug("[DEBUG] Configuração de exportação - outputURL: \(outputURL.path), outputFileType: m4a", category: .general)
        
        // Exportar usando async/await moderno com timeout
        logger.debug("[DEBUG] Iniciando exportação assíncrona...", category: .general)
        
        try await withThrowingTaskGroup(of: Void.self) { group in
            // Task para a exportação
            group.addTask {
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    var hasResumed = false
                    exportSession.exportAsynchronously { [weak self] in
                        guard !hasResumed else { return }
                        hasResumed = true
                        
                        if let error = exportSession.error {
                            self?.logger.debug("[DEBUG] Erro durante exportação: \(error)", category: .general)
                            continuation.resume(throwing: error)
                        } else {
                            self?.logger.debug("[DEBUG] Exportação concluída com sucesso", category: .general)
                            continuation.resume()
                        }
                    }
                }
            }
            
            // Task para timeout de 60 segundos
            group.addTask {
                try await Task.sleep(nanoseconds: 60_000_000_000) // 60 segundos
                throw NSError(domain: "AudioFileService", code: 8, userInfo: [NSLocalizedDescriptionKey: "Timeout na exportação (60s)"])
            }
            
            // Aguardar o primeiro a completar (sucesso ou timeout)
            try await group.next()
            group.cancelAll()
        }
        
        // Verificar se o arquivo de saída foi criado
        if FileManager.default.fileExists(atPath: outputPath) {
            let fileSize = audioFileManager.getFileSize(at: outputPath) ?? 0
            logger.debug("[DEBUG] Arquivo combinado criado: \(outputPath) (\(fileSize) bytes)", category: .general)
            return outputPath
        } else {
            logger.debug("[DEBUG] Exportação concluída, mas arquivo não encontrado", category: .general)
            throw NSError(domain: "AudioFileService", code: 4, userInfo: [NSLocalizedDescriptionKey: "Arquivo exportado não encontrado"])
        }
    }
    
    // Criar um AudioMix para ajustar os volumes das faixas - versão com APIs modernas
    private func createAudioMixSimple(micAsset: AVAsset, sysAsset: AVAsset) async throws -> AVAudioMix {
        let audioMix = AVMutableAudioMix()
        var audioMixParams: [AVMutableAudioMixInputParameters] = []
        
        // Parâmetros para microfone (volume 0.8)
        let micTracks = try await micAsset.loadTracks(withMediaType: .audio)
        if let micTrack = micTracks.first {
            let micParams = AVMutableAudioMixInputParameters(track: micTrack)
            micParams.setVolume(0.8, at: .zero)
            audioMixParams.append(micParams)
            logger.debug("[DEBUG] Parâmetros de áudio para microfone: volume 0.8", category: .general)
        }
        
        // Parâmetros para sistema (volume 0.7)
        let sysTracks = try await sysAsset.loadTracks(withMediaType: .audio)
        if let sysTrack = sysTracks.first {
            let sysParams = AVMutableAudioMixInputParameters(track: sysTrack)
            sysParams.setVolume(0.7, at: .zero)
            audioMixParams.append(sysParams)
            logger.debug("[DEBUG] Parâmetros de áudio para sistema: volume 0.7", category: .general)
        }
        
        audioMix.inputParameters = audioMixParams
        return audioMix
    }
    
    func finalizeFiles() async {
        logger.fileOperation("Finalizing audio files, waiting for queue...")
        
        await withCheckedContinuation { continuation in
            fileWritingQueue.sync {
                // Todas as operações de escrita pendentes terminaram aqui.
                logger.fileOperation("All file writes completed.")
                
                // Explicitamente fechar os arquivos
                logger.debug("[DEBUG] Fechando explicitamente os arquivos de áudio...", category: .general)
                
                // A maneira segura de "fechar" um AVAudioFile é simplesmente
                // remover a referência a ele, o que libera os recursos.
                self.microphoneFile = nil
                self.systemAudioFile = nil
                
                continuation.resume()
            }
        }
        
        // Aguardar mais um pouco para garantir que o sistema tenha tempo de liberar os recursos
        logger.debug("[DEBUG] Esperando o sistema liberar os recursos dos arquivos...", category: .general)
        try? await Task.sleep(nanoseconds: 500_000_000) // 500 ms
        
        // Log final diagnostics
        diagnostics.logFinalDiagnostics()
        
        // Cleanup temporary files if needed
        if let meetingId = currentMeetingId {
            audioFileManager.cleanupTemporaryFiles(for: meetingId)
        }
        
        logger.debug("[DEBUG] Finalização dos arquivos concluída", category: .general)
        // NÃO limpar o currentMeetingId aqui, pois ele é necessário para processRecordingFiles
        // currentMeetingId = nil
    }
    
    /// Limpar o estado interno após o processamento dos arquivos
    func cleanupState() {
        logger.debug("[DEBUG] Limpando estado interno do AudioFileService", category: .general)
        currentMeetingId = nil
    }
    
    // MARK: - Private Methods
    
    private func performMicrophoneWrite(_ buffer: AVAudioPCMBuffer) {
        guard let micFile = microphoneFile else {
            logger.error("Microphone file not available for writing", category: .file)
            return
        }
        
        do {
            try micFile.write(from: buffer)
            diagnostics.trackMicrophoneFileWrite()
        } catch {
            logger.critical("Failed to write microphone audio", error: error, category: .file)
        }
    }
    
    private func performSystemAudioWrite(_ buffer: AVAudioPCMBuffer) {
        guard let sysFile = systemAudioFile else {
            logger.error("System audio file not available for writing", category: .file)
            logger.error("🔍 DIAGNÓSTICO: systemAudioFile é nil ao tentar escrever")
            return
        }
        
        // Validate format compatibility
        let fileFormat = sysFile.processingFormat
        let bufferFormat = buffer.format
        
        guard diagnostics.validateAudioFormats(fileFormat: fileFormat, bufferFormat: bufferFormat) else {
            logger.error("Audio format incompatibility detected", category: .file)
            logger.error("🔍 DIAGNÓSTICO: Incompatibilidade de formato - file: \(fileFormat.sampleRate)Hz/\(fileFormat.channelCount)ch, buffer: \(bufferFormat.sampleRate)Hz/\(bufferFormat.channelCount)ch")
            return
        }
        
        do {
            try sysFile.write(from: buffer)
            diagnostics.trackSystemAudioFileWrite()
            
            // Log a cada 100 escritas para monitorar continuidade
            let writeCount = diagnostics.getSystemAudioFileWriteCount()
            if writeCount % 100 == 0 {
                logger.debug("🔍 Sistema de áudio: \(writeCount) escritas realizadas", category: .file)
            }
        } catch {
            logger.critical("Failed to write system audio", error: error, category: .file)
            logger.critical("🔍 DIAGNÓSTICO: Erro específico ao escrever sistema: \(error)")
            logger.critical("   • Buffer frames: \(buffer.frameLength)")
            logger.critical("   • Buffer format: \(buffer.format)")
            logger.critical("   • File URL: \(sysFile.url.path)")
        }
    }
    
    // MARK: - File Information
    
    func getFileInfo(for meetingId: UUID) -> (microphonePath: String?, systemAudioPath: String?) {
        let audioFiles = audioFileManager.listAudioFiles(for: meetingId)
        
        let microphoneFile = audioFiles.first { $0.type == .microphone }
        let systemFile = audioFiles.first { $0.type == .systemAudio }
        
        return (
            microphonePath: microphoneFile?.path,
            systemAudioPath: systemFile?.path
        )
    }
    
    func validateFileIntegrity(for meetingId: UUID) -> Bool {
        let (micPath, sysPath) = getFileInfo(for: meetingId)
        
        guard let microphonePath = micPath,
              audioFileManager.fileExists(at: microphonePath) else {
            logger.error("Microphone file validation failed", category: .file)
            return false
        }
        
        if let systemPath = sysPath {
            guard audioFileManager.fileExists(at: systemPath) else {
                logger.warning("System audio file missing but expected", category: .file)
                return false
            }
        }
        
        logger.fileOperation("File integrity validation passed")
        return true
    }
} 