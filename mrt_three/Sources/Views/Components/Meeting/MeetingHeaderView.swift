import SwiftUI

struct MeetingHeaderView: View {
    @Binding var meeting: Meeting
    @State private var editingTitle = false
    @State private var titleText = ""
    
    let onTitleUpdate: (String) -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            titleSection
            statusAndMetadataSection
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Subviews
    
    private var titleSection: some View {
        HStack {
            if editingTitle {
                TextField("Título da reunião", text: $titleText)
                    .textFieldStyle(.roundedBorder)
                    .font(.title2)
                    .onSubmit {
                        saveTitleEdit()
                    }
                    .onAppear {
                        titleText = meeting.title
                    }
            } else {
                Text(meeting.title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Button("Editar") {
                    startTitleEdit()
                }
                .buttonStyle(.bordered)
            }
        }
    }
    
    private var statusAndMetadataSection: some View {
        HStack {
            StatusBadge(status: meeting.status)
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(meeting.formattedDate)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(meeting.formattedDuration)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if meeting.audioFilePath != nil {
                    HStack(spacing: 4) {
                        Image(systemName: "waveform")
                            .font(.caption2)
                            .foregroundColor(.blue)
                        Text("Áudio disponível")
                            .font(.caption2)
                            .foregroundColor(.blue)
                    }
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func startTitleEdit() {
        titleText = meeting.title
        editingTitle = true
    }
    
    private func saveTitleEdit() {
        let newTitle = titleText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if !newTitle.isEmpty && newTitle != meeting.title {
            meeting.title = newTitle
            onTitleUpdate(newTitle)
        }
        
        editingTitle = false
    }
}

#Preview {
    MeetingHeaderView(
        meeting: .constant(Meeting()),
        onTitleUpdate: { _ in }
    )
    .frame(width: 400)
    .padding()
}