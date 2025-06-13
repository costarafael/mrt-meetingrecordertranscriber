#!/bin/bash

# =============================================================================
# DIAGNÓSTICO DETALHADO DO STATUS DO DRIVER
# =============================================================================

echo "🔍 DIAGNÓSTICO COMPLETO DO DRIVER MRT"
echo "====================================="

# Verificar se o driver está instalado
echo ""
echo "📦 1. VERIFICANDO INSTALAÇÃO:"
echo "----------------------------"

INSTALL_PATH="/Library/Audio/Plug-Ins/HAL/MRTAudioDriver.driver"
if [ -d "$INSTALL_PATH" ]; then
    echo "✅ Driver instalado em: $INSTALL_PATH"
    
    # Verificar permissões
    echo "🔑 Permissões:"
    ls -la "$INSTALL_PATH/"
    
    # Verificar se o binário existe
    BINARY_PATH="$INSTALL_PATH/Contents/MacOS/MRTAudioDriver"
    if [ -f "$BINARY_PATH" ]; then
        echo "✅ Binário encontrado: $BINARY_PATH"
        
        # Verificar arquitetura
        echo "🏗️  Arquitetura:"
        file "$BINARY_PATH"
        
        # Verificar assinatura
        echo "📝 Assinatura:"
        codesign -dv "$BINARY_PATH" 2>&1 | head -5
    else
        echo "❌ Binário não encontrado!"
    fi
    
else
    echo "❌ Driver NÃO instalado!"
    exit 1
fi

echo ""
echo "🎛️  2. VERIFICANDO STATUS NO SISTEMA:"
echo "------------------------------------"

# Verificar se o driver está carregado
echo "📊 Dispositivos de áudio detectados:"
system_profiler SPAudioDataType | grep -A 10 -B 2 "MRT"

echo ""
echo "🔊 Status do Core Audio:"
# Listar todos os dispositivos
echo "Todos os dispositivos:"
ioreg -l | grep -E "(IOAudioDevice|name.*Audio)" | head -10

echo ""
echo "🎯 3. TESTANDO COMUNICAÇÃO COM DRIVER:"
echo "-------------------------------------"

# Compilar e executar teste rápido
cat > /tmp/quick_driver_test.swift << 'EOF'
import CoreAudio
import Foundation

func testDriverCommunication() {
    print("🔍 Buscando driver MRTAudio...")
    
    var propsize: UInt32 = 0
    var address = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDevices,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain)
    
    guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &propsize) == noErr else {
        print("❌ Erro ao obter tamanho da propriedade")
        return
    }
    
    let deviceCount = Int(propsize) / MemoryLayout<AudioDeviceID>.size
    let devices = UnsafeMutablePointer<AudioDeviceID>.allocate(capacity: deviceCount)
    defer { devices.deallocate() }
    
    guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &propsize, devices) == noErr else {
        print("❌ Erro ao obter dispositivos")
        return
    }
    
    print("📊 Encontrados \(deviceCount) dispositivos de áudio")
    
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
            print("🎵 [\(deviceID)] \(name)")
            
            if name.contains("MRT") {
                print("  🎯 DRIVER MRT ENCONTRADO!")
                
                // Verificar propriedades específicas
                var isAlive: UInt32 = 0
                var aliveAddress = AudioObjectPropertyAddress(
                    mSelector: kAudioDevicePropertyDeviceIsAlive,
                    mScope: kAudioObjectPropertyScopeGlobal,
                    mElement: kAudioObjectPropertyElementMain)
                var aliveSize = UInt32(MemoryLayout<UInt32>.size)
                
                if AudioObjectGetPropertyData(deviceID, &aliveAddress, 0, nil, &aliveSize, &isAlive) == noErr {
                    print("  ✅ Driver está vivo: \(isAlive == 1 ? "SIM" : "NÃO")")
                }
                
                // Verificar se está rodando
                var isRunning: UInt32 = 0
                var runningAddress = AudioObjectPropertyAddress(
                    mSelector: kAudioDevicePropertyDeviceIsRunning,
                    mScope: kAudioObjectPropertyScopeGlobal,
                    mElement: kAudioObjectPropertyElementMain)
                var runningSize = UInt32(MemoryLayout<UInt32>.size)
                
                if AudioObjectGetPropertyData(deviceID, &runningAddress, 0, nil, &runningSize, &isRunning) == noErr {
                    print("  ✅ Driver está rodando: \(isRunning == 1 ? "SIM" : "NÃO")")
                }
                
                // Verificar formato de stream
                var streamAddress = AudioObjectPropertyAddress(
                    mSelector: kAudioDevicePropertyStreamFormat,
                    mScope: kAudioObjectPropertyScopeOutput,
                    mElement: kAudioObjectPropertyElementMain)
                var streamSize = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
                var streamFormat = AudioStreamBasicDescription()
                
                if AudioObjectGetPropertyData(deviceID, &streamAddress, 0, nil, &streamSize, &streamFormat) == noErr {
                    print("  📊 Taxa de amostragem: \(streamFormat.mSampleRate) Hz")
                    print("  📊 Canais: \(streamFormat.mChannelsPerFrame)")
                    print("  📊 Formato: \(streamFormat.mFormatID == kAudioFormatLinearPCM ? "Linear PCM" : "Outro")")
                }
            }
        }
    }
}

testDriverCommunication()
EOF

echo "🧪 Executando teste de comunicação:"
swift /tmp/quick_driver_test.swift

echo ""
echo "🚨 4. VERIFICANDO LOGS DE ERRO:"
echo "------------------------------"

# Buscar logs recentes relacionados ao driver
echo "📋 Logs recentes do sistema (últimos 2 minutos):"
log show --predicate 'eventMessage contains "MRT" || eventMessage contains "AudioServerPlugIn"' --last 2m --style syslog 2>/dev/null | head -10

echo ""
echo "🔧 5. VERIFICANDO CONFIGURAÇÃO ATUAL:"
echo "------------------------------------"

# Verificar dispositivo de saída atual
echo "🎯 Dispositivo de saída atual do sistema:"
defaults read com.apple.systempreferences com.apple.preference.sound 2>/dev/null || echo "Não foi possível verificar"

# Verificar se há Multi-Output Device
echo ""
echo "📱 Verificando Multi-Output Devices:"
system_profiler SPAudioDataType | grep -i "multi"

echo ""
echo "✅ DIAGNÓSTICO COMPLETO!"
echo "======================="
echo ""
echo "💡 PRÓXIMOS PASSOS:"
echo "1. Se o driver está vivo mas não funciona: problema na implementação de passthrough"
echo "2. Se o driver não está vivo: problema de instalação ou código"
echo "3. Se não foi encontrado: problema de instalação"

rm -f /tmp/quick_driver_test.swift