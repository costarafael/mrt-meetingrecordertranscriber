import Foundation
import AVFoundation

/// Protocolo para gerenciamento de arquivos de áudio
protocol AudioFileManagerProtocol {
    
    // MARK: - File Creation
    
    /// Criar arquivo de áudio para gravação
    /// - Parameters:
    ///   - meetingId: ID da reunião
    ///   - configuration: Configuração de áudio
    ///   - type: Tipo do arquivo (microfone, sistema, combinado)
    /// - Returns: Arquivo de áudio criado
    func createAudioFile(
        for meetingId: UUID,
        configuration: AudioConfiguration,
        type: AudioFileType
    ) throws -> AVAudioFile
    
    // MARK: - File Management
    
    /// Excluir arquivos temporários
    /// - Parameter meetingId: ID da reunião
    func cleanupTemporaryFiles(for meetingId: UUID)
    
    /// Obter diretório de áudio
    /// - Returns: URL do diretório de áudio
    func getAudioDirectory() -> URL
    
    /// Verificar se arquivo existe
    /// - Parameter path: Caminho do arquivo
    /// - Returns: True se o arquivo existe
    func fileExists(at path: String) -> Bool
    
    /// Obter tamanho do arquivo
    /// - Parameter path: Caminho do arquivo
    /// - Returns: Tamanho em bytes
    func getFileSize(at path: String) -> UInt64?
    
    /// Obter duração do arquivo de áudio
    /// - Parameter path: Caminho do arquivo
    /// - Returns: Duração em segundos
    func getAudioDuration(at path: String) -> TimeInterval?
    
    /// Listar arquivos de áudio
    /// - Parameter meetingId: ID da reunião
    /// - Returns: Lista de informações de arquivo de áudio
    func listAudioFiles(for meetingId: UUID?) -> [AudioFileInfo]
}

// MARK: - Supporting Types

/// Tipos de arquivo de áudio
enum AudioFileType: String, CaseIterable {
    case microphone = "microphone"
    case systemAudio = "system"
    case combined = "combined"
    case temporary = "temp"
    
    /// Sufixo para o nome do arquivo
    var fileSuffix: String {
        switch self {
        case .microphone:
            return "_mic"
        case .systemAudio:
            return "_sys"
        case .combined:
            return "_combined"
        case .temporary:
            return "_temp"
        }
    }
}

/// Informações sobre arquivo de áudio
struct AudioFileInfo {
    let path: String
    let type: AudioFileType
    let volume: Float
    
    init(path: String, type: AudioFileType, volume: Float = 1.0) {
        self.path = path
        self.type = type
        self.volume = volume
    }
}

/// Resultado de operação de arquivo
enum AudioFileOperationResult {
    case success(path: String)
    case failure(error: Error)
} 