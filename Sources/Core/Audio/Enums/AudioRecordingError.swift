import Foundation

/// Erros relacionados à gravação de áudio
enum AudioRecordingError: Error {
    case engineSetupFailed
    case permissionDenied
    case fileCreationFailed
    case deviceNotFound
    
    var localizedDescription: String {
        switch self {
        case .engineSetupFailed:
            return "Falha ao configurar o motor de áudio"
        case .permissionDenied:
            return "Permissão de microfone negada"
        case .fileCreationFailed:
            return "Falha ao criar arquivo de áudio"
        case .deviceNotFound:
            return "Dispositivo de áudio não encontrado"
        }
    }
} 