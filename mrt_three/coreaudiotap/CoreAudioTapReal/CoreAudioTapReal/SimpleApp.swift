import Cocoa
import SwiftUI

@main
class SimpleApp: NSObject, NSApplicationDelegate {
    
    var window: NSWindow!
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        print("🚀 Aplicação iniciando...")
        
        // Força o app a não terminar quando a janela fecha
        NSApp.setActivationPolicy(.regular)
        
        // Cria uma janela simples e forçada
        let contentView = ContentView()
        
        window = NSWindow(
            contentRect: NSRect(x: 100, y: 100, width: 600, height: 500),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        window.title = "🎧 Core Audio TAP Real - POC Funcional"
        window.contentView = NSHostingView(rootView: contentView)
        window.isReleasedWhenClosed = false
        
        // FORÇA a janela a aparecer
        window.center()
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        
        // Ativa a aplicação
        NSApp.activate(ignoringOtherApps: true)
        
        print("✅ Janela criada e exibida!")
        print("📍 Posição: \(window.frame)")
        print("👁️ Visível: \(window.isVisible)")
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        print("🛑 Aplicação terminando...")
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
    
    func applicationDidBecomeActive(_ notification: Notification) {
        print("🎯 Aplicação ativada!")
        // Garante que a janela está visível quando a app fica ativa
        if let window = window {
            window.makeKeyAndOrderFront(nil)
        }
    }
}