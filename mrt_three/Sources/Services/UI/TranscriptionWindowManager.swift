import Foundation
import SwiftUI
import AppKit

/// Gerenciador seguro para janelas de transcrição
/// Resolve problemas de ciclo de vida e vazamentos de memória
@MainActor
final class TranscriptionWindowManager: NSObject {
    static let shared = TranscriptionWindowManager()
    
    private var windows: [UUID: TranscriptionWindow] = [:]
    private let logger = LoggingService.shared
    
    private override init() {
        super.init()
    }
    
    /// Mostrar janela de transcrição
    /// - Parameters:
    ///   - result: Resultado da transcrição
    ///   - meetingStore: Store da reunião
    func showTranscription(result: TranscriptionResult, meetingStore: MeetingStore) {
        logger.info("🪟 Criando janela de transcrição para: \(result.taskId)", category: .ui)
        
        // Verificar se já existe janela para esta transcrição
        if let existingWindow = windows[result.taskId] {
            logger.debug("Janela já existe, trazendo para frente", category: .ui)
            existingWindow.window.makeKeyAndOrderFront(nil)
            return
        }
        
        // Criar nova janela
        let transcriptionWindow = TranscriptionWindow(
            result: result,
            meetingStore: meetingStore,
            onClose: { [weak self] windowId in
                self?.removeWindow(windowId)
            }
        )
        
        // Armazenar referência
        windows[result.taskId] = transcriptionWindow
        
        // Mostrar janela
        transcriptionWindow.show()
        
        logger.info("✅ Janela de transcrição criada e exibida", category: .ui)
    }
    
    /// Remover janela da memória
    private func removeWindow(_ windowId: UUID) {
        logger.info("🗑️ Removendo janela de transcrição: \(windowId)", category: .ui)
        windows.removeValue(forKey: windowId)
    }
    
    /// Fechar todas as janelas
    func closeAllWindows() {
        logger.info("🚪 Fechando todas as janelas de transcrição", category: .ui)
        for window in windows.values {
            window.close()
        }
        windows.removeAll()
    }
}

// MARK: - Wrapper para janela individual

@MainActor
private final class TranscriptionWindow: NSObject, NSWindowDelegate {
    let window: NSWindow
    private let result: TranscriptionResult
    private let onClose: (UUID) -> Void
    private var hostingView: NSHostingView<AnyView>?
    private let logger = LoggingService.shared
    
    init(result: TranscriptionResult, meetingStore: MeetingStore, onClose: @escaping (UUID) -> Void) {
        self.result = result
        self.onClose = onClose
        
        // Criar conteúdo da view
        let contentView = AnyView(
            TranscriptionView(result: result)
                .environmentObject(meetingStore)
        )
        
        self.hostingView = NSHostingView(rootView: contentView)
        
        // Criar janela
        self.window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 700),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        
        super.init()
        
        // Configurar janela
        window.title = "Transcrição"
        window.minSize = NSSize(width: 600, height: 400)
        window.contentView = hostingView
        window.delegate = self
        window.center()
        
        // Configurar aparência
        window.titlebarAppearsTransparent = false
        window.isReleasedWhenClosed = true
        
        logger.debug("TranscriptionWindow criada", category: .ui)
    }
    
    func show() {
        window.makeKeyAndOrderFront(nil)
    }
    
    func close() {
        window.close()
    }
    
    // MARK: - NSWindowDelegate
    
    func windowWillClose(_ notification: Notification) {
        logger.debug("🚪 windowWillClose chamado para janela de transcrição", category: .ui)
        
        // Cleanup explícito
        cleanup()
        
        // Notificar gerenciador
        onClose(result.taskId)
    }
    
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        logger.debug("windowShouldClose chamado", category: .ui)
        return true
    }
    
    private func cleanup() {
        logger.debug("🧹 Limpando recursos da janela de transcrição", category: .ui)
        
        // Remover delegate
        window.delegate = nil
        
        // Limpar hosting view
        if let hostingView = hostingView {
            hostingView.removeFromSuperview()
            self.hostingView = nil
        }
        
        // Limpar content view
        window.contentView = nil
        
        logger.debug("✅ Cleanup concluído", category: .ui)
    }
    
    deinit {
        logger.debug("🗑️ TranscriptionWindow deinit chamado", category: .ui)
    }
}