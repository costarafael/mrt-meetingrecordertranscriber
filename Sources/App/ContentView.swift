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
                audioService.errorMessage = nil
            }
        } message: {
            if let error = audioService.errorMessage {
                Text(error)
            }
        }
        .onAppear {
            meetingStore.refreshData()
        }
        .onChange(of: audioService.isRecording) { isRecording in
            handleRecordingStateChange(isRecording)
        }
        .onChange(of: meetingStore.lastCompletedMeeting) { newMeeting in
            handleCompletedMeeting(newMeeting)
        }
        .onChange(of: meetingStore.currentMeeting) { currentMeeting in
            handleCurrentMeetingChange(currentMeeting)
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
            RecordingView(meeting: meeting, audioService: audioService)
                .onDisappear {
                    showingRecordingView = false
                }
                    } else {
            RecordingPreparationView()
        }
    }
    
    // MARK: - Event Handlers
    
    private func handleRecordingStateChange(_ isRecording: Bool) {
        if !isRecording && showingRecordingView {
            showingRecordingView = false
            
            if let lastMeeting = meetingStore.currentMeeting {
                selectedMeeting = lastMeeting
            }
        }
    }
    
    private func handleCompletedMeeting(_ newMeeting: Meeting?) {
        if let completedMeeting = newMeeting {
            selectedMeeting = completedMeeting
            meetingStore.clearLastCompletedMeeting()
        }
    }
    
    private func handleCurrentMeetingChange(_ currentMeeting: Meeting?) {
        if showingRecordingView && currentMeeting != nil && selectedMeeting == nil {
            selectedMeeting = currentMeeting
        }
    }
}
 