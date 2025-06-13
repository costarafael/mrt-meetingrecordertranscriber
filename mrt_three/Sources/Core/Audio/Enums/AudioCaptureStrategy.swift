import Foundation

/// Estratégias disponíveis para captura de áudio do sistema
enum AudioCaptureStrategy: String, CaseIterable {
    case screenCaptureKit = "screenCaptureKit"      // macOS 13.0+
    case coreAudioTaps = "coreAudioTaps"          // macOS 14.2+
    case microphoneOnly = "microphoneOnly"        // Fallback - apenas microfone
} 