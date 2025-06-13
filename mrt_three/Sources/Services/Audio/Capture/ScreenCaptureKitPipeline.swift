import Foundation
import AVFoundation
import ScreenCaptureKit
import CoreMedia

// LoggingService for unified logging  
private let logger = LoggingService.shared

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
    
    // 🔧 DIAGNÓSTICO: Contadores para debug
    private var audioSamplesReceived = 0
    private var lastSampleTime = Date()
    private var streamStartTime = Date()
    private var logFile: FileHandle?
    
    // MARK: - AudioCaptureProtocol Properties
    
    var onAudioReceived: ((AVAudioPCMBuffer, UInt64) -> Void)?
    var onStreamFailure: ((Error) -> Void)?
    
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
        
        // 🔧 DIAGNÓSTICO: Resetar contadores e iniciar log detalhado
        audioSamplesReceived = 0
        streamStartTime = Date()
        lastSampleTime = Date()
        
        // Criar arquivo de log específico para esta sessão
        setupDebugLogging()
        
        // 🔧 DIAGNÓSTICO: Log detalhado da configuração
        logger.debug("🔍 DIAGNÓSTICO - ScreenCaptureKit startCapture:")
        logger.debug("   • Estratégia: \(configuration.captureStrategy)")
        logger.debug("   • Sample Rate: \(configuration.sampleRate)Hz")
        logger.debug("   • Canais: \(configuration.channels)")
        logger.debug("   • systemAudioConfig: \(configuration.systemAudioConfig != nil ? "✅" : "❌")")
        
        guard isSystemAudioSupported else {
            logger.error("Sistema não suporta ScreenCaptureKit")
            throw SystemAudioCaptureError.systemVersionNotSupported
        }
        
        guard await requestSystemPermissions() else {
            logger.error("Permissões de ScreenCaptureKit negadas")
            throw SystemAudioCaptureError.permissionDenied
        }
        
        logger.debug("🔍 Obtendo conteúdo compartilhável...")
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
        
        guard let display = content.displays.first else {
            logger.error("Nenhum display encontrado")
            throw SystemAudioCaptureError.noDisplayFound
        }
        
        logger.debug("🔍 Display encontrado: \(display.width)x\(display.height)")
        
        let filter = SCContentFilter(display: display, excludingApplications: [], exceptingWindows: [])
        
        let config = SCStreamConfiguration()
        config.capturesAudio = true
        config.excludesCurrentProcessAudio = configuration.systemAudioConfig?.excludeCurrentProcess ?? true
        config.sampleRate = Int(configuration.sampleRate)
        config.channelCount = Int(configuration.channels)
        
        // 🔧 CONFIGURAÇÕES OTIMIZADAS baseadas na pesquisa para estabilidade
        // Configuração mínima de captura de tela para reduzir overhead
        config.width = 2  // Captura mínima conforme sugerido na pesquisa
        config.height = 2
        config.minimumFrameInterval = CMTime(value: 1, timescale: 1) // 1 FPS mínimo
        config.showsCursor = false
        config.scalesToFit = false
        
        // 🔧 DIAGNÓSTICO: Log da configuração do SCStream
        logger.debug("🔍 Configuração SCStream:")
        logger.debug("   • capturesAudio: \(config.capturesAudio)")
        logger.debug("   • excludesCurrentProcessAudio: \(config.excludesCurrentProcessAudio)")
        logger.debug("   • sampleRate: \(config.sampleRate)")
        logger.debug("   • channelCount: \(config.channelCount)")
        
        stream = SCStream(filter: filter, configuration: config, delegate: self)
        
        do {
            logger.debug("🔍 Adicionando stream output...")
            try stream?.addStreamOutput(self, type: .audio, sampleHandlerQueue: DispatchQueue(label: "ScreenCaptureKit.AudioQueue"))
            
            logger.debug("🔍 Iniciando stream...")
            try await stream?.startCapture()
            
            _isCapturing = true
            _isPaused = false
            
            logger.info("✅ Captura ScreenCaptureKit iniciada")
            logger.info("ScreenCaptureKit: Stream iniciado com sucesso")
            
            // 🔧 DIAGNÓSTICO: Agendar verificação
            Task {
                try await Task.sleep(nanoseconds: 3_000_000_000) // 3 segundos
                await self.diagnosticCheck()
            }
            
        } catch {
            logger.error("❌ Erro ao iniciar captura: \(error)")
            logger.error("ERRO ScreenCaptureKit: \(error)")
            throw SystemAudioCaptureError.captureStartFailed(error)
        }
    }
    
    // 🔧 DIAGNÓSTICO: Verificação específica do ScreenCaptureKit
    private func diagnosticCheck() async {
        logger.debug("🔍 DIAGNÓSTICO - ScreenCaptureKit (após 3s):")
        logger.debug("   • Samples de áudio recebidos: \(self.audioSamplesReceived)")
        logger.debug("   • Stream ativo: \(self._isCapturing)")
        logger.debug("   • Stream pausado: \(self._isPaused)")
        logger.debug("   • Stream objeto existe: \(self.stream != nil)")
        
        if self.audioSamplesReceived == 0 {
            logger.error("PROBLEMA: ScreenCaptureKit não está recebendo áudio!")
            logger.debug("💡 Verificações:")
            logger.debug("   • Há áudio sendo reproduzido no sistema?")
            logger.debug("   • As permissões de ScreenCaptureKit foram concedidas?")
            logger.debug("   • O app está excluído em excludesCurrentProcessAudio?")
        } else {
            logger.info("ScreenCaptureKit funcionando corretamente!")
        }
        
        // Verificação contínua a cada 10 segundos
        if self._isCapturing {
            Task {
                try await Task.sleep(nanoseconds: 10_000_000_000) // 10 segundos
                await self.monitorStreamHealth()
            }
        }
    }
    
    // 🔧 NOVO: Monitoramento contínuo da saúde do stream (baseado na pesquisa)
    private func monitorStreamHealth() async {
        let previousSampleCount = audioSamplesReceived
        let checkTime = Date()
        
        // 🔧 CRÍTICO: Reduzir tempo de detecção para 3 segundos baseado nos dados do log
        // Log mostrou que stream congela completamente sem notificar erro
        try? await Task.sleep(nanoseconds: 3_000_000_000)
        
        if _isCapturing && audioSamplesReceived == previousSampleCount {
            let timeSinceLastSample = Date().timeIntervalSince(lastSampleTime)
            let elapsedTime = Date().timeIntervalSince(streamStartTime)
            
            // Log detalhado da detecção de problema
            writeToDebugLog("STREAM_HEALTH_ISSUE: No samples for 5s at \(String(format: "%.3f", elapsedTime))s")
            writeToDebugLog("LAST_SAMPLE_TIME: \(String(format: "%.3f", timeSinceLastSample))s ago")
            writeToDebugLog("SAMPLES_FROZEN_AT: \(audioSamplesReceived)")
            
            logger.error("❌ STREAM CONGELADO: ScreenCaptureKit parou silenciosamente sem erro!")
            logger.warning("   • Samples antes: \(previousSampleCount)")
            logger.warning("   • Samples agora: \(audioSamplesReceived)")
            logger.warning("   • Último sample há: \(String(format: "%.1f", timeSinceLastSample))s")
            logger.warning("   • Tempo total: \(String(format: "%.1f", elapsedTime))s")
            
            // 🔧 NOVA ESTRATÉGIA: Baseada na descoberta do log - stream congela silenciosamente
            // Sempre tentar recuperação quando detectar congelamento
            writeToDebugLog("STREAM_FROZEN_DETECTED: \(audioSamplesReceived) samples - IMMEDIATE RECOVERY NEEDED")
            logger.error("🚨 CONGELAMENTO CONFIRMADO - Iniciando recuperação imediata...")
            
            // Notificar sistema de fallback sobre stream congelado
            let frozenError = NSError(domain: "ScreenCaptureKit", code: -3808, 
                                     userInfo: [NSLocalizedDescriptionKey: "Stream frozen silently - no samples for 3+ seconds"])
            onStreamFailure?(frozenError)
            
            // Tentar recuperação agressiva
            await attemptStreamRecovery()
            
            // Verificar se o stream ainda existe
            if stream != nil {
                logger.debug("   • Stream objeto ainda existe")
                writeToDebugLog("STREAM_OBJECT: Still exists")
            } else {
                logger.error("   • ❌ Stream objeto foi perdido!")
                writeToDebugLog("STREAM_OBJECT: Lost/nil")
                _isCapturing = false
            }
        } else if _isCapturing {
            // Stream ainda saudável
            let elapsedTime = Date().timeIntervalSince(streamStartTime)
            writeToDebugLog("STREAM_HEALTHY: \(audioSamplesReceived) samples at \(String(format: "%.3f", elapsedTime))s")
        }
        
        // Continuar monitoramento se ainda capturando
        if _isCapturing {
            Task {
                try await Task.sleep(nanoseconds: 10_000_000_000) // 10 segundos
                await self.monitorStreamHealth()
            }
        }
    }
    
    // 🔧 NOVA: Tentativa de recuperação automática do stream
    private func attemptStreamRecovery() async {
        logger.info("🔄 Iniciando recuperação automática do ScreenCaptureKit...")
        
        guard let currentStream = stream else {
            logger.error("❌ Não é possível recuperar: stream é nil")
            return
        }
        
        do {
            // Parar o stream atual
            logger.debug("🔄 Parando stream atual...")
            try await currentStream.stopCapture()
            
            // Aguardar um pouco para o sistema liberar recursos
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 segundo
            
            // Obter novo conteúdo (pode ter mudado)
            logger.debug("🔄 Obtendo novo conteúdo compartilhável...")
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
            
            guard let display = content.displays.first else {
                logger.error("❌ Nenhum display encontrado na recuperação")
                _isCapturing = false
                return
            }
            
            // Criar nova configuração (pode resolver bugs conhecidos)
            let filter = SCContentFilter(display: display, excludingApplications: [], exceptingWindows: [])
            let config = SCStreamConfiguration()
            config.capturesAudio = true
            config.excludesCurrentProcessAudio = true
            config.sampleRate = 48000 // Usar padrão conhecido funcional
            config.channelCount = 2
            
            // Configurações otimizadas para estabilidade
            config.width = 2
            config.height = 2
            config.minimumFrameInterval = CMTime(value: 1, timescale: 1)
            config.showsCursor = false
            config.scalesToFit = false
            
            // Criar novo stream
            let newStream = SCStream(filter: filter, configuration: config, delegate: self)
            
            // Configurar output
            try newStream.addStreamOutput(self, type: .audio, sampleHandlerQueue: DispatchQueue(label: "ScreenCaptureKit.AudioQueue.Recovery"))
            
            // Iniciar novo stream
            try await newStream.startCapture()
            
            // Substitir stream antigo
            stream = newStream
            
            logger.info("✅ Recuperação do ScreenCaptureKit bem-sucedida")
            
        } catch {
            logger.error("❌ Falha na recuperação automática: \(error)")
            _isCapturing = false
        }
    }
    
    func stopCapture() async {
        logger.info("🛑 Parando captura ScreenCaptureKit...")
        
        // 🔧 DIAGNÓSTICO: Log final com estatísticas completas
        let totalTime = Date().timeIntervalSince(streamStartTime)
        let timeSinceLastSample = Date().timeIntervalSince(lastSampleTime)
        
        writeToDebugLog("STOP_CAPTURE: Total time \(String(format: "%.3f", totalTime))s, Last sample \(String(format: "%.3f", timeSinceLastSample))s ago")
        writeToDebugLog("FINAL_STATS: \(audioSamplesReceived) total samples")
        
        logger.info("📊 Estatísticas finais ScreenCaptureKit:")
        logger.info("   • Total de samples: \(audioSamplesReceived)")
        logger.info("   • Tempo total: \(String(format: "%.1f", totalTime))s")
        logger.info("   • Último sample há: \(String(format: "%.1f", timeSinceLastSample))s")
        
        _isCapturing = false
        _isPaused = false
        
        if let stream = stream {
            do {
                try await stream.stopCapture()
                self.stream = nil
                logger.info("✅ Captura ScreenCaptureKit parada")
                writeToDebugLog("STREAM_STOPPED: Successfully")
            } catch {
                logger.error("❌ Erro ao parar captura: \(error)")
                writeToDebugLog("STREAM_STOP_ERROR: \(error)")
            }
        }
        
        // Fechar arquivo de log
        closeDebugLogging()
    }
    
    func pauseCapture() async {
        guard _isCapturing && !_isPaused else { return }
        
        _isPaused = true
        // ScreenCaptureKit não tem pause nativo, precisamos parar callbacks
        logger.info("⏸️ Captura ScreenCaptureKit pausada")
        logger.debug("⏸️ ScreenCaptureKit pausado")
    }
    
    func resumeCapture() async {
        guard _isCapturing && _isPaused else { return }
        
        _isPaused = false
        logger.info("▶️ Captura ScreenCaptureKit retomada")
        logger.debug("▶️ ScreenCaptureKit retomado")
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
            logger.info("Permissões ScreenCaptureKit: OK")
            return true
        } catch {
            logger.error("❌ Erro de permissão ScreenCaptureKit: \(error)")
            logger.error("ERRO de permissão ScreenCaptureKit: \(error)")
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
            logger.error("Sistema não suporta ScreenCaptureKit")
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
        logger.debug("🔊 Áudio do sistema disponível: Presumido Sim")
        
        return hasAudioSources
    }
    
    // MARK: - SCStreamOutput
    
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .audio, !_isPaused else { return }
        
        // 🔧 DIAGNÓSTICO: Contar samples e registrar timing preciso
        audioSamplesReceived += 1
        let now = Date()
        lastSampleTime = now
        let elapsedTime = now.timeIntervalSince(streamStartTime)
        
        // Log detalhado para arquivo
        writeToDebugLog("SAMPLE_\(audioSamplesReceived): \(String(format: "%.3f", elapsedTime))s")
        
        if audioSamplesReceived == 1 {
            logger.debug("🎵 PRIMEIRO sample de áudio ScreenCaptureKit recebido!")
            writeToDebugLog("FIRST_SAMPLE: \(String(format: "%.3f", elapsedTime))s")
            
            // Log detalhado do primeiro sample
            if let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer),
               let audioStreamBasicDescription = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription) {
                logger.debug("   • Sample Rate: \(audioStreamBasicDescription.pointee.mSampleRate)Hz")
                logger.debug("   • Canais: \(audioStreamBasicDescription.pointee.mChannelsPerFrame)")
                logger.debug("   • Frames: \(CMSampleBufferGetNumSamples(sampleBuffer))")
                
                writeToDebugLog("FORMAT: \(audioStreamBasicDescription.pointee.mSampleRate)Hz, \(audioStreamBasicDescription.pointee.mChannelsPerFrame)ch")
            }
        }
        
        // 🔧 DIAGNÓSTICO: Log a cada 1000 samples para monitorar continuidade
        if audioSamplesReceived % 1000 == 0 {
            logger.debug("🔍 ScreenCaptureKit: \(audioSamplesReceived) samples de áudio recebidos (tempo: \(String(format: "%.1f", elapsedTime))s)")
            writeToDebugLog("MILESTONE_1000: \(audioSamplesReceived) samples at \(String(format: "%.3f", elapsedTime))s")
        }
        
        guard let audioBuffer = createAudioBuffer(from: sampleBuffer) else {
            logger.warning("⚠️ Falha ao criar buffer de áudio")
            logger.warning("🔍 DIAGNÓSTICO: Sample \(audioSamplesReceived) falhou na conversão")
            return
        }
        
        let hostTime = mach_absolute_time()
        onAudioReceived?(audioBuffer, hostTime)
    }
    
    // MARK: - SCStreamDelegate
    
    func stream(_ stream: SCStream, didStopWithError error: Error) {
        logger.error("❌ Stream parou com erro: \(error)")
        logger.error("ScreenCaptureKit stream erro: \(error)")
        logger.error("🔍 DIAGNÓSTICO - Stream parou inesperadamente:")
        logger.error("   • Total de samples recebidos: \(audioSamplesReceived)")
        logger.error("   • Era capturando: \(_isCapturing)")
        logger.error("   • Estava pausado: \(_isPaused)")
        logger.error("   • Tipo do erro: \(type(of: error))")
        logger.error("   • Descrição completa: \(error.localizedDescription)")
        
        // Log informações do sistema
        let memoryPressure = ProcessInfo.processInfo.thermalState
        logger.error("   • Estado térmico: \(memoryPressure.rawValue)")
        
        _isCapturing = false
        _isPaused = false
        
        // 🔧 NOVO: Notificar falha para o sistema de fallback
        onStreamFailure?(error)
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
    
    // MARK: - Debug Logging
    
    private func setupDebugLogging() {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let logFileName = "screencapturekit_debug_\(timestamp).log"
        let logURL = URL(fileURLWithPath: "/tmp/\(logFileName)")
        
        do {
            // Criar arquivo se não existir
            if !FileManager.default.fileExists(atPath: logURL.path) {
                FileManager.default.createFile(atPath: logURL.path, contents: nil)
            }
            
            logFile = try FileHandle(forWritingTo: logURL)
            logFile?.seekToEndOfFile()
            
            writeToDebugLog("SESSION_START: \(timestamp)")
            writeToDebugLog("LOG_FILE: \(logURL.path)")
            
            logger.info("🔧 Debug logging iniciado: \(logURL.path)")
            
        } catch {
            logger.error("❌ Falha ao criar arquivo de debug: \(error)")
        }
    }
    
    private func writeToDebugLog(_ message: String) {
        guard let logFile = logFile else { return }
        
        let timestamp = String(format: "%.3f", Date().timeIntervalSince(streamStartTime))
        let logEntry = "[\(timestamp)s] \(message)\n"
        
        if let data = logEntry.data(using: .utf8) {
            logFile.write(data)
        }
    }
    
    private func closeDebugLogging() {
        writeToDebugLog("SESSION_END: \(ISO8601DateFormatter().string(from: Date()))")
        
        logFile?.closeFile()
        logFile = nil
        
        // Log localização do arquivo final
        if let logPath = logFile?.fileDescriptor {
            logger.info("🔧 Debug log finalizado. Arquivo salvo para análise.")
        }
    }
}

enum ScreenCaptureKitError: Error {
    case permissionDenied
    case configurationFailed
} 