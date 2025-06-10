import Foundation
import AVFoundation
import ScreenCaptureKit
import OSLog
import CoreMedia

// MARK: - Timeout Wrapper

/// Executa uma operação assíncrona com timeout
func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
    return try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask {
            try await operation()
        }
        
        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            throw ScreenCaptureKitError.configurationFailed
        }
        
        guard let result = try await group.next() else {
            throw ScreenCaptureKitError.configurationFailed
        }
        
        group.cancelAll()
        return result
    }
}

// MARK: - Pipeline ScreenCaptureKit

/// Pipeline para captura de áudio do sistema usando ScreenCaptureKit (macOS 13.0+)
@available(macOS 13.0, *)
class ScreenCaptureKitAudioPipeline: NSObject, SCStreamDelegate, SCStreamOutput, SystemAudioCaptureProtocol {
    private var stream: SCStream?
    private var _isCapturing = false
    private var _isPaused = false
    private let logger = Logger(subsystem: "AudioRecording", category: "ScreenCaptureKit")
    
    // 🔧 DIAGNÓSTICO: Contadores para debug
    private var audioSamplesReceived = 0
    
    // MARK: - AudioCaptureProtocol Properties
    
    var onAudioReceived: ((AVAudioPCMBuffer, UInt64) -> Void)?
    
    var isCapturing: Bool { _isCapturing }
    var isPaused: Bool { _isPaused }
    
    // MARK: - SystemAudioCaptureProtocol Properties
    
    var isSystemAudioSupported: Bool {
        let osVersion = ProcessInfo.processInfo.operatingSystemVersion
        return osVersion.majorVersion >= 13
    }
    
    // Legacy property para compatibilidade
    var onSystemAudioReceived: ((AVAudioPCMBuffer, UInt64) -> Void)? {
        get { onAudioReceived }
        set { onAudioReceived = newValue }
    }
    
    // MARK: - AudioCaptureProtocol Methods
    
    func startCapture(configuration: AudioConfiguration) async throws {
        logger.info("🎬 Iniciando captura ScreenCaptureKit...")
        
        // 🔧 DIAGNÓSTICO: Resetar contadores
        audioSamplesReceived = 0
        
        // 🔧 DIAGNÓSTICO: Log detalhado da configuração
        print("🔍 DIAGNÓSTICO - ScreenCaptureKit startCapture:")
        print("   • Estratégia: \(configuration.captureStrategy)")
        print("   • Sample Rate: \(configuration.sampleRate)Hz")
        print("   • Canais: \(configuration.channels)")
        print("   • systemAudioConfig: \(configuration.systemAudioConfig != nil ? "✅" : "❌")")
        
        guard isSystemAudioSupported else {
            print("❌ Sistema não suporta ScreenCaptureKit")
            throw SystemAudioCaptureError.systemVersionNotSupported
        }
        
        guard await requestSystemPermissions() else {
            print("❌ Permissões de ScreenCaptureKit negadas")
            throw SystemAudioCaptureError.permissionDenied
        }
        
        print("🔍 Obtendo conteúdo compartilhável...")
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
        
        guard let display = content.displays.first else {
            print("❌ Nenhum display encontrado")
            throw SystemAudioCaptureError.noDisplayFound
        }
        
        print("🔍 Display encontrado: \(display.width)x\(display.height)")
        
        let filter = SCContentFilter(display: display, excludingApplications: [], exceptingWindows: [])
        
        let config = SCStreamConfiguration()
        config.capturesAudio = true
        config.excludesCurrentProcessAudio = configuration.systemAudioConfig?.excludeCurrentProcess ?? true
        config.sampleRate = Int(configuration.sampleRate)
        config.channelCount = Int(configuration.channels)
        
        // 🔧 DIAGNÓSTICO: Log da configuração do SCStream
        print("🔍 Configuração SCStream:")
        print("   • capturesAudio: \(config.capturesAudio)")
        print("   • excludesCurrentProcessAudio: \(config.excludesCurrentProcessAudio)")
        print("   • sampleRate: \(config.sampleRate)")
        print("   • channelCount: \(config.channelCount)")
        
        stream = SCStream(filter: filter, configuration: config, delegate: self)
        
        do {
            print("🔍 Adicionando stream output...")
            try stream?.addStreamOutput(self, type: .audio, sampleHandlerQueue: DispatchQueue(label: "ScreenCaptureKit.AudioQueue"))
            
            print("🔍 Iniciando stream...")
            try await stream?.startCapture()
            
            _isCapturing = true
            _isPaused = false
            
            logger.info("✅ Captura ScreenCaptureKit iniciada")
            print("✅ ScreenCaptureKit: Stream iniciado com sucesso")
            
            // 🔧 DIAGNÓSTICO: Agendar verificação
            Task {
                try await Task.sleep(nanoseconds: 3_000_000_000) // 3 segundos
                await self.diagnosticCheck()
            }
            
        } catch {
            logger.error("❌ Erro ao iniciar captura: \(error)")
            print("❌ ERRO ScreenCaptureKit: \(error)")
            throw SystemAudioCaptureError.captureStartFailed(error)
        }
    }
    
    // 🔧 DIAGNÓSTICO: Verificação específica do ScreenCaptureKit
    private func diagnosticCheck() async {
        print("🔍 DIAGNÓSTICO - ScreenCaptureKit (após 3s):")
        print("   • Samples de áudio recebidos: \(audioSamplesReceived)")
        print("   • Stream ativo: \(_isCapturing)")
        print("   • Stream pausado: \(_isPaused)")
        
        if audioSamplesReceived == 0 {
            print("❌ PROBLEMA: ScreenCaptureKit não está recebendo áudio!")
            print("💡 Verificações:")
            print("   • Há áudio sendo reproduzido no sistema?")
            print("   • As permissões de ScreenCaptureKit foram concedidas?")
            print("   • O app está excluído em excludesCurrentProcessAudio?")
        } else {
            print("✅ ScreenCaptureKit funcionando corretamente!")
        }
    }
    
    func stopCapture() async {
        logger.info("🛑 Parando captura ScreenCaptureKit...")
        
        _isCapturing = false
        _isPaused = false
        
        if let stream = stream {
            do {
                try await stream.stopCapture()
                self.stream = nil
                logger.info("✅ Captura ScreenCaptureKit parada")
                print("✅ ScreenCaptureKit: Stream parado")
            } catch {
                logger.error("❌ Erro ao parar captura: \(error)")
                print("❌ ERRO ao parar ScreenCaptureKit: \(error)")
            }
        }
    }
    
    func pauseCapture() async {
        guard _isCapturing && !_isPaused else { return }
        
        _isPaused = true
        // ScreenCaptureKit não tem pause nativo, precisamos parar callbacks
        logger.info("⏸️ Captura ScreenCaptureKit pausada")
        print("⏸️ ScreenCaptureKit pausado")
    }
    
    func resumeCapture() async {
        guard _isCapturing && _isPaused else { return }
        
        _isPaused = false
        logger.info("▶️ Captura ScreenCaptureKit retomada")
        print("▶️ ScreenCaptureKit retomado")
    }
    
    // MARK: - SystemAudioCaptureProtocol Methods
    
    func requestSystemPermissions() async -> Bool {
        guard isSystemAudioSupported else {
            logger.warning("❌ Sistema não suporta ScreenCaptureKit")
            return false
        }
        
        do {
            _ = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
            logger.info("✅ Permissões ScreenCaptureKit concedidas")
            print("✅ Permissões ScreenCaptureKit: OK")
            return true
        } catch {
            logger.error("❌ Erro de permissão ScreenCaptureKit: \(error)")
            print("❌ ERRO de permissão ScreenCaptureKit: \(error)")
            return false
        }
    }
    
    func getSystemAudioCapabilities() -> SystemAudioCapabilities {
        let osVersion = ProcessInfo.processInfo.operatingSystemVersion
        
        let strategy: AudioCaptureStrategy
        if osVersion.majorVersion >= 14 && osVersion.minorVersion >= 2 {
            strategy = .coreAudioTaps
        } else if osVersion.majorVersion >= 13 {
            strategy = .screenCaptureKit
        } else {
            strategy = .microphoneOnly
        }
        
        return SystemAudioCapabilities(
            isSupported: isSystemAudioSupported,
            supportedStrategy: strategy,
            macOSVersion: "\(osVersion.majorVersion).\(osVersion.minorVersion).\(osVersion.patchVersion)",
            recommendedConfiguration: isSystemAudioSupported ? .mixed : .microphoneOnly
        )
    }
    
    func isSystemAudioAvailable() async -> Bool {
        // Verificar suporte do sistema operacional
        guard isSystemAudioSupported else {
            logger.warning("❌ Sistema não suporta captura de áudio do sistema")
            print("❌ Sistema não suporta ScreenCaptureKit")
            return false
        }
        
        // Verificar permissões
        guard await requestSystemPermissions() else {
            logger.warning("❌ Permissões para ScreenCaptureKit não concedidas")
            return false
        }
        
        // Em sistemas mais recentes, podemos verificar a disponibilidade
        // Por enquanto, se o sistema suporta e temos permissão, assumimos disponível
        // Isso será detectado durante a captura de qualquer forma
        
        // Se ScreenCaptureKit está disponível e permitido, presumimos que o áudio do sistema
        // também está disponível até prova em contrário (durante a captura)
        let hasAudioSources = true
        
        logger.info("🔊 Áudio do sistema presumido disponível via ScreenCaptureKit: \(hasAudioSources ? "✅" : "❌")")
        print("🔊 Áudio do sistema disponível: Presumido Sim")
        
        return hasAudioSources
    }
    
    // MARK: - SCStreamOutput
    
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .audio, !_isPaused else { return }
        
        // 🔧 DIAGNÓSTICO: Contar samples
        audioSamplesReceived += 1
        if audioSamplesReceived == 1 {
            print("🎵 PRIMEIRO sample de áudio ScreenCaptureKit recebido!")
            
            // Log detalhado do primeiro sample
            if let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer),
               let audioStreamBasicDescription = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription) {
                print("   • Sample Rate: \(audioStreamBasicDescription.pointee.mSampleRate)Hz")
                print("   • Canais: \(audioStreamBasicDescription.pointee.mChannelsPerFrame)")
                print("   • Frames: \(CMSampleBufferGetNumSamples(sampleBuffer))")
            }
        }
        
        guard let audioBuffer = createAudioBuffer(from: sampleBuffer) else {
            logger.warning("⚠️ Falha ao criar buffer de áudio")
            return
        }
        
        let hostTime = mach_absolute_time()
        onAudioReceived?(audioBuffer, hostTime)
    }
    
    // MARK: - SCStreamDelegate
    
    func stream(_ stream: SCStream, didStopWithError error: Error) {
        logger.error("❌ Stream parou com erro: \(error)")
        print("❌ ScreenCaptureKit stream erro: \(error)")
        _isCapturing = false
        _isPaused = false
    }
    
    // MARK: - Helper Methods
    
    private func createAudioBuffer(from sampleBuffer: CMSampleBuffer) -> AVAudioPCMBuffer? {
        // Obter o formato de áudio do sample buffer
        guard let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer),
              let audioStreamBasicDescription = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription),
              let format = AVAudioFormat(streamDescription: audioStreamBasicDescription) else {
            return nil
        }
        
        // Obter o número de frames
        let frameLength = CMSampleBufferGetNumSamples(sampleBuffer)
        
        // Criar buffer PCM
        guard let audioBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frameLength)) else {
            return nil
        }
        
        audioBuffer.frameLength = AVAudioFrameCount(frameLength)
        
        // Copiar dados de áudio usando Core Media
        let audioBufferListPtr = audioBuffer.mutableAudioBufferList
        
        let status = CMSampleBufferCopyPCMDataIntoAudioBufferList(
            sampleBuffer,
            at: 0,
            frameCount: Int32(frameLength),
            into: audioBufferListPtr
        )
        
        guard status == noErr else {
            logger.warning("⚠️ Erro ao copiar dados PCM: \(status)")
            return nil
        }
        
        return audioBuffer
    }
}

enum ScreenCaptureKitError: Error {
    case permissionDenied
    case configurationFailed
} 