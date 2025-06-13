import Foundation
import SwiftUI

@MainActor
class AudioManager: ObservableObject {
    @Published var isHelperInstalled = false
    @Published var isCapturing = false
    @Published var isLoading = false
    @Published var lastError = ""
    @Published var deviceName = ""
    
    private let helperManager = HelperManager.shared
    private let xpcClient = XPCClient()
    
    var helperStatus: String {
        isHelperInstalled ? "Instalada" : "Não Instalada"
    }
    
    var captureStatus: String {
        if !isHelperInstalled {
            return "Helper Não Disponível"
        }
        return isCapturing ? "Ativa" : "Inativa"
    }
    
    func checkHelperStatus() {
        isLoading = true
        lastError = ""
        
        Task {
            do {
                let installed = try await helperManager.isHelperInstalled()
                await MainActor.run {
                    self.isHelperInstalled = installed
                    self.isLoading = false
                }
                
                if installed {
                    await checkCaptureStatus()
                }
            } catch {
                await MainActor.run {
                    self.isHelperInstalled = false
                    self.lastError = "Erro verificando helper: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }
    
    func installHelperTool() {
        isLoading = true
        lastError = ""
        
        helperManager.installHelperIfNeeded { [weak self] result in
            Task { @MainActor in
                guard let self = self else { return }
                
                switch result {
                case .success:
                    self.isHelperInstalled = true
                    self.lastError = ""
                    print("✅ Helper tool instalada com sucesso")
                case .failure(let error):
                    self.isHelperInstalled = false
                    self.lastError = "Falha na instalação: \(error.localizedDescription)"
                    print("❌ Erro na instalação: \(error)")
                }
                self.isLoading = false
            }
        }
    }
    
    func startSystemAudioCapture() {
        guard isHelperInstalled else {
            lastError = "Helper tool não está instalada"
            return
        }
        
        isLoading = true
        lastError = ""
        
        let helper = xpcClient.getHelperService { [weak self] error in
            Task { @MainActor in
                self?.lastError = "Erro conectando XPC: \(error.localizedDescription)"
                self?.isLoading = false
            }
        }
        
        guard let helper = helper else {
            isLoading = false
            return
        }
        
        // PID 0 = capturar todo o sistema
        helper.startAudioCapture(forPID: 0) { [weak self] success, error in
            Task { @MainActor in
                guard let self = self else { return }
                
                if success {
                    self.isCapturing = true
                    self.lastError = ""
                    print("✅ Captura de áudio iniciada")
                    await self.checkCaptureStatus()
                } else {
                    let errorMsg = error?.localizedDescription ?? "Erro desconhecido"
                    self.lastError = "Falha ao iniciar captura: \(errorMsg)"
                    print("❌ Erro iniciando captura: \(errorMsg)")
                }
                self.isLoading = false
            }
        }
    }
    
    func stopAudioCapture() {
        guard isHelperInstalled else {
            lastError = "Helper tool não está instalada"
            return
        }
        
        isLoading = true
        lastError = ""
        
        let helper = xpcClient.getHelperService { [weak self] error in
            Task { @MainActor in
                self?.lastError = "Erro conectando XPC: \(error.localizedDescription)"
                self?.isLoading = false
            }
        }
        
        guard let helper = helper else {
            isLoading = false
            return
        }
        
        helper.stopAudioCapture { [weak self] success, error in
            Task { @MainActor in
                guard let self = self else { return }
                
                if success {
                    self.isCapturing = false
                    self.deviceName = ""
                    self.lastError = ""
                    print("✅ Captura de áudio parada")
                } else {
                    let errorMsg = error?.localizedDescription ?? "Erro desconhecido"
                    self.lastError = "Falha ao parar captura: \(errorMsg)"
                    print("❌ Erro parando captura: \(errorMsg)")
                }
                self.isLoading = false
            }
        }
    }
    
    func checkStatus() {
        Task {
            await checkCaptureStatus()
        }
    }
    
    private func checkCaptureStatus() async {
        guard isHelperInstalled else { return }
        
        let helper = xpcClient.getHelperService { [weak self] error in
            Task { @MainActor in
                self?.lastError = "Erro conectando XPC: \(error.localizedDescription)"
            }
        }
        
        guard let helper = helper else { return }
        
        helper.getCaptureStatus { [weak self] capturing, deviceName in
            Task { @MainActor in
                guard let self = self else { return }
                self.isCapturing = capturing
                self.deviceName = deviceName ?? ""
            }
        }
    }
}