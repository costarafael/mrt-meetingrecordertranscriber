import Cocoa
import SwiftUI

@main 
struct MinimalApp: App {
    var body: some Scene {
        WindowGroup {
            VStack {
                Text("🎧 Core Audio TAP TESTE")
                    .font(.largeTitle)
                Text("Se você vê esta janela, a aplicação funciona\!")
                    .padding()
                Button("Testar Audio") {
                    print("Botão clicado\!")
                }
                .padding()
            }
            .frame(width: 400, height: 300)
        }
    }
}
EOF < /dev/null