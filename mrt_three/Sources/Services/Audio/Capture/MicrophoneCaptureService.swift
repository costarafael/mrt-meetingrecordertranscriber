import Foundation
import AVFoundation
import CoreAudio

/// Service especializado para captura de áudio do microfone
class MicrophoneCaptureService: MicrophoneCaptureProtocol {
    
    // MARK: - AudioCaptureProtocol Properties
    
    var onAudioReceived: ((AVAudioPCMBuffer, UInt64) -> Void)?
    
    private var _isCapturing = false
    private var _isPaused = false
    
    var isCapturing: Bool { _isCapturing }
    var isPaused: Bool { _isPaused }
    
    // MARK: - MicrophoneCaptureProtocol Properties
    
    private var _availableInputDevices: [AudioDevice] = []
    private var _selectedInputDevice: AudioDevice?
    
    var availableInputDevices: [AudioDevice] { _availableInputDevices }
    var selectedInputDevice: AudioDevice? {
        get { _selectedInputDevice }
        set { _selectedInputDevice = newValue }
    }
    
    // MARK: - Private Properties
    
    private var audioEngine: AVAudioEngine?
    private var formatConverter: AudioConverterProtocol?
    private var currentConfiguration: AudioConfiguration?
    private let logger = LoggingService.shared
    
    // Diagnostics tracking
    private var audioBuffersReceived = 0
    
    // MARK: - Initialization
    
    init() {
        logger.debug("MicrophoneCaptureService initialized", category: .audio)
        loadAvailableDevices()
        _selectedInputDevice = getDefaultInputDevice()
        
        logger.audioEvent("Microphone service initialization", details: [
            "devicesFound": _availableInputDevices.count,
            "defaultDevice": _selectedInputDevice?.name ?? "None"
        ])
    }
    
    // MARK: - AudioCaptureProtocol Methods
    
    func startCapture(configuration: AudioConfiguration) async throws {
        logger.audioEvent("Starting microphone capture")
        
        // Reset diagnostics counters
        audioBuffersReceived = 0
        
        // Stop previous capture if exists
        if _isCapturing {
            logger.warning("Stopping previous capture", category: .audio)
            await stopCapture()
        }
        
        logger.audioEvent("Microphone capture configuration", details: [
            "strategy": configuration.captureStrategy.rawValue,
            "sampleRate": configuration.sampleRate,
            "channels": configuration.channels,
            "bufferSize": configuration.bufferSize
        ])
        
        // Check permissions
        let hasPermission = await requestMicrophonePermissions()
        
        guard hasPermission else {
            logger.error("Microphone permission denied", category: .audio)
            throw AudioRecordingError.permissionDenied
        }
        
        // Setup audio engine
        logger.debug("Setting up AudioEngine", category: .audio)
        try await setupAudioEngine(configuration: configuration)
        
        // Try multiple times if it fails
        var startAttempts = 0
        let maxAttempts = 3
        var engineStarted = false
        
        while startAttempts < maxAttempts && !engineStarted {
            startAttempts += 1
            logger.debug("AudioEngine start attempt \(startAttempts)", category: .audio)
            
            do {
                try audioEngine?.start()
                engineStarted = audioEngine?.isRunning == true
                
                if engineStarted {
                    logger.audioEvent("AudioEngine started", details: ["attempt": startAttempts])
                } else {
                    logger.warning("AudioEngine failed to start on attempt \(startAttempts)", category: .audio)
                    if startAttempts < maxAttempts {
                        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                    }
                }
            } catch {
                logger.error("AudioEngine start failed", error: error, category: .audio)
                if startAttempts < maxAttempts {
                    try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                }
            }
        }
        
        // Try fallback if engine didn't start
        if !engineStarted {
            logger.warning("AudioEngine failed after \(maxAttempts) attempts, trying fallback", category: .audio)
            
            if let internalMic = findInternalMicrophone() {
                logger.audioEvent("Trying internal microphone fallback", details: ["device": internalMic.name])
                _selectedInputDevice = internalMic
                try await setupAudioEngine(configuration: configuration)
                try audioEngine?.start()
                
                engineStarted = audioEngine?.isRunning == true
                logger.audioEvent("Fallback result", details: ["success": engineStarted])
            }
            
            guard engineStarted else {
                logger.error("AudioEngine setup failed completely", category: .audio)
                throw AudioRecordingError.engineSetupFailed
            }
        }
        
        _isCapturing = true
        _isPaused = false
        currentConfiguration = configuration
        
        // Schedule diagnostics check
        Task {
            try await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
            await self.diagnosticCheck()
        }
        
        logger.audioEvent("Microphone capture started successfully")
    }
    
    // 🔧 DIAGNÓSTICO: Verificação específica do microfone
    private func diagnosticCheck() async {
        logger.info("DIAGNÓSTICO - Microfone (após 3s):", category: .audio)
        logger.debug("   • Buffers recebidos: \(audioBuffersReceived)", category: .general)
        logger.debug("   • Engine rodando: \(audioEngine?.isRunning == true)", category: .general)
        logger.debug("   • Callback configurado: \(onAudioReceived != nil)", category: .general)
        
        if audioBuffersReceived == 0 {
            logger.error("PROBLEMA: Microfone não está recebendo áudio!", category: .general)
            logger.debug("💡 Verificações:", category: .general)
            logger.debug("   • O microfone está conectado e funcionando?", category: .general)
            logger.debug("   • O volume do microfone não está mudo?", category: .general)
            logger.debug("   • Outras aplicações estão usando o microfone?", category: .general)
            
            // Informações adicionais do engine
            if let engine = audioEngine {
                let inputNode = engine.inputNode
                let format = inputNode.outputFormat(forBus: 0)
                logger.debug("   • Formato do InputNode: \(format.sampleRate)Hz, \(format.channelCount) canais", category: .general)
                logger.debug("   • Engine isRunning: \(engine.isRunning)", category: .general)
            }
        } else {
            logger.info("Microfone funcionando corretamente!", category: .general)
        }
    }
    
    func stopCapture() async {
        logger.info("🛑 Parando captura de microfone...")
        
        _isCapturing = false
        _isPaused = false
        
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        formatConverter = nil
        currentConfiguration = nil
        
        logger.info("MicrophoneCaptureService: Captura parada", category: .general)
        logger.info("✅ Captura de microfone parada")
    }
    
    func pauseCapture() async {
        guard _isCapturing && !_isPaused else { return }
        
        _isPaused = true
        audioEngine?.pause()
        
        logger.debug("⏸️ MicrophoneCaptureService pausado", category: .general)
        logger.info("⏸️ Captura de microfone pausada")
    }
    
    func resumeCapture() async {
        guard _isCapturing && _isPaused else { return }
        
        do {
            try audioEngine?.start()
            _isPaused = false
            logger.debug("▶️ MicrophoneCaptureService retomado", category: .general)
            logger.info("▶️ Captura de microfone retomada")
        } catch {
            logger.error("ERRO ao retomar microfone: \(error)", category: .general)
            logger.error("❌ Erro ao retomar captura: \(error)")
        }
    }
    
    // MARK: - MicrophoneCaptureProtocol Methods
    
    func requestMicrophonePermissions() async -> Bool {
        return await withCheckedContinuation { continuation in
            let currentStatus = AVCaptureDevice.authorizationStatus(for: .audio)
            
            switch currentStatus {
            case .authorized:
                continuation.resume(returning: true)
            case .notDetermined:
                AVCaptureDevice.requestAccess(for: .audio) { granted in
                    continuation.resume(returning: granted)
                }
            case .denied, .restricted:
                continuation.resume(returning: false)
            @unknown default:
                continuation.resume(returning: false)
            }
        }
    }
    
    func selectInputDevice(_ device: AudioDevice) {
        _selectedInputDevice = device
        logger.info("🎧 Dispositivo selecionado: \(device.name)")
        logger.info("DIAGNÓSTICO - Dispositivo selecionado: \(device.name)", category: .audio)
        
        // Se estiver capturando, reiniciar com novo dispositivo
        if _isCapturing, let config = currentConfiguration {
            logger.info("DIAGNÓSTICO - Reiniciando captura com novo dispositivo", category: .audio)
            Task {
                await stopCapture()
                try? await startCapture(configuration: config)
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func setupAudioEngine(configuration: AudioConfiguration) async throws {
        logger.info("DIAGNÓSTICO - setupAudioEngine iniciado", category: .audio)
        
        // 🔧 CORREÇÃO: Limpar engine anterior se existir
        if let existingEngine = audioEngine {
            existingEngine.inputNode.removeTap(onBus: 0)
            existingEngine.stop()
        }
        
        audioEngine = AVAudioEngine()
        
        guard let audioEngine = audioEngine else {
            logger.error("ERRO: Falha ao criar AVAudioEngine", category: .general)
            throw AudioRecordingError.engineSetupFailed
        }
        
        logger.info("DIAGNÓSTICO - AVAudioEngine criado", category: .audio)
        
        // Configurar dispositivo de entrada se especificado
        if let inputDevice = _selectedInputDevice {
            logger.info("DIAGNÓSTICO - Configurando dispositivo: \(inputDevice.name)", category: .audio)
            try setInputDevice(inputDevice.deviceID)
        } else {
            logger.info("DIAGNÓSTICO - Usando dispositivo padrão do sistema", category: .audio)
        }
        
        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)
        
        logger.info("DIAGNÓSTICO - InputNode format:", category: .audio)
        logger.debug("   • Sample Rate: \(inputFormat.sampleRate)Hz", category: .general)
        logger.debug("   • Canais: \(inputFormat.channelCount)", category: .general)
        logger.debug("   • Formato: \(inputFormat.formatDescription)", category: .general)
        
        // 🔧 CORREÇÃO: Verificar compatibilidade de sample rate
        if inputFormat.sampleRate != Double(configuration.sampleRate) {
            logger.warning("AVISO: Sample rate incompatível!", category: .general)
            logger.debug("   • Esperado: \(configuration.sampleRate)Hz", category: .general)
            logger.debug("   • Dispositivo: \(inputFormat.sampleRate)Hz", category: .general)
            logger.debug("   • Conversão será aplicada automaticamente", category: .general)
        }
        
        // Validações de formato
        guard inputFormat.sampleRate > 0 && inputFormat.channelCount > 0 else {
            logger.error("ERRO: Formato de entrada inválido", category: .general)
            throw AudioRecordingError.engineSetupFailed
        }
        
        guard inputFormat.sampleRate >= 8000 && inputFormat.sampleRate <= 192000 else {
            logger.error("ERRO: Sample rate fora do range permitido", category: .general)
            throw AudioRecordingError.engineSetupFailed
        }
        
        logger.info("📊 Formato de entrada: \(inputFormat.sampleRate)Hz, \(inputFormat.channelCount) canais")
        
        // Configurar conversor de formato
        logger.info("DIAGNÓSTICO - Configurando conversor de formato...", category: .audio)
        logger.debug("   • Input format details: \(inputFormat)", category: .audio)
        formatConverter = UnifiedAudioConverter()
        try formatConverter?.setupConverters(systemFormat: nil, microphoneFormat: inputFormat)
        
        // 🔧 CORREÇÃO: Usar buffer size adequado baseado no sample rate
        let bufferSize = calculateOptimalBufferSize(sampleRate: inputFormat.sampleRate, requestedSize: configuration.bufferSize)
        logger.info("DIAGNÓSTICO - Buffer size otimizado: \(bufferSize) (original: \(configuration.bufferSize))", category: .audio)
        
        // Instalar tap de áudio
        logger.info("DIAGNÓSTICO - Instalando tap de áudio...", category: .audio)
        inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: nil) { [weak self] buffer, time in
            self?.processAudioBuffer(buffer, time: time)
        }
        
        logger.info("MicrophoneCaptureService: AudioEngine configurado", category: .general)
        logger.info("🔧 AudioEngine configurado com sucesso")
    }
    
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer, time: AVAudioTime) {
        guard _isCapturing && !_isPaused else { return }
        guard buffer.frameLength > 0 else { return }
        
        // 🔧 DIAGNÓSTICO: Contar buffers
        audioBuffersReceived += 1
        if audioBuffersReceived == 1 {
            logger.info("PRIMEIRO buffer de microfone recebido!", category: .audio)
            logger.debug("   • Sample Rate: \(buffer.format.sampleRate)Hz", category: .general)
            logger.debug("   • Canais: \(buffer.format.channelCount)", category: .general)
            logger.debug("   • Frames: \(buffer.frameLength)", category: .general)
        }
        
        // Converter formato se necessário
        let processedBuffer = formatConverter?.convertMicrophoneAudio(buffer) ?? buffer
        
        // Gerar timestamp
        let hostTime = mach_absolute_time()
        
        // Chamar callback
        onAudioReceived?(processedBuffer, hostTime)
    }
    
    func loadAvailableDevices() {
        logger.info("DIAGNÓSTICO - Carregando dispositivos disponíveis...", category: .audio)
        _availableInputDevices = getAvailableInputDevices()
        logger.info("DIAGNÓSTICO - Dispositivos carregados: \(_availableInputDevices.count)", category: .audio)
        
        for (index, device) in _availableInputDevices.enumerated() {
            logger.debug("   [\(index)] \(device.name)", category: .general)
        }
    }
    
    private func getAvailableInputDevices() -> [AudioDevice] {
        var devices: [AudioDevice] = []
        
        var deviceCount: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &propertyAddress, 0, nil, &size)
        deviceCount = size / UInt32(MemoryLayout<AudioDeviceID>.size)
        
        var deviceIDs = Array<AudioDeviceID>(repeating: 0, count: Int(deviceCount))
        AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &propertyAddress, 0, nil, &size, &deviceIDs)
        
        for deviceID in deviceIDs {
            if let device = AudioDevice(deviceID: deviceID), device.hasInputStreams {
                devices.append(device)
            }
        }
        
        return devices
    }
    
    private func getDefaultInputDevice() -> AudioDevice? {
        var deviceID: AudioDeviceID = 0
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        let status = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &propertyAddress, 0, nil, &size, &deviceID)
        
        if status == noErr {
            return AudioDevice(deviceID: deviceID)
        }
        
        return nil
    }
    
    private func setInputDevice(_ deviceID: AudioDeviceID) throws {
        // Nota: AudioEngine usa o dispositivo padrão do sistema
        // Para controle total seria necessário usar Core Audio diretamente
        // Esta implementação é compatível com a estrutura atual
        logger.info("DIAGNÓSTICO - setInputDevice: \(deviceID)", category: .audio)
        logger.info("🎧 Configurando dispositivo de entrada: \(deviceID)")
    }
    
    // 🔧 NOVO: Calcular buffer size otimizado
    private func calculateOptimalBufferSize(sampleRate: Double, requestedSize: AVAudioFrameCount) -> AVAudioFrameCount {
        // Para sample rates altos, usar buffers maiores
        let baseSize = requestedSize
        let multiplier: Double = sampleRate > 32000 ? 2.0 : 1.0
        return AVAudioFrameCount(Double(baseSize) * multiplier)
    }
    
    // 🔧 NOVO: Encontrar microfone interno como fallback
    private func findInternalMicrophone() -> AudioDevice? {
        let devices = getAvailableInputDevices()
        logger.info("DIAGNÓSTICO - Procurando microfone interno...", category: .audio)
        
        // Procurar por microfone interno (Built-in, MacBook, etc.)
        let internalNames = ["MacBook", "Built-in", "Internal", "iMac"]
        
        for device in devices {
            logger.debug("   • Verificando: \(device.name)", category: .general)
            for internalName in internalNames {
                if device.name.contains(internalName) {
                    logger.info("Microfone interno encontrado: \(device.name)", category: .general)
                    return device
                }
            }
        }
        
        logger.error("Microfone interno não encontrado", category: .general)
        return nil
    }
} 