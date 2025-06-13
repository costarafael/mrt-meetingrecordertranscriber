import Foundation

/// Protocolo para sincronização de áudio entre múltiplas fontes
protocol AudioSynchronizerProtocol {
    /// Verificar se a sincronização foi inicializada
    var isInitialized: Bool { get }
    
    /// Inicializar sincronização com timestamps iniciais
    /// - Parameters:
    ///   - systemTime: Timestamp inicial do áudio do sistema
    ///   - microphoneTime: Timestamp inicial do áudio do microfone
    func initializeSync(systemTime: UInt64, microphoneTime: UInt64)
    
    /// Calcular offset de sincronização
    /// - Parameters:
    ///   - systemTime: Timestamp atual do áudio do sistema
    ///   - microphoneTime: Timestamp atual do áudio do microfone
    /// - Returns: Diferença de tempo em segundos
    func calculateSyncOffset(systemTime: UInt64, microphoneTime: UInt64) -> TimeInterval
    
    /// Reset da sincronização
    func resetSync()
    
    func combineAudioFiles(
        files: [AudioFileInfo],
        outputPath: String,
        mixingConfig: AudioMixingConfiguration
    ) throws -> String
}

// MARK: - Modelo de Sincronização

/// Dados de sincronização de áudio
struct AudioSyncData {
    let systemTimestamp: UInt64
    let microphoneTimestamp: UInt64
    let calculatedOffset: TimeInterval
    let isValid: Bool
    
    init(systemTimestamp: UInt64, microphoneTimestamp: UInt64, calculatedOffset: TimeInterval) {
        self.systemTimestamp = systemTimestamp
        self.microphoneTimestamp = microphoneTimestamp
        self.calculatedOffset = calculatedOffset
        self.isValid = abs(calculatedOffset) < 1.0 // Offset válido se menor que 1 segundo
    }
} 