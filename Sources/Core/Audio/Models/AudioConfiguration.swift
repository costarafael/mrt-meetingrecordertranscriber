import Foundation
import AVFoundation

/// Configuração principal para gravação de áudio
struct AudioConfiguration {
    /// Configuração de sample rate
    let sampleRate: Double
    
    /// Número de canais
    let channels: UInt32
    
    /// Qualidade do encoder
    let encoderQuality: AVAudioQuality
    
    /// Bit rate do encoder
    let bitRate: Int
    
    /// Formato de arquivo de saída
    let outputFormat: AudioOutputFormat
    
    /// Tamanho do buffer de captura
    let bufferSize: AVAudioFrameCount
    
    /// Estratégia de captura
    let captureStrategy: AudioCaptureStrategy
    
    /// Configuração específica do microfone
    let microphoneConfig: MicrophoneConfiguration?
    
    /// Configuração específica do áudio do sistema
    let systemAudioConfig: SystemAudioConfiguration?
    
    /// Inicializador com valores padrão otimizados
    init(
        sampleRate: Double = 16000.0,
        channels: UInt32 = 1,
        encoderQuality: AVAudioQuality = .medium,
        bitRate: Int = 32000,
        outputFormat: AudioOutputFormat = .m4a,
        bufferSize: AVAudioFrameCount = 1024,
        captureStrategy: AudioCaptureStrategy = .microphoneOnly,
        microphoneConfig: MicrophoneConfiguration? = nil,
        systemAudioConfig: SystemAudioConfiguration? = nil
    ) {
        self.sampleRate = sampleRate
        self.channels = channels
        self.encoderQuality = encoderQuality
        self.bitRate = bitRate
        self.outputFormat = outputFormat
        self.bufferSize = bufferSize
        self.captureStrategy = captureStrategy
        self.microphoneConfig = microphoneConfig
        self.systemAudioConfig = systemAudioConfig
    }
    
    /// Configuração padrão para microfone apenas
    static let microphoneOnly = AudioConfiguration(
        captureStrategy: .microphoneOnly,
        microphoneConfig: MicrophoneConfiguration.default
    )
    
    /// Configuração padrão para áudio misto (microfone + sistema)
    static let mixed = AudioConfiguration(
        captureStrategy: .screenCaptureKit,
        microphoneConfig: MicrophoneConfiguration.default,
        systemAudioConfig: SystemAudioConfiguration.default
    )
}

/// Configuração específica para captura de microfone
struct MicrophoneConfiguration {
    /// Dispositivo de entrada (nil = dispositivo padrão)
    let inputDevice: AudioDevice?
    
    /// Habilitar cancelamento de ruído
    let enableNoiseCancellation: Bool
    
    /// Habilitar supressão de eco
    let enableEchoSuppression: Bool
    
    /// Ganho do microfone (0.0 a 1.0)
    let gain: Float
    
    init(
        inputDevice: AudioDevice? = nil,
        enableNoiseCancellation: Bool = true,
        enableEchoSuppression: Bool = true,
        gain: Float = 0.8
    ) {
        self.inputDevice = inputDevice
        self.enableNoiseCancellation = enableNoiseCancellation
        self.enableEchoSuppression = enableEchoSuppression
        self.gain = max(0.0, min(1.0, gain))
    }
    
    static let `default` = MicrophoneConfiguration()
}

/// Configuração específica para captura de áudio do sistema
struct SystemAudioConfiguration {
    /// Excluir áudio do próprio processo
    let excludeCurrentProcess: Bool
    
    /// Configuração específica do ScreenCaptureKit
    let screenCaptureConfig: ScreenCaptureConfiguration?
    
    /// Mixagem com áudio do microfone
    let mixingConfiguration: AudioMixingConfiguration
    
    init(
        excludeCurrentProcess: Bool = true,
        screenCaptureConfig: ScreenCaptureConfiguration? = ScreenCaptureConfiguration.default,
        mixingConfiguration: AudioMixingConfiguration = AudioMixingConfiguration.default
    ) {
        self.excludeCurrentProcess = excludeCurrentProcess
        self.screenCaptureConfig = screenCaptureConfig
        self.mixingConfiguration = mixingConfiguration
    }
    
    static let `default` = SystemAudioConfiguration()
}

/// Configuração específica do ScreenCaptureKit
struct ScreenCaptureConfiguration {
    /// Sample rate nativo do ScreenCaptureKit
    let nativeSampleRate: Int
    
    /// Número de canais nativos
    let nativeChannels: Int
    
    /// Configuração de vídeo mínima (obrigatória)
    let minimumVideoConfig: MinimumVideoConfiguration
    
    init(
        nativeSampleRate: Int = 48000,
        nativeChannels: Int = 2,
        minimumVideoConfig: MinimumVideoConfiguration = MinimumVideoConfiguration.default
    ) {
        self.nativeSampleRate = nativeSampleRate
        self.nativeChannels = nativeChannels
        self.minimumVideoConfig = minimumVideoConfig
    }
    
    static let `default` = ScreenCaptureConfiguration()
}

/// Configuração mínima de vídeo para ScreenCaptureKit
struct MinimumVideoConfiguration {
    let width: Int
    let height: Int
    let frameRate: Int
    
    init(width: Int = 2, height: Int = 2, frameRate: Int = 1) {
        self.width = width
        self.height = height
        self.frameRate = frameRate
    }
    
    static let `default` = MinimumVideoConfiguration()
}

/// Configuração de mixagem de áudio
struct AudioMixingConfiguration {
    /// Volume do microfone (0.0 a 1.0)
    let microphoneVolume: Float
    
    /// Volume do áudio do sistema (0.0 a 1.0)
    let systemAudioVolume: Float
    
    /// Habilitar limitação de volume para evitar clipping
    let enableLimiter: Bool
    
    init(
        microphoneVolume: Float = 0.8,
        systemAudioVolume: Float = 0.6,
        enableLimiter: Bool = true
    ) {
        self.microphoneVolume = max(0.0, min(1.0, microphoneVolume))
        self.systemAudioVolume = max(0.0, min(1.0, systemAudioVolume))
        self.enableLimiter = enableLimiter
    }
    
    static let `default` = AudioMixingConfiguration()
}

/// Formatos de saída suportados
enum AudioOutputFormat: String, CaseIterable {
    case m4a = "m4a"
    case wav = "wav"
    case aac = "aac"
    
    /// Identificador do formato para AVFoundation
    var formatID: AudioFormatID {
        switch self {
        case .m4a, .aac:
            return kAudioFormatMPEG4AAC
        case .wav:
            return kAudioFormatLinearPCM
        }
    }
    
    /// Extensão do arquivo
    var fileExtension: String {
        return rawValue
    }
} 