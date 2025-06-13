import Foundation
import AVFoundation
import Combine

/// Coordinator principal para orquestrar gravação de áudio usando services especializados
class AudioRecordingCoordinator: ObservableObject, WarmupManagerDelegate {
    
    // MARK: - Published Properties (Interface pública para Views)
    
    @Published var isRecording = false
    @Published var isPaused = false
    @Published var currentDuration: TimeInterval = 0
    @Published var audioLevel: Float = 0.0
    @Published var errorMessage: String?
    @Published var availableInputDevices: [AudioDevice] = []
    @Published var selectedInputDevice: AudioDevice?
    @Published var systemAudioAvailable = false
    @Published var systemAudioEnabled = true
    @Published var isWarmingUp: Bool = false
    @Published var warmupProgress: Double = 0.0
    @Published var warmupCountdown: Int = 3
    
    // MARK: - Computed Properties
    
    /// Estratégia de captura atual sendo usada
    var activeAudioCaptureStrategy: AudioCaptureStrategy {
        return currentCaptureStrategy
    }
    
    // MARK: - Private Properties
    
    // Services especializados (injeção de dependência)
    private var microphoneService: MicrophoneCaptureProtocol
    private var systemAudioService: SystemAudioCaptureProtocol
    private let permissionManager: AudioPermissionManager
    private let formatConverter: AudioConverterProtocol
    private let synchronizer: AudioSynchronizerProtocol
    
    // 🎯 Core Audio Tap Service via XPC + Helper Tool (macOS 13+)
    private var coreAudioTapService: (any SystemAudioCaptureProtocol)?
    private var originalSystemAudioService: SystemAudioCaptureProtocol
    private var currentCaptureStrategy: AudioCaptureStrategy = .screenCaptureKit
    
    // 🔧 Services especializados extraídos
    private let audioFileService: AudioFileService
    private let diagnostics = DiagnosticsService()
    private let logger = LoggingService.shared
    
    // 🔧 NOVO: Módulos especializados
    private let recordingState = RecordingState()
    private let warmupManager = WarmupManager()
    
    // Combine subscriptions
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(
        microphoneService: MicrophoneCaptureProtocol,
        systemAudioService: SystemAudioCaptureProtocol,
        audioFileManager: AudioFileManagerProtocol,
        permissionManager: AudioPermissionManager,
        formatConverter: AudioConverterProtocol,
        synchronizer: AudioSynchronizerProtocol
    ) {
        self.microphoneService = microphoneService
        self.systemAudioService = systemAudioService
        self.originalSystemAudioService = systemAudioService // Armazenar referência original
        self.permissionManager = permissionManager
        self.formatConverter = formatConverter
        self.synchronizer = synchronizer
        
        // Inicializar services especializados
        self.audioFileService = AudioFileService(
            audioFileManager: audioFileManager,
            synchronizer: synchronizer
        )
        
        logger.info("AudioRecordingCoordinator initialized", category: .recording)
        
        // Configurar módulos especializados
        setupSpecializedModules()
        setupServiceCallbacks()
        setupStateBindings()
    }
    
    // MARK: - Public Methods
    
    /// Inicializar coordinator (carrega dispositivos, detecta capacidades)
    func initialize() async {
        logger.info("Initializing coordinator", category: .recording)
        
        // Log system capabilities
        diagnostics.logSystemCapabilities()
        
        // Carregar dispositivos disponíveis e atualizar estado
        let devices = microphoneService.availableInputDevices
        let selectedDevice = microphoneService.selectedInputDevice
        
        recordingState.updateAvailableDevices(devices)
        if let device = selectedDevice {
            recordingState.selectInputDevice(device)
        }
        
        // Detectar capacidades de áudio do sistema
        let systemCapabilities = systemAudioService.getSystemAudioCapabilities()
        recordingState.setSystemAudioAvailable(systemCapabilities.isSupported)
        
        logger.audioEvent("System audio capabilities", details: [
            "supported": systemCapabilities.isSupported,
            "strategy": systemCapabilities.supportedStrategy.rawValue,
            "macOSVersion": systemCapabilities.macOSVersion,
            "enabledInCoordinator": systemAudioEnabled
        ])
        
        logger.info("Coordinator initialization completed", category: .recording)
    }
    
    /// Solicitar todas as permissões necessárias
    /// - Returns: True se todas as permissões foram concedidas
    func requestPermissions() async -> Bool {
        logger.info("Requesting permissions", category: .recording)
        
        // Primeiro verificar se áudio do sistema está disponível ANTES de solicitar permissões
        let systemAudioCurrentlyAvailable = await systemAudioService.isSystemAudioAvailable()
        
        // Primeiro verificar status atual sem triggerar diálogos
        let currentStatus = await permissionManager.checkCurrentPermissionStatus(includeSystemAudio: systemAudioEnabled && systemAudioCurrentlyAvailable)
        
        if currentStatus.success {
            logger.info("✅ All permissions already granted", category: .recording)
            await MainActor.run {
                errorMessage = nil
            }
            return true
        }
        
        // Limpar mensagem de erro antes de solicitar permissões
        await MainActor.run {
            errorMessage = nil
        }
        
        // Agora solicitar as permissões que faltam
        logger.info("🚀 Requesting missing permissions", category: .recording)
        let result = await permissionManager.requestAllPermissions(includeSystemAudio: systemAudioEnabled && systemAudioCurrentlyAvailable)
        
        // Apenas mostrar erro se realmente foi negado após o usuário responder
        await MainActor.run {
            if !result.success {
                let errorMessages = result.errors.map { $0.localizedDescription }
                errorMessage = "Permissions denied: \(errorMessages.joined(separator: ", "))"
                logger.warning("❌ Permissions denied by user", category: .recording)
            } else {
                errorMessage = nil
                logger.info("✅ All permissions granted by user", category: .recording)
            }
        }
        
        logger.audioEvent("Permission request result", details: [
            "success": result.success,
            "microphoneGranted": result.microphoneGranted,
            "systemAudioGranted": result.systemAudioGranted
        ])
        
        return result.success
    }
    
    /// Iniciar gravação para uma reunião
    /// - Parameter meeting: Reunião para gravar
    /// - Returns: True se a gravação foi iniciada com sucesso
    func startRecording(for meeting: Meeting) async -> Bool {
        guard !recordingState.isRecording && !warmupManager.isWarmingUp else { return false }
        
        logger.recordingEvent("Starting recording preparation phase", meetingId: meeting.id)
        
        // Reset diagnostics
        diagnostics.resetCounters()
        
        // Verificar permissões
        guard await requestPermissions() else {
            logger.error("Insufficient permissions", category: .recording)
            return false
        }
        
        do {
            // 1. Determinar configuração otimizada
            let configuration = determineOptimalConfiguration()
            
            // 2. Preparar estado de gravação
            recordingState.prepareForRecording(meetingId: meeting.id, configuration: configuration)
            
            // Log configuration
            diagnostics.logAudioConfiguration(configuration)
            
            // 3. Configurar arquivos de áudio
            try await audioFileService.setupAudioFiles(
                for: meeting.id,
                configuration: configuration
            )
            
            // 4. Iniciar período de aquecimento
            warmupManager.startWarmup()
            
            // 5. Iniciar captura do microfone
            try await startMicrophoneCapture(configuration: configuration)
            
            // 6. Iniciar captura do áudio do sistema se disponível e habilitado
            let systemAudioAvailable = await systemAudioService.isSystemAudioAvailable()
            recordingState.setSystemAudioAvailable(systemAudioAvailable)
            
            if systemAudioEnabled && systemAudioAvailable {
                logger.audioEvent("Starting system audio capture during warmup")
                try await startSystemAudioCapture(configuration: configuration)
                logger.audioEvent("System audio capture started during warmup")
            } else {
                logger.audioEvent("System audio capture skipped", details: [
                    "enabled": systemAudioEnabled,
                    "available": systemAudioAvailable
                ])
            }
            
            // 7. Marcar que a captura foi iniciada durante o warmup
            warmupManager.markCaptureStarted()
            logger.recordingEvent("Capture started during warmup phase", meetingId: meeting.id)
            
            // Start diagnostics monitoring
            diagnostics.performBufferCheck()
            
            return true
            
        } catch {
            logger.error("Failed to start recording", error: error, category: .recording)
            recordingState.setError("Failed to start recording: \(error.localizedDescription)")
            warmupManager.cancelWarmup()
            await cleanupRecording()
            return false
        }
    }
    
    
    /// Pausar gravação
    func pauseRecording() {
        guard recordingState.isRecording && !recordingState.isPaused else { return }
        
        logger.recordingEvent("Pausing recording", meetingId: recordingState.currentMeetingId)
        
        Task {
            await microphoneService.pauseCapture()
            if systemAudioEnabled {
                await systemAudioService.pauseCapture()
            }
        }
        
        recordingState.pauseRecording()
        
        logger.recordingEvent("Recording paused", meetingId: recordingState.currentMeetingId)
    }
    
    /// Retomar gravação
    func resumeRecording() {
        guard recordingState.isRecording && recordingState.isPaused else { return }
        
        logger.recordingEvent("Resuming recording", meetingId: recordingState.currentMeetingId)
        
        Task {
            await microphoneService.resumeCapture()
            if systemAudioEnabled {
                await systemAudioService.resumeCapture()
            }
        }
        
        recordingState.resumeRecording()
        
        logger.recordingEvent("Recording resumed", meetingId: recordingState.currentMeetingId)
    }
    
    /// Parar gravação
    /// - Returns: Tupla com caminho do arquivo e duração
    func stopRecording() async -> (audioPath: String?, duration: TimeInterval) {
        // Se estiver no período de aquecimento, cancelar o processo
        if warmupManager.isWarmingUp || warmupManager.isInWarmup {
            logger.recordingEvent("Cancelando gravação durante período de aquecimento")
            
            // Cancelar warmup
            warmupManager.cancelWarmup()
            
            // Parar serviços de captura
            await microphoneService.stopCapture()
            await systemAudioService.stopCapture()
            
            // Limpar recursos
            await cleanupRecording()
            
            return (nil, 0)
        }
        
        // Código existente para parar gravação normal
        guard recordingState.isRecording else { return (nil, 0) }
        
        logger.recordingEvent("Stopping recording", meetingId: recordingState.currentMeetingId)
        
        // 1. Stop recording state and get final duration
        let finalDuration = recordingState.stopRecording()
        
        // 2. Stop audio capture and wait for it to complete
        await microphoneService.stopCapture()
        await systemAudioService.stopCapture()
        
        // 3. Finalize files to ensure all buffers are written
        await audioFileService.finalizeFiles()
        
        // 4. Aguardar um pequeno intervalo para garantir que o sistema operacional tenha tempo
        // de completar operações de I/O e liberar os arquivos totalmente
        logger.debug("[DEBUG] Aguardando um momento para garantir que os arquivos estejam disponíveis...", category: .general)
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 segundo
        
        // 5. Now, process the complete files
        logger.debug("[DEBUG] === INICIANDO processRecordingFiles no Coordinator ===", category: .general)
        let finalAudioPath = await audioFileService.processRecordingFiles()
        logger.debug("[DEBUG] === FINALIZOU processRecordingFiles, resultado: \(finalAudioPath ?? "nil") ===", category: .general)
        
        // 6. Cleanup states
        logger.debug("[DEBUG] === INICIANDO cleanup ===", category: .general)
        audioFileService.cleanupState()
        await cleanupRecording()
        logger.debug("[DEBUG] === FINALIZOU cleanup ===", category: .general)
        
        // 🔧 DIAGNÓSTICO: Log final dos contadores
        logger.debug("🔍 DIAGNÓSTICO FINAL:")
        logger.debug("   • Sistema de áudio callbacks: \(systemAudioCallbackCount)")
        logger.debug("   • Arquivo de sistema escritas: \(diagnostics.getSystemAudioFileWriteCount())")
        logger.debug("   • Arquivo de microfone escritas: \(diagnostics.getMicrophoneFileWriteCount())")
        
        logger.recordingEvent("Recording stopped", meetingId: recordingState.currentMeetingId)
        logger.performance("Recording duration", duration: finalDuration)
        
        return (finalAudioPath, finalDuration)
    }
    
    // MARK: - Device Management (Delegated to MicrophoneService)
    
    /// Recarregar dispositivos de entrada disponíveis
    func loadAvailableDevices() {
        microphoneService.loadAvailableDevices()
        let devices = microphoneService.availableInputDevices
        recordingState.updateAvailableDevices(devices)
        
        // Atualizar dispositivo selecionado se necessário
        if let selectedDevice = microphoneService.selectedInputDevice {
            recordingState.selectInputDevice(selectedDevice)
        }
        
        logger.audioEvent("Devices reloaded", details: [
            "count": devices.count
        ])
    }
    
    /// Selecionar dispositivo de entrada
    func selectInputDevice(_ device: AudioDevice) {
        recordingState.selectInputDevice(device)
        microphoneService.selectInputDevice(device)
        
        logger.audioEvent("Input device selected", details: [
            "deviceName": device.name
        ])
    }
    
    /// Configurar se o áudio do sistema deve ser habilitado
    func setSystemAudioEnabled(_ enabled: Bool) {
        systemAudioEnabled = enabled
        recordingState.setSystemAudioEnabled(enabled)
        
        logger.audioEvent("System audio setting changed", details: [
            "enabled": enabled,
            "available": systemAudioAvailable
        ])
    }
    
    // MARK: - Private Setup Methods
    
    private func setupSpecializedModules() {
        logger.debug("Setting up specialized modules", category: .recording)
        
        // Configurar warmup manager
        warmupManager.delegate = self
        
        // Resetar sincronização
        synchronizer.resetSync()
    }
    
    private func setupStateBindings() {
        logger.debug("Setting up state bindings", category: .recording)
        
        // Bind recording state properties to coordinator published properties
        recordingState.$isRecording
            .receive(on: DispatchQueue.main)
            .assign(to: &$isRecording)
        
        recordingState.$isPaused
            .receive(on: DispatchQueue.main)
            .assign(to: &$isPaused)
            
        recordingState.$currentDuration
            .receive(on: DispatchQueue.main)
            .assign(to: &$currentDuration)
            
        recordingState.$audioLevel
            .receive(on: DispatchQueue.main)
            .assign(to: &$audioLevel)
            
        recordingState.$errorMessage
            .receive(on: DispatchQueue.main)
            .assign(to: &$errorMessage)
            
        recordingState.$availableInputDevices
            .receive(on: DispatchQueue.main)
            .assign(to: &$availableInputDevices)
            
        recordingState.$selectedInputDevice
            .receive(on: DispatchQueue.main)
            .assign(to: &$selectedInputDevice)
            
        recordingState.$systemAudioAvailable
            .receive(on: DispatchQueue.main)
            .assign(to: &$systemAudioAvailable)
            
        recordingState.$systemAudioEnabled
            .receive(on: DispatchQueue.main)
            .assign(to: &$systemAudioEnabled)
        
        // Bind warmup manager properties
        warmupManager.$isWarmingUp
            .receive(on: DispatchQueue.main)
            .assign(to: &$isWarmingUp)
            
        warmupManager.$warmupProgress
            .receive(on: DispatchQueue.main)
            .assign(to: &$warmupProgress)
            
        warmupManager.$warmupCountdown
            .receive(on: DispatchQueue.main)
            .assign(to: &$warmupCountdown)
    }
    
    private func setupServiceCallbacks() {
        logger.debug("Setting up service callbacks", category: .recording)
        
        // Callback para áudio do microfone
        microphoneService.onAudioReceived = { [weak self] buffer, hostTime in
            self?.handleMicrophoneAudio(buffer, hostTime: hostTime)
        }
        
        // Callback para áudio do sistema
        systemAudioService.onAudioReceived = { [weak self] buffer, hostTime in
            self?.handleSystemAudio(buffer, hostTime: hostTime)
        }
        
        // 🔧 CRÍTICO: Verificar saúde do sistema de áudio a cada 5 segundos (baseado no log de 78s gap)
        Task {
            while true {
                try await Task.sleep(nanoseconds: 5_000_000_000) // 5 segundos - detecção mais rápida
                await self.checkSystemAudioHealth()
            }
        }
    }
    
    // MARK: - WarmupManagerDelegate
    
    func warmupDidComplete() {
        logger.recordingEvent("Warmup completed, starting recording", meetingId: recordingState.currentMeetingId)
        
        // Se a captura foi iniciada durante o warmup, começar a gravação real
        if warmupManager.wasCaptureStartedDuringWarmup {
            recordingState.startRecording()
            
            // Resetar o sincronizador para que seja inicializado com buffers estáveis
            synchronizer.resetSync()
            
            logger.recordingEvent("Recording started after warmup", meetingId: recordingState.currentMeetingId)
        }
    }
    
    func warmupProgressDidUpdate(progress: Double, countdown: Int) {
        // UI updates are handled by the published properties binding
        // This method can be used for additional logic if needed
    }
    
    private func determineOptimalConfiguration() -> AudioConfiguration {
        // Determinar estratégia baseada em preferências e capacidades
        let strategy: AudioCaptureStrategy
        if systemAudioEnabled && recordingState.systemAudioAvailable {
            strategy = .screenCaptureKit
        } else {
            strategy = .microphoneOnly
        }
        
        return AudioConfiguration(
            captureStrategy: strategy,
            microphoneConfig: MicrophoneConfiguration(inputDevice: recordingState.selectedInputDevice),
            systemAudioConfig: systemAudioEnabled ? SystemAudioConfiguration.default : nil
        )
    }
    
    private func startMicrophoneCapture(configuration: AudioConfiguration) async throws {
        logger.audioEvent("Starting microphone capture")
        try await microphoneService.startCapture(configuration: configuration)
        logger.audioEvent("Microphone capture started")
    }
    
    private func startSystemAudioCapture(configuration: AudioConfiguration) async throws {
        logger.audioEvent("Starting system audio capture")
        try await systemAudioService.startCapture(configuration: configuration)
        logger.audioEvent("System audio capture started")
    }
    
    private func handleMicrophoneAudio(_ buffer: AVAudioPCMBuffer, hostTime: UInt64) {
        // Se estiver no período de aquecimento, analisar estabilidade
        if warmupManager.isInWarmup {
            // Apenas monitorar nível de áudio para feedback, mas não gravar
            recordingState.updateAudioLevel(from: buffer)
            
            // Analisar estabilidade do buffer
            warmupManager.analyzeMicrophoneBuffer(buffer)
            
            return
        }
        
        guard recordingState.isRecording && !recordingState.isPaused else { return }
        
        // Inicializar sincronização no primeiro buffer após o período de aquecimento
        if recordingState.isRecordingAfterWarmup {
            recordingState.registerFirstMicBuffer(hostTime: hostTime)
            tryInitializeSynchronizer()
        }
        
        // Write to file via AudioFileService
        audioFileService.writeMicrophoneAudio(buffer)
        
        // Update audio level for visual feedback
        recordingState.updateAudioLevel(from: buffer)
    }
    
    // 🔧 DIAGNÓSTICO: Contadores para monitoramento
    private var systemAudioCallbackCount = 0
    private var lastSystemAudioTime = Date()
    
    private func handleSystemAudio(_ buffer: AVAudioPCMBuffer, hostTime: UInt64) {
        // 🔧 DIAGNÓSTICO: Contar callbacks e monitorar timing
        systemAudioCallbackCount += 1
        let now = Date()
        let timeSinceLastCallback = now.timeIntervalSince(lastSystemAudioTime)
        lastSystemAudioTime = now
        
        if systemAudioCallbackCount == 1 {
            logger.debug("🎵 PRIMEIRO callback de sistema de áudio recebido!", category: .audio)
        }
        
        // Log a cada 1000 callbacks
        if systemAudioCallbackCount % 1000 == 0 {
            logger.debug("🔍 Sistema: \(systemAudioCallbackCount) callbacks recebidos (gap: \(String(format: "%.3f", timeSinceLastCallback))s)", category: .audio)
        }
        
        // Detectar gaps grandes (pode indicar problema)
        if systemAudioCallbackCount > 10 && timeSinceLastCallback > 2.0 {
            logger.warning("⚠️ Gap grande detectado no sistema de áudio: \(String(format: "%.3f", timeSinceLastCallback))s", category: .audio)
        }
        
        // Se estiver no período de aquecimento, analisar estabilidade
        if warmupManager.isInWarmup {
            // Analisar estabilidade do buffer
            warmupManager.analyzeSystemBuffer(buffer)
            
            return
        }
        
        guard recordingState.isRecording && !recordingState.isPaused else { 
            logger.debug("🔍 Sistema de áudio ignorado: recording=\(recordingState.isRecording), paused=\(recordingState.isPaused)", category: .audio)
            return 
        }
        
        // Inicializar sincronização no primeiro buffer após o período de aquecimento
        if recordingState.isRecordingAfterWarmup {
            recordingState.registerFirstSystemBuffer(hostTime: hostTime)
            tryInitializeSynchronizer()
        }
        
        // Write to file via AudioFileService
        audioFileService.writeSystemAudio(buffer)
    }
    
    private func tryInitializeSynchronizer() {
        guard let syncTimes = recordingState.canInitializeSync() else {
            return
        }
        
        synchronizer.initializeSync(systemTime: syncTimes.sysTime, microphoneTime: syncTimes.micTime)
    }
    
    private func cleanupRecording() async {
        logger.debug("Cleaning up recording", category: .recording)
        
        recordingState.cleanup()
    }
    
    // 🔧 NOVO: Verificação de saúde do sistema de áudio (melhorada com base no log)
    private func checkSystemAudioHealth() async {
        guard recordingState.isRecording && systemAudioEnabled else { return }
        
        // Verificar se o serviço de áudio do sistema ainda está capturando
        if !systemAudioService.isCapturing {
            logger.error("❌ CRÍTICO: Sistema de áudio parou de capturar durante gravação ativa!", category: .recording)
            logger.error("   • Gravação ativa: \(recordingState.isRecording)", category: .recording)
            logger.error("   • Microfone ainda capturando: \(microphoneService.isCapturing)", category: .recording)
            logger.error("   • DIAGNÓSTICO: ScreenCaptureKit provavelmente congelou silenciosamente", category: .recording)
            
            // Tentar diagnosticar o problema
            let isAvailable = await systemAudioService.isSystemAudioAvailable()
            logger.warning("   • Sistema de áudio ainda disponível: \(isAvailable)", category: .recording)
            
            if isAvailable {
                logger.info("🔄 RECUPERAÇÃO CRÍTICA: Reiniciando captura de áudio do sistema...", category: .recording)
                
                let configuration = determineOptimalConfiguration()
                do {
                    try await systemAudioService.startCapture(configuration: configuration)
                    logger.info("✅ Captura de áudio do sistema reiniciada com sucesso", category: .recording)
                    // Limpar erro se recuperação funcionar
                    recordingState.setError("")
                } catch {
                    logger.error("❌ Falha crítica ao reiniciar captura de áudio: \(error)", category: .recording)
                    recordingState.setError("ScreenCaptureKit falhou silenciosamente e não pôde ser recuperado")
                }
            } else {
                logger.error("❌ Sistema de áudio não está mais disponível após falha", category: .recording)
                recordingState.setError("ScreenCaptureKit perdeu acesso ao sistema de áudio")
            }
        }
    }
    
    // MARK: - Audio Capture Strategy Configuration
    
    /// Configura a estratégia de captura de áudio
    /// - Parameter strategy: Estratégia a ser utilizada (.screenCaptureKit, .coreAudioTaps, ou .microphoneOnly)
    func setAudioCaptureStrategy(_ strategy: AudioCaptureStrategy) {
        logger.info("Configurando estratégia de captura de áudio: \(strategy.rawValue)", category: .audio)
        
        // Evitar reconfigurar se já está usando a mesma estratégia
        guard currentCaptureStrategy != strategy else {
            logger.debug("Estratégia já configurada: \(strategy.rawValue)", category: .audio)
            return
        }
        
        currentCaptureStrategy = strategy
        
        switch strategy {
        case .screenCaptureKit:
            logger.debug("Configurando ScreenCaptureKit (padrão)", category: .audio)
            systemAudioService = originalSystemAudioService
            coreAudioTapService = nil
            
        case .coreAudioTaps:
            logger.info("🎯 Configurando Core Audio Tap (XPC + Helper Tool)", category: .audio)
            
            // Verificar compatibilidade de versão (agora requer macOS 13+)
            if #available(macOS 13, *) {
                if CoreAudioTapService.isSupported() {
                    logger.info("Sistema compatível com Core Audio Tap XPC", category: .audio)
                    
                    // Criar novo serviço Core Audio Tap com XPC
                    let tapService = CoreAudioTapService()
                    coreAudioTapService = tapService
                    systemAudioService = tapService
                    
                    logger.info("✅ Core Audio Tap XPC Service configurado", category: .audio)
                } else {
                    logger.warning("Sistema não suporta Core Audio Tap XPC - usando ScreenCaptureKit", category: .audio)
                    systemAudioService = originalSystemAudioService
                    currentCaptureStrategy = .screenCaptureKit
                }
            } else {
                logger.warning("macOS 13+ necessário para Core Audio Tap XPC - usando ScreenCaptureKit", category: .audio)
                systemAudioService = originalSystemAudioService
                currentCaptureStrategy = .screenCaptureKit
            }
            
        case .microphoneOnly:
            logger.debug("Configurando apenas microfone", category: .audio)
            // Desabilitar áudio do sistema
            systemAudioEnabled = false
            systemAudioService = originalSystemAudioService
            coreAudioTapService = nil
        }
        
        // Reconfigurar callbacks se necessário
        if isRecording {
            logger.warning("Mudança de estratégia durante gravação não recomendada", category: .audio)
        } else {
            setupServiceCallbacks()
        }
        
        logger.info("✅ Estratégia de captura configurada: \(currentCaptureStrategy.rawValue)", category: .audio)
    }
    
} 