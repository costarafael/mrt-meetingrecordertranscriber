import SwiftUI

struct ContentView: View {
    @EnvironmentObject var meetingStore: MeetingStore
    @EnvironmentObject var audioService: AudioRecordingCoordinator
    @State private var selectedMeeting: Meeting?
    @State private var showingRecordingView = false
    @State private var showingAudioSettings = false
    
    var body: some View {
        NavigationSplitView {
            SidebarView(
                selectedMeeting: $selectedMeeting, 
                showingRecordingView: $showingRecordingView,
                showingAudioSettings: $showingAudioSettings
            )
        } detail: {
            detailView
        }
        .navigationSplitViewStyle(.balanced)
        .sheet(isPresented: $showingAudioSettings) {
            AudioSettingsView()
        }
        .alert("Erro", isPresented: .constant(audioService.errorMessage != nil)) {
            Button("OK") {
                meetingStore.clearError()
            }
        } message: {
            if let error = audioService.errorMessage {
                Text(error)
            }
        }
        .onAppear {
            meetingStore.refreshData()
        }
        .onChange(of: meetingStore.lastCompletedMeeting) { newMeeting in
            if let completedMeeting = newMeeting {
                selectedMeeting = completedMeeting
                meetingStore.clearLastCompletedMeeting()
            }
        }
    }
    
    @ViewBuilder
    private var detailView: some View {
        if showingRecordingView {
            recordingDetailView
        } else if let meeting = selectedMeeting {
            MeetingDetailView(meeting: meeting)
        } else {
            WelcomeView(showingRecordingView: $showingRecordingView)
        }
    }
    
    @ViewBuilder
    private var recordingDetailView: some View {
        if let meeting = meetingStore.currentMeeting ?? selectedMeeting {
            RecordingView(meeting: meeting)
                .onDisappear {
                    showingRecordingView = false
                }
                    } else {
            RecordingPreparationView()
        }
    }
    
}
 