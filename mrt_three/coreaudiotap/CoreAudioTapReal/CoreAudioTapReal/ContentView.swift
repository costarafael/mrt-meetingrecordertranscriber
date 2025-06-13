import SwiftUI

struct ContentView: View {
    @StateObject private var audioManager = AudioManager()
    
    var body: some View {
        VStack(spacing: 20) {
            Text("🎧 Core Audio TAP REAL")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("POC Funcional - Captura de Áudio do Sistema")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            VStack(spacing: 12) {
                HStack {
                    Text("Status da Helper Tool:")
                    Text(audioManager.helperStatus)
                        .foregroundColor(audioManager.isHelperInstalled ? .green : .red)
                        .fontWeight(.medium)
                }
                
                HStack {
                    Text("Status da Captura:")
                    Text(audioManager.captureStatus)
                        .foregroundColor(audioManager.isCapturing ? .green : .orange)
                        .fontWeight(.medium)
                }
                
                if !audioManager.deviceName.isEmpty {
                    HStack {
                        Text("Dispositivo:")
                        Text(audioManager.deviceName)
                            .fontWeight(.medium)
                    }
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
            
            VStack(spacing: 12) {
                Button("🔧 Instalar Helper Tool") {
                    audioManager.installHelperTool()
                }
                .disabled(audioManager.isHelperInstalled || audioManager.isLoading)
                .buttonStyle(.borderedProminent)
                
                Button("🎵 Iniciar Captura REAL do Sistema") {
                    audioManager.startSystemAudioCapture()
                }
                .disabled(!audioManager.isHelperInstalled || audioManager.isCapturing || audioManager.isLoading)
                .buttonStyle(.bordered)
                
                Button("⏹️ Parar Captura") {
                    audioManager.stopAudioCapture()
                }
                .disabled(!audioManager.isCapturing || audioManager.isLoading)
                .buttonStyle(.bordered)
                
                Button("📊 Verificar Status") {
                    audioManager.checkStatus()
                }
                .disabled(!audioManager.isHelperInstalled || audioManager.isLoading)
                .buttonStyle(.bordered)
            }
            
            if audioManager.isLoading {
                ProgressView("Processando...")
                    .scaleEffect(0.8)
            }
            
            if !audioManager.lastError.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("❌ Erro:")
                        .fontWeight(.bold)
                        .foregroundColor(.red)
                    Text(audioManager.lastError)
                        .font(.caption)
                        .multilineTextAlignment(.leading)
                }
                .padding()
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)
            }
            
            Spacer()
            
            Text("Esta é uma implementação REAL de Core Audio TAP")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(30)
        .frame(minWidth: 500, minHeight: 400)
        .onAppear {
            audioManager.checkHelperStatus()
        }
    }
}

#Preview {
    ContentView()
}