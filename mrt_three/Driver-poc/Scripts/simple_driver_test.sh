#!/bin/bash

# =============================================================================
# TESTE SIMPLES: Verificar e tentar forçar driver a rodar
# =============================================================================

echo "🚀 TESTE SIMPLES DE INICIALIZAÇÃO DO DRIVER"
echo "==========================================="

# Criar script Swift simplificado
cat > /tmp/simple_test.swift << 'EOF'
import CoreAudio
import Foundation

func simpleDriverTest() {
    print("🔍 Verificando driver MRTAudio...")
    
    // Encontrar nosso driver
    var propsize: UInt32 = 0
    var address = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDevices,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain)
    
    guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &propsize) == noErr else {
        print("❌ Erro ao obter dispositivos")
        return
    }
    
    let deviceCount = Int(propsize) / MemoryLayout<AudioDeviceID>.size
    let devices = UnsafeMutablePointer<AudioDeviceID>.allocate(capacity: deviceCount)
    defer { devices.deallocate() }
    
    guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &propsize, devices) == noErr else {
        print("❌ Erro ao ler dispositivos")
        return
    }
    
    var mrtDeviceID: AudioDeviceID = kAudioObjectUnknown
    
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
                print("✅ MRTAudio encontrado: [\(deviceID)] \(name)")
                mrtDeviceID = deviceID
                break
            }
        }
    }
    
    guard mrtDeviceID != kAudioObjectUnknown else {
        print("❌ Driver MRT não encontrado!")
        return
    }
    
    // Verificar se está rodando
    var isRunning: UInt32 = 0
    var runningAddress = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyDeviceIsRunning,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain)
    var runningSize = UInt32(MemoryLayout<UInt32>.size)
    
    if AudioObjectGetPropertyData(mrtDeviceID, &runningAddress, 0, nil, &runningSize, &isRunning) == noErr {
        print("📊 Status: \(isRunning == 1 ? "RODANDO ✅" : "PARADO ❌")")
    }
    
    if isRunning == 0 {
        print("🎯 Tentando configurar como dispositivo padrão...")
        
        // Configurar como dispositivo padrão de saída
        var defaultAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        
        let status = AudioObjectSetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &defaultAddress, 0, nil,
            UInt32(MemoryLayout<AudioDeviceID>.size), &mrtDeviceID)
        
        if status == noErr {
            print("✅ Configurado como dispositivo padrão")
            
            // Aguardar um pouco e verificar novamente
            Thread.sleep(forTimeInterval: 2.0)
            
            isRunning = 0
            if AudioObjectGetPropertyData(mrtDeviceID, &runningAddress, 0, nil, &runningSize, &isRunning) == noErr {
                print("📊 Status após configuração: \(isRunning == 1 ? "RODANDO ✅" : "AINDA PARADO ❌")")
            }
        } else {
            print("❌ Erro ao configurar como padrão: \(status)")
        }
    }
    
    // Verificar dispositivo padrão atual
    var currentDefault: AudioDeviceID = kAudioObjectUnknown
    var defaultSize = UInt32(MemoryLayout<AudioDeviceID>.size)
    var defaultAddress = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDefaultOutputDevice,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain)
    
    if AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &defaultAddress, 0, nil, &defaultSize, &currentDefault) == noErr {
        if currentDefault == mrtDeviceID {
            print("✅ MRTAudio é o dispositivo padrão")
        } else {
            print("⚠️  MRTAudio NÃO é o dispositivo padrão (atual: \(currentDefault))")
        }
    }
}

simpleDriverTest()
EOF

echo "🧪 Executando teste..."
swift /tmp/simple_test.swift

echo ""
echo "🔧 Verificando se há problemas no código do driver..."

# Procurar por logs específicos no Console
echo "📋 Buscando logs do driver nos últimos minutos..."
log show --predicate 'eventMessage contains "MRT" OR eventMessage contains "AudioServerPlugIn"' --last 3m --style syslog 2>/dev/null | tail -20

echo ""
echo "💡 ANÁLISE DO PROBLEMA:"
echo "======================"
echo ""
echo "Se o driver ainda não está rodando após ser configurado como padrão,"
echo "isso indica que há um problema na implementação do driver."
echo ""
echo "🔍 POSSÍVEIS CAUSAS:"
echo "1. Erro na função de inicialização (MRT_Initialize)"
echo "2. Erro na função de start (MRT_Start)"
echo "3. Problema nas propriedades do driver"
echo "4. Configuração incorreta no Info.plist"
echo ""
echo "📋 PRÓXIMO PASSO: Analisar código do driver"

rm -f /tmp/simple_test.swift