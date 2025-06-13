import SwiftUI

struct RecordingPreparationView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
                .scaleEffect(1.5)
            
            Text("Preparando gravação...")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("Criando reunião e configurando áudio...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.textBackgroundColor))
    }
} 