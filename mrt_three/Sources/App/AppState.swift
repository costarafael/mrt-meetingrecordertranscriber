import Foundation
import SwiftUI

/// Estado central da aplicação - gerencia ciclo de vida seguro
@MainActor
final class AppState: ObservableObject {
    
    // MARK: - Services
    
    let meetingStore: MeetingStore
    let audioService: AudioRecordingCoordinator
    
    // MARK: - Private Properties
    
    private let logger = LoggingService.shared
    private var isInitialized = false
    
    // MARK: - Initialization
    
    init() {
        logger.info("🚀 Initializing AppState", category: .general)
        
        // Criar services base
        let microphoneService = MicrophoneCaptureService()
        let systemAudioService = SystemAudioCaptureService()
        let audioFileManager = AudioFileManager()
        let permissionManager = AudioPermissionManager()
        let formatConverter = UnifiedAudioConverter()
        let synchronizer = AudioSynchronizer()
        
        // Criar AudioRecordingCoordinator
        self.audioService = AudioRecordingCoordinator(
            microphoneService: microphoneService,
            systemAudioService: systemAudioService,
            audioFileManager: audioFileManager,
            permissionManager: permissionManager,
            formatConverter: formatConverter,
            synchronizer: synchronizer
        )
        
        // Criar MeetingStore
        self.meetingStore = MeetingStore()
        
        logger.info("✅ AppState created successfully", category: .general)
    }
    
    // MARK: - Public Methods
    
    /// Inicializar aplicação de forma segura
    func initialize() {
        guard !isInitialized else {
            logger.warning("AppState já foi inicializado", category: .general)
            return
        }
        
        logger.info("🔧 Initializing app components", category: .general)
        
        // Inicializar MeetingStore de forma assíncrona
        meetingStore.initializeAsync()
        
        // Conectar MeetingStore com AudioService
        meetingStore.setAudioService(audioService)
        
        // Configurar áudio do sistema
        audioService.setSystemAudioEnabled(true)
        
        // Inicializar AudioService de forma assíncrona
        Task {
            await audioService.initialize()
            logger.info("✅ AudioService initialized successfully", category: .general)
        }
        
        isInitialized = true
        logger.info("🎉 App initialization complete", category: .general)
    }
    
    // MARK: - Cleanup
    
    deinit {
        logger.info("🗑️ AppState deinit - cleaning up", category: .memory)
        
        // Não é mais necessário fechar janelas NSWindow - usando SwiftUI sheets
        
        logger.info("✅ AppState cleanup complete", category: .memory)
    }
}