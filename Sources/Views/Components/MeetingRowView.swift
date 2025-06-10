import SwiftUI

struct MeetingRowView: View {
    let meeting: Meeting
    @EnvironmentObject var meetingStore: MeetingStore
    @State private var refreshTrigger = UUID()
    
    // Computed property para sempre pegar versão atualizada
    private var currentMeeting: Meeting {
        meetingStore.meetings.first { $0.id == meeting.id } ?? meeting
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(currentMeeting.title)
                    .font(.headline)
                    .lineLimit(1)
                
                Spacer()
                
                StatusBadge(status: currentMeeting.status)
            }
            
            HStack {
                Text(currentMeeting.formattedDate)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(currentMeeting.formattedDuration)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if currentMeeting.audioFilePath != nil {
                    Image(systemName: "waveform")
                        .font(.caption2)
                        .foregroundColor(.blue)
                }
            }
            
            if !currentMeeting.notes.isEmpty {
                Text(currentMeeting.notes)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
        .id(refreshTrigger) // Força refresh quando trigger muda
        .onReceive(meetingStore.$meetings) { updatedMeetings in
            // Encontrar a versão nova e a antiga da nossa reunião
            guard let oldMeeting = meetingStore.meetings.first(where: { $0.id == self.meeting.id }),
                  let newMeeting = updatedMeetings.first(where: { $0.id == self.meeting.id }) else {
                return
            }

            // Comparar se houve mudança de status
            if oldMeeting.status != newMeeting.status {
                print("🔄 Row refresh: \(newMeeting.title) - Status: \(oldMeeting.status.displayName) → \(newMeeting.status.displayName)")
                refreshTrigger = UUID() // Força refresh da view
            }
        }
        .contextMenu {
            Button("Exportar") {
                exportMeeting()
            }
            .disabled(currentMeeting.audioFilePath == nil)
            
            Button("Excluir Áudio") {
                meetingStore.deleteAudioArtifacts(for: currentMeeting)
            }
            .disabled(currentMeeting.audioFilePath == nil)
            
            Divider()
            
            Button("Excluir Reunião", role: .destructive) {
                Task {
                    await meetingStore.deleteMeeting(currentMeeting)
                }
            }
        }
    }
    
    private func exportMeeting() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.audio]
        panel.nameFieldStringValue = "\(currentMeeting.title).m4a"
        
        if panel.runModal() == .OK, let url = panel.url {
            try? meetingStore.exportMeeting(currentMeeting, to: url)
        }
    }
} 