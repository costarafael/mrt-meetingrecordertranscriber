import Foundation

class FileSystemWatcher {
    private var source: DispatchSourceFileSystemObject?
    private let directory: URL
    private let onChange: () -> Void
    
    init(directory: URL, onChange: @escaping () -> Void) {
        self.directory = directory
        self.onChange = onChange
        startWatching()
    }
    
    private func startWatching() {
        guard FileManager.default.fileExists(atPath: directory.path) else {
            // Criar diretório se não existir
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            return
        }
        
        let fileDescriptor = open(directory.path, O_EVTONLY)
        guard fileDescriptor >= 0 else {
            print("❌ Erro ao abrir diretório para monitoramento: \(directory.path)")
            return
        }
        
        source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .delete, .rename],
            queue: DispatchQueue.global(qos: .utility)
        )
        
        source?.setEventHandler { [weak self] in
            DispatchQueue.main.async {
                self?.onChange()
            }
        }
        
        source?.setCancelHandler {
            close(fileDescriptor)
        }
        
        source?.resume()
        print("👁️ FileSystemWatcher monitorando: \(directory.path)")
    }
    
    deinit {
        source?.cancel()
    }
} 