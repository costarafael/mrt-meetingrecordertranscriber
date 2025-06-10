import SwiftUI

struct AudioSettingsView: View {
    @EnvironmentObject var audioService: AudioRecordingCoordinator
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Configurações de Áudio")
                .font(.title2)
                .fontWeight(.bold)
            
            // Dispositivo de Entrada
            InputDeviceSection()
            
            // Áudio do Sistema
            SystemAudioSection()
            
            Spacer()
        }
        .frame(width: 600, height: 500)
        .onAppear {
            audioService.loadAvailableDevices()
        }
    }
}

// MARK: - Input Device Section

private struct InputDeviceSection: View {
    @EnvironmentObject var audioService: AudioRecordingCoordinator
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Dispositivo de Entrada")
                .font(.headline)
            
            Picker("Dispositivo de Entrada", selection: $audioService.selectedInputDevice) {
                ForEach(audioService.availableInputDevices) { device in
                    Text(device.name).tag(device as AudioDevice?)
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity, alignment: .leading)
            .onChange(of: audioService.selectedInputDevice) { newDevice in
                if let device = newDevice {
                    audioService.selectInputDevice(device)
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal)
    }
}

// MARK: - System Audio Section

private struct SystemAudioSection: View {
    @EnvironmentObject var audioService: AudioRecordingCoordinator
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Áudio do Sistema")
                .font(.headline)
            
            // Status da disponibilidade
            SystemAudioStatusView()
            
            // Controle de habilitação (apenas se disponível)
            if audioService.systemAudioAvailable {
                Divider()
                SystemAudioToggleView()
                
                // Informação sobre implementação real
                if audioService.systemAudioEnabled {
                    SystemAudioImplementationInfo()
                }
            }
            
            // Resumo do que será gravado
            Divider()
            RecordingSummaryView()
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal)
    }
}

// MARK: - System Audio Components

private struct SystemAudioStatusView: View {
    @EnvironmentObject var audioService: AudioRecordingCoordinator
    
    var body: some View {
        HStack {
            Image(systemName: audioService.systemAudioAvailable ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(audioService.systemAudioAvailable ? .green : .red)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(audioService.systemAudioAvailable ? 
                     "Disponível (macOS 13+)" : 
                     "Indisponível")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                if !audioService.systemAudioAvailable {
                    Text("Atualize para macOS 13+ para gravar áudio do sistema")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
    }
}

private struct SystemAudioToggleView: View {
    @EnvironmentObject var audioService: AudioRecordingCoordinator
    
    var body: some View {
        Toggle(isOn: $audioService.systemAudioEnabled) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Gravar Áudio do Sistema")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("Inclui áudio de apps, música, vídeos, notificações, etc.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .disabled(audioService.isRecording)
        .onChange(of: audioService.systemAudioEnabled) { enabled in
            audioService.setSystemAudioEnabled(enabled)
        }
    }
}

private struct SystemAudioImplementationInfo: View {
    var body: some View {
        HStack {
            Image(systemName: "checkmark.circle")
                .foregroundColor(.green)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Captura Nativa Implementada")
                    .font(.caption)
                    .fontWeight(.medium)
                
                Text("Sistema de captura de áudio do sistema totalmente funcional usando ScreenCaptureKit + AVAudioEngine com mixagem em tempo real.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(8)
        .background(Color.green.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

private struct RecordingSummaryView: View {
    @EnvironmentObject var audioService: AudioRecordingCoordinator
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Será Gravado:")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            HStack {
                Image(systemName: "mic.fill")
                    .foregroundColor(.green)
                    .font(.caption)
                Text("Microfone")
                    .font(.caption)
                
                if audioService.systemAudioAvailable && audioService.systemAudioEnabled {
                    Image(systemName: "plus")
                        .foregroundColor(.secondary)
                        .font(.caption)
                    
                    Image(systemName: "speaker.wave.2.fill")
                        .foregroundColor(.blue)
                        .font(.caption)
                    Text("Áudio do Sistema")
                        .font(.caption)
                }
                
                Spacer()
            }
        }
    }
} 