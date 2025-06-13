import Foundation
import OSLog
import AVFoundation

/// Sincronizador responsável por alinhar e combinar áudio do microfone e sistema
class AudioSynchronizer: AudioSynchronizerProtocol {
    private var initialSystemTime: UInt64 = 0
    private var initialMicTime: UInt64 = 0
    private let logger = Logger(subsystem: "AudioRecording", category: "Synchronizer")
    
    /// Verificar se a sincronização foi inicializada
    var isInitialized: Bool = false
    
    func initializeSync(systemTime: UInt64, microphoneTime: UInt64) {
        initialSystemTime = systemTime
        initialMicTime = microphoneTime
        isInitialized = true
        logger.info("Sincronização inicializada - System: \(systemTime), Mic: \(microphoneTime)")
    }
    
    func calculateSyncOffset(systemTime: UInt64, microphoneTime: UInt64) -> TimeInterval {
        guard isInitialized else { return 0 }
        
        let systemOffset = Int64(systemTime - initialSystemTime)
        let micOffset = Int64(microphoneTime - initialMicTime)
        let timeDifference = systemOffset - micOffset
        
        // Converter para segundos
        return Double(timeDifference) / 1_000_000_000.0
    }
    
    func resetSync() {
        isInitialized = false
        initialSystemTime = 0
        initialMicTime = 0
        logger.info("Sincronização resetada")
    }
    
    // MARK: - Audio Combination (Moved from AudioFileManager)

    func combineAudioFiles(
        files: [AudioFileInfo],
        outputPath: String,
        mixingConfig: AudioMixingConfiguration
    ) throws -> String {
        logger.info("🎵 Combinando \(files.count) arquivos de áudio com sincronização...")
        
        guard isInitialized else {
            logger.error("❌ Sincronizador não inicializado. Não é possível combinar.")
            throw AudioFileManagerError.incompatibleFormats // Reutilizar erro
        }
        
        guard files.count >= 2 else {
            throw AudioFileManagerError.insufficientFiles
        }
        
        // Verificar cada arquivo individualmente antes de combiná-los
        let verifiedFiles = try verifyFiles(files)
        
        // Criar arquivo de saída
        let outputURL = URL(fileURLWithPath: outputPath)
        
        // Remover arquivo existente se necessário para evitar conflitos
        if FileManager.default.fileExists(atPath: outputPath) {
            try FileManager.default.removeItem(at: URL(fileURLWithPath: outputPath))
        }
        
        let referenceFormat = verifiedFiles[0].0.processingFormat
        let outputSettings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: referenceFormat.sampleRate,
            AVNumberOfChannelsKey: 1, // Saída sempre mono
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue
        ]
        
        do {
            let outputFile = try AVAudioFile(forWriting: outputURL, settings: outputSettings)
            
            // Processar
            try combineAudioFilesInternal(audioFiles: verifiedFiles, outputFile: outputFile, mixingConfig: mixingConfig)
            
            logger.info("✅ Arquivos combinados com sucesso: \(outputPath)")
            return outputPath
        } catch {
            logger.error("❌ Erro ao criar arquivo de saída: \(error)")
            throw error
        }
    }
    
    // Função auxiliar para verificar cada arquivo individualmente
    private func verifyFiles(_ files: [AudioFileInfo]) throws -> [(AVAudioFile, AudioFileInfo)] {
        var result: [(AVAudioFile, AudioFileInfo)] = []
        
        for fileInfo in files {
            do {
                let url = URL(fileURLWithPath: fileInfo.path)
                let file = try AVAudioFile(forReading: url)
                logger.info("✅ Arquivo \(fileInfo.type.rawValue) verificado: \(file.length) frames")
                result.append((file, fileInfo))
            } catch {
                logger.error("❌ Erro ao verificar arquivo \(fileInfo.type.rawValue): \(error)")
                throw AudioFileManagerError.fileNotFound(path: fileInfo.path)
            }
        }
        
        return result
    }

    private func combineAudioFilesInternal(
        audioFiles: [(AVAudioFile, AudioFileInfo)],
        outputFile: AVAudioFile,
        mixingConfig: AudioMixingConfiguration
    ) throws {
        let bufferSize: AVAudioFrameCount = 4096
        let outputFormat = outputFile.processingFormat
        let sampleRate = outputFormat.sampleRate

        // Calcular offset de tempo e de frames
        let timeDifference = Int64(initialSystemTime) - Int64(initialMicTime)
        let timeOffsetSeconds = Double(timeDifference) / 1_000_000_000.0
        let frameOffset = AVAudioFramePosition(abs(timeOffsetSeconds) * sampleRate)

        logger.info("🕒 Offset de sincronização: \(String(format: "%.3f", timeOffsetSeconds))s (\(frameOffset) frames)")

        // Identificar arquivos
        guard let micFile = audioFiles.first(where: { $0.1.type == .microphone })?.0,
              let sysFile = audioFiles.first(where: { $0.1.type == .systemAudio })?.0 else {
            throw AudioFileManagerError.fileNotFound(path: "mic or sys")
        }

        // CORREÇÃO: Avançar o arquivo que começou PRIMEIRO
        if timeOffsetSeconds > 0 {
            logger.info("🎤 Microfone começou primeiro. Avançando \(frameOffset) frames.")
            micFile.framePosition = frameOffset
        } else {
            logger.info("🔊 Áudio do sistema começou primeiro. Avançando \(frameOffset) frames.")
            sysFile.framePosition = frameOffset
        }

        // O comprimento máximo agora é calculado a partir dos pontos de início alinhados
        let maxLength = max(micFile.length - micFile.framePosition, sysFile.length - sysFile.framePosition)
        var processedFrames: AVAudioFramePosition = 0

        while processedFrames < maxLength {
            // Criar buffers para os inputs e o output
            guard let micBuffer = AVAudioPCMBuffer(pcmFormat: micFile.processingFormat, frameCapacity: bufferSize),
                  let sysBuffer = AVAudioPCMBuffer(pcmFormat: sysFile.processingFormat, frameCapacity: bufferSize),
                  let outputBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: bufferSize) else {
                throw AudioFileManagerError.bufferCreationFailed
            }

            // Ler dados dos arquivos de origem
            try micFile.framePosition < micFile.length ? micFile.read(into: micBuffer) : nil
            try sysFile.framePosition < sysFile.length ? sysFile.read(into: sysBuffer) : nil

            // Definir o tamanho do buffer de saída
            let framesToProcess = max(micBuffer.frameLength, sysBuffer.frameLength)
            if framesToProcess == 0 { break }
            outputBuffer.frameLength = framesToProcess

            // Zerar o buffer de saída antes da mixagem
            if let channelData = outputBuffer.floatChannelData?[0] {
                for i in 0..<Int(framesToProcess) { channelData[i] = 0.0 }
            }

            // Mixar os buffers
            mix(sourceBuffer: micBuffer, to: outputBuffer, volume: 0.8)
            mix(sourceBuffer: sysBuffer, to: outputBuffer, volume: 0.7)

            try outputFile.write(from: outputBuffer)
            processedFrames += AVAudioFramePosition(framesToProcess)
        }
    }

    private func mix(sourceBuffer: AVAudioPCMBuffer, to outputBuffer: AVAudioPCMBuffer, volume: Float) {
        guard let sourceData = sourceBuffer.floatChannelData?[0],
              let outputData = outputBuffer.floatChannelData?[0] else { return }

        let framesToMix = min(sourceBuffer.frameLength, outputBuffer.frameLength)
        guard framesToMix > 0 else { return }

        for i in 0..<Int(framesToMix) {
            let sample = sourceData[i] * volume
            outputData[i] += sample
            outputData[i] = max(-1.0, min(1.0, outputData[i])) // Limitar para evitar clipping
        }
    }
} 