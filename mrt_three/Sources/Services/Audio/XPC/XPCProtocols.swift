import Foundation

// MARK: - XPC Protocol Bridge

/// Bridge para o protocolo AudioHelperProtocol definido em Objective-C
/// Permite comunicação entre a aplicação Swift e a Helper Tool
protocol AudioHelperProtocolSwift {
    func getVersion() async throws -> String
    func startAudioCapture(forPID processID: pid_t) async throws -> Bool
    func stopAudioCapture() async throws -> Bool
    func getCaptureStatus() async throws -> (isCapturing: Bool, deviceName: String?)
}

// MARK: - Helper Installation Manager Protocol

protocol HelperInstallationManagerProtocol {
    func isHelperInstalled() async throws -> Bool
    func installHelperIfNeeded() async throws -> Bool
    func checkHelperVersion() async throws -> String?
    func createXPCConnection() -> NSXPCConnection?
}

// MARK: - XPC Error Types

enum XPCError: LocalizedError {
    case connectionFailed
    case helperNotInstalled
    case installationFailed(String)
    case communicationTimeout
    case invalidResponse
    case helperVersionMismatch
    
    var errorDescription: String? {
        switch self {
        case .connectionFailed:
            return "Falha ao conectar com Helper Tool"
        case .helperNotInstalled:
            return "Helper Tool não está instalada"
        case .installationFailed(let reason):
            return "Falha na instalação da Helper Tool: \(reason)"
        case .communicationTimeout:
            return "Timeout na comunicação XPC"
        case .invalidResponse:
            return "Resposta inválida da Helper Tool"
        case .helperVersionMismatch:
            return "Versão incompatível da Helper Tool"
        }
    }
}

// MARK: - Helper Installation Status

struct HelperInstallationStatus {
    let isInstalled: Bool
    let version: String?
    let canInstall: Bool
    let lastError: Error?
    
    var needsInstallation: Bool {
        return !isInstalled && canInstall
    }
}