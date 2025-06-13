#!/usr/bin/swift

import Foundation

print("🧪 TESTE SIMPLES - Core Audio TAP Real")
print("=====================================")

// Verificar se a aplicação está rodando
let task = Process()
task.launchPath = "/bin/ps"
task.arguments = ["aux"]

let pipe = Pipe()
task.standardOutput = pipe
task.launch()

let data = pipe.fileHandleForReading.readDataToEndOfFile()
let output = String(data: data, encoding: .utf8) ?? ""

if output.contains("CoreAudioTapReal") {
    print("✅ Aplicação CoreAudioTapReal está rodando")
    
    // Verificar se há helper tool instalada
    let launchctl = Process()
    launchctl.launchPath = "/bin/launchctl"
    launchctl.arguments = ["list"]
    
    let launchPipe = Pipe()
    launchctl.standardOutput = launchPipe
    launchctl.launch()
    
    let launchData = launchPipe.fileHandleForReading.readDataToEndOfFile()
    let launchOutput = String(data: launchData, encoding: .utf8) ?? ""
    
    if launchOutput.contains("AudioCaptureHelper") {
        print("✅ Helper tool está instalada via launchd")
    } else {
        print("⚠️  Helper tool não está instalada via launchd")
    }
    
} else {
    print("❌ Aplicação CoreAudioTapReal não está rodando")
}

print("")
print("📋 INSTRUÇÕES:")
print("1. Se a aplicação está rodando mas sem interface:")
print("   - Pressione Cmd+Tab para encontrar a aplicação")
print("   - Ou clique no ícone no Dock")
print("")
print("2. Para testar a captura de áudio:")
print("   - Abra YouTube ou qualquer player de música")
print("   - Use a interface da aplicação para:")
print("     * Instalar Helper Tool")
print("     * Iniciar Captura do Sistema")
print("     * Verificar Status")
print("")
print("3. Monitorar logs no Console.app:")
print("   - Procure por 'AudioCaptureHelper'")
print("   - Ou use: sudo log stream --process AudioCaptureHelper")

exit(0)