import Foundation

/// Erros padronizados para o sistema de áudio
public enum AudioError: Error, Equatable {
    case permissionDenied
    case deviceNotFound
    case formatMismatch
    case fileOperationFailed(String)
    case systemAudioNotSupported
    case captureFailed(String)
    case invalidConfiguration
    case synchronizationFailed
    
    /// Mensagem descritiva do erro
    public var localizedDescription: String {
        switch self {
        case .permissionDenied:
            return "Permissão de acesso ao microfone negada"
        case .deviceNotFound:
            return "Dispositivo de áudio não encontrado"
        case .formatMismatch:
            return "Formato de áudio incompatível"
        case .fileOperationFailed(let details):
            return "Operação de arquivo falhou: \(details)"
        case .systemAudioNotSupported:
            return "Captura de áudio do sistema não suportada nesta versão do macOS"
        case .captureFailed(let details):
            return "Falha na captura de áudio: \(details)"
        case .invalidConfiguration:
            return "Configuração de áudio inválida"
        case .synchronizationFailed:
            return "Falha na sincronização de áudio"
        }
    }
} 