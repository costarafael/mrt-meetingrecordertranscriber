import Foundation

class XPCClient {
    private var connection: NSXPCConnection?
    private let helperLabel = "com.empresa.CoreAudioTapReal.AudioCaptureHelper"
    
    deinit {
        connection?.invalidate()
    }
    
    private func setupConnection() {
        if connection != nil { return }
        
        print("🔗 Configurando conexão XPC com \(helperLabel)")
        
        let newConnection = NSXPCConnection(machServiceName: helperLabel, options: .privileged)
        newConnection.remoteObjectInterface = NSXPCInterface(with: AudioHelperProtocol.self)
        
        newConnection.invalidationHandler = { [weak self] in
            print("⚠️ Conexão XPC invalidada")
            self?.connection = nil
        }
        
        newConnection.interruptionHandler = { [weak self] in
            print("⚠️ Conexão XPC interrompida")
            self?.connection = nil
        }
        
        self.connection = newConnection
        self.connection?.resume()
        print("✅ Conexão XPC configurada e iniciada")
    }
    
    func getHelperService(errorHandler: @escaping (Error) -> Void) -> AudioHelperProtocol? {
        if connection == nil {
            setupConnection()
        }
        
        guard let connection = connection else {
            let error = NSError(
                domain: "com.empresa.XPCError",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Falha ao configurar conexão XPC"]
            )
            errorHandler(error)
            return nil
        }
        
        let remoteObject = connection.remoteObjectProxyWithErrorHandler { error in
            print("❌ Erro no proxy remoto XPC: \(error.localizedDescription)")
            errorHandler(error)
        }
        
        guard let helper = remoteObject as? AudioHelperProtocol else {
            let error = NSError(
                domain: "com.empresa.XPCError",
                code: -2,
                userInfo: [NSLocalizedDescriptionKey: "Falha ao obter interface do helper"]
            )
            errorHandler(error)
            return nil
        }
        
        return helper
    }
    
    func invalidateConnection() {
        connection?.invalidate()
        connection = nil
    }
}