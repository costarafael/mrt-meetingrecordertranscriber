import Foundation

print("=== MRT Audio Driver Control ===")
print()

let driverManager = AudioDriverManager()

// Verifica status do driver
print("Status do Driver MRT:")
print("- Instalado: \(driverManager.isDriverInstalled() ? "✅" : "❌")")
print("- Ativo: \(driverManager.isDriverActive() ? "✅" : "❌")")
print()

// Lista dispositivos de áudio
print("Dispositivos de Áudio Disponíveis:")
let devices = driverManager.listAudioDevices()
for (deviceID, name) in devices {
    let isMRT = name.contains("MRTAudio")
    let indicator = isMRT ? "🎯" : "🔊"
    print("\(indicator) [\(deviceID)] \(name)")
}

if devices.isEmpty {
    print("Nenhum dispositivo encontrado")
}

print()

// Menu de opções
print("Opções disponíveis:")
print("1. Testar funcionalidade de passthrough")
print("2. Apenas listar dispositivos (padrão)")
print()

if CommandLine.arguments.contains("--test-passthrough") || CommandLine.arguments.contains("-t") {
    print("🧪 Executando testes de passthrough...\n")
    let tester = PassthroughTester()
    tester.runPassthroughTests()
} else {
    print("💡 Para testar passthrough: swift run MRTDriverControl --test-passthrough")
    print("💡 Ou use o script dedicado: ./Scripts/test_passthrough.sh")
}

print()
print("Para reinstalar o Core Audio: sudo killall -9 coreaudiod")
