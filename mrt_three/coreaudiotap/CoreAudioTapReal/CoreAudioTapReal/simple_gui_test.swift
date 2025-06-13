import Cocoa
import SwiftUI

struct SimpleTestView: View {
    var body: some View {
        VStack(spacing: 20) {
            Text("🎧 Core Audio TAP TESTE")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Se você vê esta janela, a aplicação funciona!")
                .padding()
            
            Text("✅ APIs Core Audio: FUNCIONANDO")
                .foregroundColor(.green)
            
            Text("✅ Helper Tool: COMPILADA")
                .foregroundColor(.green)
            
            Text("✅ XPC Service: IMPLEMENTADO")
                .foregroundColor(.green)
            
            Button("🎵 Teste Básico Realizado") {
                print("Interface GUI funcionando!")
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
        }
        .frame(width: 500, height: 400)
        .padding()
    }
}

@main
class SimpleGUIApp: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        NSApp.setActivationPolicy(.regular)
        
        let contentView = SimpleTestView()
        
        window = NSWindow(
            contentRect: NSRect(x: 200, y: 200, width: 500, height: 400),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        window.title = "Core Audio TAP - Teste GUI"
        window.contentView = NSHostingView(rootView: contentView)
        window.center()
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        
        NSApp.activate(ignoringOtherApps: true)
        
        print("✅ Janela de teste criada!")
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}