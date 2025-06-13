import SwiftUI

@main
struct MacOSAppApp: App {
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState.meetingStore)
                .environmentObject(appState.audioService)
                .frame(minWidth: 800, minHeight: 600)
                .onAppear {
                    appState.initialize()
                }
        }
        .windowResizability(.contentSize)
    }
} 