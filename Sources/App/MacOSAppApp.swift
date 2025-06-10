import SwiftUI

@main
struct MacOSAppApp: App {
    @StateObject private var meetingStore = MeetingStore()
    @StateObject private var audioService: AudioRecordingCoordinator = {
        let microphoneService = MicrophoneCaptureService()
        let systemAudioService = SystemAudioCaptureService()
        let audioFileManager = AudioFileManager()
        let permissionManager = AudioPermissionManager()
        let formatConverter = AudioFormatConverter()
        let synchronizer = AudioSynchronizer()
        
        return AudioRecordingCoordinator(
            microphoneService: microphoneService,
            systemAudioService: systemAudioService,
            audioFileManager: audioFileManager,
            permissionManager: permissionManager,
            formatConverter: formatConverter,
            synchronizer: synchronizer
        )
    }()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(meetingStore)
                .environmentObject(audioService)
                .frame(minWidth: 800, minHeight: 600)
                .onAppear {
                    meetingStore.setAudioService(audioService)
                    
                    audioService.setSystemAudioEnabled(true)
                    
                    Task {
                        await audioService.initialize()
                    }
                }
        }
        .windowResizability(.contentSize)
    }
} 