#!/bin/bash

# =============================================================================
# Diagnóstico do Estado Atual do Driver
# =============================================================================

echo "🔍 DIAGNÓSTICO DO ESTADO DO DRIVER"
echo "=================================="

echo ""
echo "📋 1. DRIVER INSTALADO?"
echo "----------------------"

if [ -d "/Library/Audio/Plug-Ins/HAL/MRTAudioDriver.driver" ]; then
    echo "✅ Driver encontrado em /Library/Audio/Plug-Ins/HAL/"
    ls -la /Library/Audio/Plug-Ins/HAL/MRTAudioDriver.driver/Contents/MacOS/
    echo ""
    echo "🔍 Verificando arquivo principal:"
    file /Library/Audio/Plug-Ins/HAL/MRTAudioDriver.driver/Contents/MacOS/MRTAudioDriver
else
    echo "❌ Driver NÃO encontrado"
    exit 1
fi

echo ""
echo "📋 2. ESTADO DO COREAUDIOD"
echo "-------------------------"

echo "🔄 Processo coreaudiod:"
ps aux | grep coreaudiod | grep -v grep

echo ""
echo "📋 3. DISPOSITIVOS DE ÁUDIO DETECTADOS"
echo "--------------------------------------"

# Script Swift para testar detecção
cat > /tmp/audio_devices_test.swift << 'EOF'
import CoreAudio
import Foundation

func testAudioDevices() {
    var propsize: UInt32 = 0
    var address = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDevices,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain)
    
    var result = AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &propsize)
    guard result == noErr else { 
        print("❌ Erro ao obter tamanho da propriedade: \(result)")
        return 
    }
    
    let deviceCount = Int(propsize) / MemoryLayout<AudioDeviceID>.size
    let devices = UnsafeMutablePointer<AudioDeviceID>.allocate(capacity: deviceCount)
    defer { devices.deallocate() }
    
    result = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &propsize, devices)
    guard result == noErr else { 
        print("❌ Erro ao obter dados de dispositivos: \(result)")
        return 
    }
    
    print("🎵 Total de dispositivos: \(deviceCount)")
    
    for i in 0..<deviceCount {
        let deviceID = devices[i]
        
        // Obter nome do dispositivo
        var nameAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceNameCFString,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        
        var nameSize: UInt32 = UInt32(MemoryLayout<CFString>.size)
        var deviceName: CFString = "" as CFString
        
        let nameResult = AudioObjectGetPropertyData(deviceID, &nameAddress, 0, nil, &nameSize, &deviceName)
        
        if nameResult == noErr {
            let name = deviceName as String
            let marker = name.contains("MRT") ? "🎯" : "  "
            print("\(marker) [\(deviceID)] \(name)")
            
            // Se for MRTAudio, teste propriedades adicionais
            if name.contains("MRT") {
                print("     └─ 🔍 Analisando MRTAudio...")
                
                // Verificar streams de entrada
                var inputStreamAddress = AudioObjectPropertyAddress(
                    mSelector: kAudioDevicePropertyStreams,
                    mScope: kAudioDevicePropertyScopeInput,
                    mElement: kAudioObjectPropertyElementMain)
                
                var inputStreamSize: UInt32 = 0
                let inputResult = AudioObjectGetPropertyDataSize(deviceID, &inputStreamAddress, 0, nil, &inputStreamSize)
                let inputStreamCount = inputResult == noErr ? inputStreamSize / UInt32(MemoryLayout<AudioStreamID>.size) : 0
                
                // Verificar streams de saída
                var outputStreamAddress = AudioObjectPropertyAddress(
                    mSelector: kAudioDevicePropertyStreams,
                    mScope: kAudioDevicePropertyScopeOutput,
                    mElement: kAudioObjectPropertyElementMain)
                
                var outputStreamSize: UInt32 = 0
                let outputResult = AudioObjectGetPropertyDataSize(deviceID, &outputStreamAddress, 0, nil, &outputStreamSize)
                let outputStreamCount = outputResult == noErr ? outputStreamSize / UInt32(MemoryLayout<AudioStreamID>.size) : 0
                
                print("     └─ Streams: \(inputStreamCount) entrada, \(outputStreamCount) saída")
                
                // Verificar se é dispositivo padrão
                var defaultAddress = AudioObjectPropertyAddress(
                    mSelector: kAudioHardwarePropertyDefaultOutputDevice,
                    mScope: kAudioObjectPropertyScopeGlobal,
                    mElement: kAudioObjectPropertyElementMain)
                
                var defaultSize: UInt32 = UInt32(MemoryLayout<AudioDeviceID>.size)
                var defaultDevice: AudioDeviceID = 0
                
                let defaultResult = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &defaultAddress, 0, nil, &defaultSize, &defaultDevice)
                
                if defaultResult == noErr && defaultDevice == deviceID {
                    print("     └─ ✅ É o dispositivo de saída PADRÃO")
                } else {
                    print("     └─ ℹ️  NÃO é o dispositivo de saída padrão (padrão: \(defaultDevice))")
                }
            }
        }
    }
}

testAudioDevices()
EOF

swift /tmp/audio_devices_test.swift

echo ""
echo "📋 4. TESTE DE FUNCIONAMENTO"
echo "----------------------------"

echo "🎯 O MRTAudio está configurado como dispositivo padrão?"
echo "   Vá em Preferências do Sistema → Som → Saída"
echo "   e verifique se 'MRTAudio 2ch' está selecionado"

echo ""
echo "📋 5. LOGS DO SISTEMA"
echo "--------------------"

echo "🔍 Logs recentes relacionados ao áudio:"
log show --last 5m --predicate 'subsystem == "com.apple.audio"' --style compact | tail -10

echo ""
echo "📋 6. RECOMENDAÇÕES DE TESTE"
echo "----------------------------"

echo "💡 Para testar o passthrough:"
echo "1. Configure MRTAudio 2ch como saída nas Preferências do Sistema"
echo "2. Abra um player de música (ex: Spotify, Music)"  
echo "3. Toque uma música"
echo "4. Verifique se há áudio"

echo ""
echo "🔧 Se não houver áudio:"
echo "1. Verifique se MRTAudio está realmente selecionado"
echo "2. Reinicie o coreaudiod: sudo killall coreaudiod"
echo "3. Tente novamente"

echo ""
echo "📄 Logs de debug do driver estarão em:"
echo "   Console.app → Filtro: 'MRT' ou 'BlackHole'"

rm -f /tmp/audio_devices_test.swift