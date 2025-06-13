import Foundation
import AVFoundation
import OSLog

/// Service especializado para gerenciamento de arquivos de áudio
class AudioFileManager: AudioFileManagerProtocol {
    
    // MARK: - Private Properties
    
    private let logger = Logger(subsystem: "AudioRecording", category: "FileManager")
    private let fileManager = FileManager.default
    
    // MARK: - AudioFileManagerProtocol Methods
    
    func createAudioFile(
        for meetingId: UUID,
        configuration: AudioConfiguration,
        type: AudioFileType
    ) throws -> AVAudioFile {
        logger.info("📁 Criando arquivo de áudio: \(type.rawValue) para reunião \(meetingId)")
        
        // Criar diretório se não existir
        let audioDirectory = getAudioDirectory()
        try fileManager.createDirectory(at: audioDirectory, withIntermediateDirectories: true)
        
        // Gerar nome do arquivo
        let fileName = generateFileName(for: meetingId, type: type, format: configuration.outputFormat)
        let fileURL = audioDirectory.appendingPathComponent(fileName)
        
        // Configurar settings do arquivo
        let audioSettings = createAudioSettings(from: configuration)
        
        // Criar arquivo de áudio
        let audioFile = try AVAudioFile(forWriting: fileURL, settings: audioSettings)
        
        logger.info("✅ Arquivo criado: \(fileURL.path)")
        logger.info("📊 Formato: \(configuration.sampleRate)Hz, \(configuration.channels) canais, \(configuration.outputFormat.rawValue)")
        
        return audioFile
    }
    
    func cleanupTemporaryFiles(for meetingId: UUID) {
        logger.info("🗑️ Limpando arquivos temporários para reunião \(meetingId)")
        
        let audioDirectory = getAudioDirectory()
        let meetingIdString = meetingId.uuidString
        
        do {
            let contents = try fileManager.contentsOfDirectory(at: audioDirectory, includingPropertiesForKeys: nil)
            
            for fileURL in contents {
                let fileName = fileURL.lastPathComponent
                
                // Verificar se é arquivo temporário desta reunião
                if fileName.contains(meetingIdString) && 
                   (fileName.contains(AudioFileType.temporary.fileSuffix)) {
                    
                    try fileManager.removeItem(at: fileURL)
                    logger.info("🗑️ Arquivo removido: \(fileName)")
                }
            }
        } catch {
            logger.error("❌ Erro ao limpar arquivos temporários: \(error)")
        }
    }
    
    func getAudioDirectory() -> URL {
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent("MeetingRecordings")
    }
    
    func fileExists(at path: String) -> Bool {
        return fileManager.fileExists(atPath: path)
    }
    
    func getFileSize(at path: String) -> UInt64? {
        do {
            let attributes = try fileManager.attributesOfItem(atPath: path)
            return attributes[.size] as? UInt64
        } catch {
            logger.error("❌ Erro ao obter tamanho do arquivo: \(error)")
            return nil
        }
    }
    
    func getAudioDuration(at path: String) -> TimeInterval? {
        do {
            let audioFile = try AVAudioFile(forReading: URL(fileURLWithPath: path))
            let duration = Double(audioFile.length) / audioFile.processingFormat.sampleRate
            return duration
        } catch {
            logger.error("❌ Erro ao obter duração do arquivo: \(error)")
            return nil
        }
    }
    
    // MARK: - Private Helper Methods
    
    private func generateFileName(for meetingId: UUID, type: AudioFileType, format: AudioOutputFormat) -> String {
        let meetingIdString = meetingId.uuidString
        let suffix = type.fileSuffix
        let fileExtension = format.fileExtension
        
        return "\(meetingIdString)\(suffix).\(fileExtension)"
    }
    
    private func createAudioSettings(from configuration: AudioConfiguration) -> [String: Any] {
        return [
            AVFormatIDKey: Int(configuration.outputFormat.formatID),
            AVSampleRateKey: configuration.sampleRate,
            AVNumberOfChannelsKey: configuration.channels,
            AVEncoderAudioQualityKey: configuration.encoderQuality.rawValue,
            AVEncoderBitRateKey: configuration.bitRate
        ]
    }
    
    // MARK: - Utility Methods
    
    func listAudioFiles(for meetingId: UUID? = nil) -> [AudioFileInfo] {
        var audioFiles: [AudioFileInfo] = []
        
        do {
            let audioDirectory = getAudioDirectory()
            let contents = try fileManager.contentsOfDirectory(at: audioDirectory, includingPropertiesForKeys: nil)
            
            for fileURL in contents {
                let fileName = fileURL.lastPathComponent
                
                // Filtrar por reunião se especificado
                if let meetingId = meetingId {
                    guard fileName.contains(meetingId.uuidString) else { continue }
                }
                
                // Determinar tipo do arquivo
                let fileType: AudioFileType
                if fileName.contains(AudioFileType.systemAudio.fileSuffix) {
                    fileType = .systemAudio
                } else if fileName.contains(AudioFileType.combined.fileSuffix) {
                    fileType = .combined
                } else if fileName.contains(AudioFileType.temporary.fileSuffix) {
                    fileType = .temporary
                } else {
                    fileType = .microphone
                }
                
                let audioFileInfo = AudioFileInfo(
                    path: fileURL.path,
                    type: fileType
                )
                
                audioFiles.append(audioFileInfo)
            }
        } catch {
            logger.error("❌ Erro ao listar arquivos de áudio: \(error)")
        }
        
        return audioFiles
    }
}

// MARK: - Error Types

enum AudioFileManagerError: Error, LocalizedError {
    case insufficientFiles
    case fileNotFound(path: String)
    case incompatibleFormats
    case bufferCreationFailed
    case writeFailed
    
    var errorDescription: String? {
        switch self {
        case .insufficientFiles:
            return "Arquivos insuficientes para combinação (mínimo 2)"
        case .fileNotFound(let path):
            return "Arquivo não encontrado: \(path)"
        case .incompatibleFormats:
            return "Formatos de áudio incompatíveis"
        case .bufferCreationFailed:
            return "Falha ao criar buffer de áudio"
        case .writeFailed:
            return "Falha ao escrever arquivo de áudio"
        }
    }
} 