#!/bin/bash

# =============================================================================
# Implementação da SOLUÇÃO CORRETA: Multi-Output Device Automático
# Baseado na pesquisa: esta é a única forma real de fazer passthrough
# =============================================================================

echo "🎯 IMPLEMENTANDO SOLUÇÃO CORRETA: MULTI-OUTPUT DEVICE"
echo "====================================================="

echo ""
echo "💡 DESCOBERTA IMPORTANTE da pesquisa:"
echo "- BlackHole NUNCA foi projetado para passthrough direto"
echo "- Solução padrão é Multi-Output Device MANUAL"
echo "- Drivers virtuais não podem enviar para dispositivos físicos via código"
echo ""
echo "🔧 SOLUÇÃO: Criar Multi-Output Device automaticamente"

# Criar script que cria Multi-Output Device automaticamente
cat > /tmp/create_multi_output.scpt << 'EOF'
tell application "Audio MIDI Setup"
    activate
    
    -- Espera a aplicação abrir
    delay 1
    
    -- Tentar criar Multi-Output Device via AppleScript
    -- (Isso pode não funcionar em todas as versões do macOS)
    
end tell

-- Alternativa: usar SoX ou comandos de terminal
do shell script "echo 'Multi-Output Device creation attempted'"
EOF

echo "📋 Criando utilitário para Multi-Output Device..."

# Criar aplicação Swift para criar Multi-Output Device programaticamente
cat > /Users/rafaelaredes/Documents/mrt_macos/mrt_three/Driver-poc/create_multi_output.swift << 'EOF'
import CoreAudio
import Foundation

class MultiOutputCreator {
    
    func createMultiOutputDevice() -> AudioDeviceID? {
        // NOTA: Criar Multi-Output Device programaticamente é extremamente complexo
        // A Apple não fornece APIs públicas simples para isso
        
        // Método 1: Tentar usar AudioObjectCreate (pode não funcionar)
        var deviceID: AudioDeviceID = kAudioObjectUnknown
        
        // Configuração do Multi-Output Device
        var deviceInfo = AudioObjectPropertyAddress(
            mSelector: kAudioPlugInCreateAggregateDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        // Este método geralmente falha para aplicações normais
        // porque requer privilégios especiais
        
        print("⚠️  Criar Multi-Output Device programaticamente é muito complexo")
        print("💡 Recomendação: Usar abordagem manual ou solicitar ao usuário")
        
        return nil
    }
    
    func findMRTAudioDevice() -> AudioDeviceID? {
        var propsize: UInt32 = 0
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        
        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &propsize) == noErr else {
            return nil
        }
        
        let deviceCount = Int(propsize) / MemoryLayout<AudioDeviceID>.size
        let devices = UnsafeMutablePointer<AudioDeviceID>.allocate(capacity: deviceCount)
        defer { devices.deallocate() }
        
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &propsize, devices) == noErr else {
            return nil
        }
        
        for i in 0..<deviceCount {
            let deviceID = devices[i]
            
            var nameAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyDeviceNameCFString,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain)
            
            var nameSize: UInt32 = UInt32(MemoryLayout<CFString>.size)
            var deviceName: CFString = "" as CFString
            
            if AudioObjectGetPropertyData(deviceID, &nameAddress, 0, nil, &nameSize, &deviceName) == noErr {
                let name = deviceName as String
                if name.contains("MRT") {
                    print("🎯 MRTAudio encontrado: [\(deviceID)] \(name)")
                    return deviceID
                }
            }
        }
        
        return nil
    }
    
    func checkExistingMultiOutput() -> AudioDeviceID? {
        // Verifica se já existe um Multi-Output Device configurado
        // que inclui MRTAudio
        
        var propsize: UInt32 = 0
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        
        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &propsize) == noErr else {
            return nil
        }
        
        let deviceCount = Int(propsize) / MemoryLayout<AudioDeviceID>.size
        let devices = UnsafeMutablePointer<AudioDeviceID>.allocate(capacity: deviceCount)
        defer { devices.deallocate() }
        
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &propsize, devices) == noErr else {
            return nil
        }
        
        for i in 0..<deviceCount {
            let deviceID = devices[i]
            
            var nameAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyDeviceNameCFString,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain)
            
            var nameSize: UInt32 = UInt32(MemoryLayout<CFString>.size)
            var deviceName: CFString = "" as CFString
            
            if AudioObjectGetPropertyData(deviceID, &nameAddress, 0, nil, &nameSize, &deviceName) == noErr {
                let name = deviceName as String
                if name.contains("Multi-Output") {
                    print("📱 Multi-Output encontrado: [\(deviceID)] \(name)")
                    return deviceID
                }
            }
        }
        
        return nil
    }
}

// Executar análise
let creator = MultiOutputCreator()

print("🔍 ANÁLISE DO SISTEMA DE ÁUDIO")
print("==============================")

if let mrtDevice = creator.findMRTAudioDevice() {
    print("✅ MRTAudio encontrado: \(mrtDevice)")
} else {
    print("❌ MRTAudio não encontrado")
}

if let multiDevice = creator.checkExistingMultiOutput() {
    print("✅ Multi-Output existente: \(multiDevice)")
    print("💡 Você pode configurar este Multi-Output manualmente")
} else {
    print("ℹ️  Nenhum Multi-Output encontrado")
}

print("\n🛠️  SOLUÇÕES DISPONÍVEIS:")
print("1. Manual: Audio MIDI Setup → Criar Multi-Output Device")
print("2. Script automático (limitado)")
print("3. Solicitar permissões especiais (complexo)")
EOF

echo "🚀 Executando análise do sistema..."
swift /Users/rafaelaredes/Documents/mrt_macos/mrt_three/Driver-poc/create_multi_output.swift

echo ""
echo "🎯 PRÓXIMOS PASSOS RECOMENDADOS:"
echo "================================"
echo ""
echo "📋 SOLUÇÃO 1: Manual (mais confiável)"
echo "1. Abrir Audio MIDI Setup"
echo "2. Clique no '+' → Criar Multi-Output Device"  
echo "3. Adicionar 'MacBook Air Speakers' e 'MRTAudio 2ch'"
echo "4. Configurar como dispositivo padrão"
echo ""
echo "📋 SOLUÇÃO 2: Script automático (experimental)"
echo "Vou criar um script que tenta automatizar isso..."

# Criar script de automação via osascript
cat > /Users/rafaelaredes/Documents/mrt_macos/mrt_three/Driver-poc/Scripts/setup_multi_output.sh << 'EOF'
#!/bin/bash

echo "🔧 Configurando Multi-Output Device automaticamente..."

# Tentar abrir Audio MIDI Setup
osascript << 'APPLESCRIPT'
tell application "Audio MIDI Setup"
    activate
    delay 2
end tell

tell application "System Events"
    tell process "Audio MIDI Setup"
        -- Tentar clicar no botão +
        try
            click button "+" of window 1
            delay 1
            
            -- Procurar opção "Create Multi-Output Device"
            click menu item "Create Multi-Output Device" of menu 1 of button "+" of window 1
            delay 1
            
            display dialog "Multi-Output Device criado! Configure manualmente adicionando MacBook Air Speakers e MRTAudio 2ch"
        on error
            display dialog "Não foi possível criar automaticamente. Abra Audio MIDI Setup e crie manualmente."
        end try
    end tell
end tell
APPLESCRIPT

echo "✅ Tentativa de criação automática concluída"
echo "Se não funcionou, crie manualmente no Audio MIDI Setup"
EOF

chmod +x /Users/rafaelaredes/Documents/mrt_macos/mrt_three/Driver-poc/Scripts/setup_multi_output.sh

echo ""
echo "✅ UTILITÁRIOS CRIADOS:"
echo "- create_multi_output.swift (análise)"
echo "- Scripts/setup_multi_output.sh (automação)"
echo ""
echo "🎯 TESTE AGORA:"
echo "bash Scripts/setup_multi_output.sh"

rm -f /tmp/create_multi_output.scpt