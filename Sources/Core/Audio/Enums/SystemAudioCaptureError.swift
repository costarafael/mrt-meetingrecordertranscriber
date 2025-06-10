import Foundation

/// Erros relacionados à captura de áudio do sistema
enum SystemAudioCaptureError: Error, LocalizedError {
    case systemVersionNotSupported
    case permissionDenied
    case noDisplayFound
    case captureStartFailed(Error)
    case configurationFailed
    case internalError
    
    var errorDescription: String? {
        switch self {
        case .systemVersionNotSupported:
            return "Versão do sistema não suporta captura de áudio do sistema (mínimo macOS 13.0)"
        case .permissionDenied:
            return "Permissão negada para captura de áudio do sistema"
        case .noDisplayFound:
            return "Nenhum display encontrado para captura"
        case .captureStartFailed(let error):
            return "Falha ao iniciar captura: \(error.localizedDescription)"
        case .configurationFailed:
            return "Falha na configuração do sistema de captura"
        case .internalError:
            return "Erro interno do sistema de captura"
        }
    }
} 