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
    
    func processRecordingFiles() -> String? {
        print("[DEBUG] Entrou em processRecordingFiles")
        guard let meetingId = currentMeetingId else {
            logger.error("No meeting ID available for file processing", category: .file)
            print("[DEBUG] currentMeetingId nil em processRecordingFiles")
            return nil
        }
        
        let audioFiles = audioFileManager.listAudioFiles(for: meetingId)
        
        let microphoneFiles = audioFiles.filter { $0.type == .microphone }
        let systemFiles = audioFiles.filter { $0.type == .systemAudio }
        
        guard let micFile = microphoneFiles.first else {
            logger.error("Microphone file not found for processing", category: .file)
            print("[DEBUG] Nenhum arquivo de microfone encontrado em processRecordingFiles")
            return nil
        }
        
        return diagnostics.monitorPerformance(operation: "Process recording files", category: .file) {
            logger.fileOperation("Processing files", path: micFile.path)
            print("[DEBUG] Iniciando processamento dos arquivos: mic = \(micFile.path), sys = \(systemFiles.first?.path ?? "<nenhum>")")
            
            // Check if system audio file exists and should be combined
            if let systemFile = systemFiles.first,
               audioFileManager.fileExists(at: systemFile.path) {
                
                // Verificar tamanho e validez dos arquivos
                guard let micSize = audioFileManager.getFileSize(at: micFile.path),
                      let sysSize = audioFileManager.getFileSize(at: systemFile.path) else {
                    print("[DEBUG] Não foi possível obter o tamanho de um dos arquivos")
                    logger.error("Falha ao obter tamanho dos arquivos", category: .file)
                    return micFile.path
                }
                
                print("[DEBUG] Tamanho dos arquivos - mic: \(micSize) bytes, sys: \(sysSize) bytes")
                
                // Verificar se os arquivos têm tamanho válido
                guard micSize > 0, sysSize > 0 else {
                    print("[DEBUG] Um dos arquivos está vazio - mic: \(micSize), sys: \(sysSize)")
                    logger.error("Arquivos de áudio vazios", category: .file)
                    return micFile.path
                }
                
                // NOVA ABORDAGEM: Usar diretamente o método alternativo baseado em AVAsset
                // sem tentar usar AVAudioFile primeiro
                let outputPath = micFile.path.replacingOccurrences(of: "_mic.m4a", with: "_combined.m4a")
                print("[DEBUG] Usando diretamente método alternativo de combinação")
                
                do {
                    let combinedPath = try combineAudioFilesSimple(
                        micPath: micFile.path,
                        sysPath: systemFile.path,
                        outputPath: outputPath
                    )
                    print("[DEBUG] Combinação alternativa bem-sucedida: \(combinedPath)")
                    return combinedPath
                } catch {
                    print("[DEBUG] Método alternativo falhou: \(error)")
                    logger.error("Falha ao combinar arquivos com método alternativo", error: error, category: .file)
                    return micFile.path // Fallback
                }
                
            } else {
                if systemFiles.isEmpty {
                    logger.error("[LOG DIAGNÓSTICO] Nenhum arquivo de áudio do sistema encontrado para combinar. Apenas o arquivo do microfone será usado.", category: .file)
                    print("[DEBUG] Nenhum arquivo de áudio do sistema encontrado para combinar.")
                } else {
                    logger.error("[LOG DIAGNÓSTICO] Arquivo de áudio do sistema existe na lista, mas não existe no disco.", category: .file)
                    print("[DEBUG] Arquivo de áudio do sistema existe na lista, mas não existe no disco.")
                }
                logger.fileOperation("Using microphone-only recording")
                print("[DEBUG] Usando apenas o arquivo do microfone: \(micFile.path)")
                return micFile.path
            }
        }
    }
    
    // Método simplificado para combinação de arquivos usando AVAssetExportSession
    // Esta versão usa apenas chamadas síncronas para evitar problemas de concorrência
    private func combineAudioFilesSimple(micPath: String, sysPath: String, outputPath: String) throws -> String {
        print("[DEBUG] Iniciando combinação simplificada")
        
        // Verificar explicitamente se os arquivos existem e são acessíveis
        guard FileManager.default.fileExists(atPath: micPath),
              FileManager.default.fileExists(atPath: sysPath) else {
            print("[DEBUG] Um dos arquivos não existe ou não é acessível")
            throw NSError(domain: "AudioFileService", code: 5, userInfo: [NSLocalizedDescriptionKey: "Arquivos não existem ou não são acessíveis"])
        }
        
        // Verificar tamanho dos arquivos
        guard let micSize = audioFileManager.getFileSize(at: micPath),
              let sysSize = audioFileManager.getFileSize(at: sysPath),
              micSize > 0, sysSize > 0 else {
            print("[DEBUG] Um dos arquivos está vazio ou não pode ter seu tamanho determinado")
            throw NSError(domain: "AudioFileService", code: 6, userInfo: [NSLocalizedDescriptionKey: "Arquivos vazios ou inacessíveis"])
        }
        
        print("[DEBUG] Verificação de arquivos OK - mic: \(micSize) bytes, sys: \(sysSize) bytes")
        
        // Criar AVAssets a partir dos caminhos
        let micAsset = AVAsset(url: URL(fileURLWithPath: micPath))
        let sysAsset = AVAsset(url: URL(fileURLWithPath: sysPath))
        
        // Criar composição
        let composition = AVMutableComposition()
        guard let compositionTrack = composition.addMutableTrack(
            withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            throw NSError(domain: "AudioFileService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Não foi possível criar faixa de composição"])
        }
        
        // Adicionar faixa de microfone
        let micTracks = micAsset.tracks(withMediaType: .audio)
        if let micTrack = micTracks.first {
            let timeRange = CMTimeRange(start: .zero, duration: micAsset.duration)
            do {
                try compositionTrack.insertTimeRange(timeRange, of: micTrack, at: .zero)
                print("[DEBUG] Faixa de microfone adicionada à composição")
            } catch {
                print("[DEBUG] Erro ao adicionar faixa de microfone: \(error)")
                throw error
            }
        } else {
            print("[DEBUG] Microfone não possui faixas de áudio")
            throw NSError(domain: "AudioFileService", code: 3, userInfo: [NSLocalizedDescriptionKey: "Microfone não tem faixas de áudio"])
        }
        
        // Adicionar faixa de sistema
        let sysTracks = sysAsset.tracks(withMediaType: .audio)
        if let sysTrack = sysTracks.first {
            if let compositionTrack2 = composition.addMutableTrack(
                withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) {
                do {
                    let timeRange = CMTimeRange(start: .zero, duration: sysAsset.duration)
                    try compositionTrack2.insertTimeRange(timeRange, of: sysTrack, at: .zero)
                    print("[DEBUG] Faixa de sistema adicionada à composição")
                } catch {
                    print("[DEBUG] Erro ao adicionar faixa de sistema: \(error)")
                    throw error
                }
            }
        } else {
            print("[DEBUG] Sistema não possui faixas de áudio")
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
        exportSession.audioMix = createAudioMixSimple(micAsset: micAsset, sysAsset: sysAsset)
        
        print("[DEBUG] Configuração de exportação - outputURL: \(outputURL.path), outputFileType: m4a")
        
        // Exportar de forma síncrona
        let semaphore = DispatchSemaphore(value: 0)
        
        exportSession.exportAsynchronously {
            if let error = exportSession.error {
                print("[DEBUG] Erro durante exportação: \(error)")
            } else {
                print("[DEBUG] Exportação concluída com sucesso")
            }
            semaphore.signal()
        }
        
        // Aguardar com um timeout de 30 segundos
        let waitResult = semaphore.wait(timeout: .now() + 30)
        if waitResult == .timedOut {
            print("[DEBUG] Timeout na exportação")
            throw NSError(domain: "AudioFileService", code: 7, userInfo: [NSLocalizedDescriptionKey: "Timeout na exportação"])
        }
        
        if let error = exportSession.error {
            print("[DEBUG] Erro na exportação: \(error)")
            throw error
        }
        
        // Verificar se o arquivo de saída foi criado
        if FileManager.default.fileExists(atPath: outputPath) {
            let fileSize = audioFileManager.getFileSize(at: outputPath) ?? 0
            print("[DEBUG] Arquivo combinado criado: \(outputPath) (\(fileSize) bytes)")
            return outputPath
        } else {
            print("[DEBUG] Exportação concluída, mas arquivo não encontrado")
            throw NSError(domain: "AudioFileService", code: 4, userInfo: [NSLocalizedDescriptionKey: "Arquivo exportado não encontrado"])
        }
    }
    
    // Criar um AudioMix para ajustar os volumes das faixas - versão simplificada
    private func createAudioMixSimple(micAsset: AVAsset, sysAsset: AVAsset) -> AVAudioMix {
        let audioMix = AVMutableAudioMix()
        var audioMixParams: [AVMutableAudioMixInputParameters] = []
        
        // Parâmetros para microfone (volume 0.8)
        if let micTrack = micAsset.tracks(withMediaType: .audio).first {
            let micParams = AVMutableAudioMixInputParameters(track: micTrack)
            micParams.setVolume(0.8, at: .zero)
            audioMixParams.append(micParams)
            print("[DEBUG] Parâmetros de áudio para microfone: volume 0.8")
        }
        
        // Parâmetros para sistema (volume 0.7)
        if let sysTrack = sysAsset.tracks(withMediaType: .audio).first {
            let sysParams = AVMutableAudioMixInputParameters(track: sysTrack)
            sysParams.setVolume(0.7, at: .zero)
            audioMixParams.append(sysParams)
            print("[DEBUG] Parâmetros de áudio para sistema: volume 0.7")
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
                print("[DEBUG] Fechando explicitamente os arquivos de áudio...")
                
                // A maneira segura de "fechar" um AVAudioFile é simplesmente
                // remover a referência a ele, o que libera os recursos.
                self.microphoneFile = nil
                self.systemAudioFile = nil
                
                continuation.resume()
            }
        }
        
        // Aguardar mais um pouco para garantir que o sistema tenha tempo de liberar os recursos
        print("[DEBUG] Esperando o sistema liberar os recursos dos arquivos...")
        try? await Task.sleep(nanoseconds: 500_000_000) // 500 ms
        
        // Log final diagnostics
        diagnostics.logFinalDiagnostics()
        
        // Cleanup temporary files if needed
        if let meetingId = currentMeetingId {
            audioFileManager.cleanupTemporaryFiles(for: meetingId)
        }
        
        print("[DEBUG] Finalização dos arquivos concluída")
        // NÃO limpar o currentMeetingId aqui, pois ele é necessário para processRecordingFiles
        // currentMeetingId = nil
    }
    
    /// Limpar o estado interno após o processamento dos arquivos
    func cleanupState() {
        print("[DEBUG] Limpando estado interno do AudioFileService")
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
            return
        }
        
        // Validate format compatibility
        let fileFormat = sysFile.processingFormat
        let bufferFormat = buffer.format
        
        guard diagnostics.validateAudioFormats(fileFormat: fileFormat, bufferFormat: bufferFormat) else {
            logger.error("Audio format incompatibility detected", category: .file)
            return
        }
        
        do {
            try sysFile.write(from: buffer)
            diagnostics.trackSystemAudioFileWrite()
        } catch {
            logger.critical("Failed to write system audio", error: error, category: .file)
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