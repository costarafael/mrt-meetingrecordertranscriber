import Foundation

/// Protocolo para estratégias de fallback em caso de falhas no sistema de áudio
public protocol FallbackStrategy {
    /// Tenta tratar um erro de áudio
    /// - Parameter error: O erro que ocorreu
    /// - Returns: Boolean indicando se o erro foi tratado com sucesso
    func handleError(_ error: AudioError) -> Bool
    
    /// Retorna uma configuração alternativa para casos de fallback
    /// - Returns: Uma configuração de áudio alternativa
    func getFallbackConfiguration() -> AudioConfiguration
    
    /// Registra evento de fallback no log
    /// - Parameters:
    ///   - error: O erro original que causou o fallback
    ///   - success: Se o fallback foi bem-sucedido
    func logFallbackEvent(error: AudioError, success: Bool)
}

/// Estrutura de configuração de áudio para fallback
public struct AudioConfiguration {
    let sampleRate: Double
    let channels: Int
    let bitDepth: Int
    let isSystemAudioEnabled: Bool
    
    public init(
        sampleRate: Double = 44100,
        channels: Int = 2,
        bitDepth: Int = 16,
        isSystemAudioEnabled: Bool = false
    ) {
        self.sampleRate = sampleRate
        self.channels = channels
        self.bitDepth = bitDepth
        self.isSystemAudioEnabled = isSystemAudioEnabled
    }
}

/// Implementação padrão de FallbackStrategy
public class DefaultFallbackStrategy: FallbackStrategy {
    private let logger = LoggingService.shared
    
    public init() {}
    
    public func handleError(_ error: AudioError) -> Bool {
        // Implementação do tratamento de erro
        switch error {
        case .deviceNotFound:
            logger.warning("Fallback: Dispositivo não encontrado, usando dispositivo padrão", category: .audio)
            return true
            
        case .formatMismatch:
            logger.warning("Fallback: Formato incompatível, usando formato padrão", category: .audio)
            return true
            
        case .systemAudioNotSupported:
            logger.warning("Fallback: Áudio do sistema não suportado, desabilitando captura do sistema", category: .audio)
            return true
            
        default:
            return false
        }
    }
    
    public func getFallbackConfiguration() -> AudioConfiguration {
        // Configuração mais simples e compatível
        return AudioConfiguration(
            sampleRate: 44100,
            channels: 1,
            bitDepth: 16,
            isSystemAudioEnabled: false
        )
    }
    
    public func logFallbackEvent(error: AudioError, success: Bool) {
        if success {
            logger.info("✅ Fallback aplicado com sucesso para erro: \(error.localizedDescription)", category: .audio)
        } else {
            logger.error("❌ Fallback falhou para erro: \(error.localizedDescription)", category: .audio)
        }
    }
} 