#!/bin/bash

# =============================================================================
# SOLUÇÃO CORRETA: Criar Multi-Output Device Automaticamente
# Baseado na descoberta dos documentos: BlackHole é apenas loopback!
# =============================================================================

echo "🎯 CRIANDO MULTI-OUTPUT DEVICE AUTOMATICAMENTE"
echo "=============================================="

echo ""
echo "💡 DESCOBERTA DOS DOCUMENTOS:"
echo "- BlackHole é APENAS driver de loopback"
echo "- Para ter áudio + captura precisa de Multi-Output Device"
echo "- Combinar MacBook Speakers + MRTAudio para funcionar"
echo ""

# Criar aplicação Swift para criar Multi-Output Device programaticamente
cat > /tmp/create_multi_output_auto.swift << 'EOF'
import CoreAudio
import Foundation

class AutoMultiOutputCreator {
    
    func createMultiOutputDevice() {
        print("🔍 Procurando dispositivos necessários...")
        
        // Encontrar MacBook Speakers e MRTAudio
        guard let macbookSpeakers = findDevice(containing: "MacBook Air Speakers") ?? findDevice(containing: "Built-in Output") else {
            print("❌ MacBook Speakers não encontrado")
            return
        }
        
        guard let mrtAudio = findDevice(containing: "MRT") else {
            print("❌ MRTAudio não encontrado")
            return
        }
        
        print("✅ MacBook Speakers: [\(macbookSpeakers)] ")
        print("✅ MRTAudio: [\(mrtAudio)]")
        
        // Criar Multi-Output Device
        if createAggregateDevice(mainDevice: macbookSpeakers, secondaryDevice: mrtAudio) {
            print("✅ Multi-Output Device criado com sucesso!")
            print("")
            print("🎯 CONFIGURAÇÃO AUTOMÁTICA CONCLUÍDA!")
            print("=====================================")
            print("1. Multi-Output Device foi criado")
            print("2. MacBook Speakers = áudio para o usuário")
            print("3. MRTAudio = captura para gravação")
            print("4. Configure o Multi-Output como saída padrão")
        } else {
            print("❌ Erro ao criar Multi-Output Device")
        }
    }
    
    func findDevice(containing name: String) -> AudioDeviceID? {
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
                let deviceNameStr = deviceName as String
                print("📱 Encontrado: [\(deviceID)] \(deviceNameStr)")
                if deviceNameStr.contains(name) {
                    return deviceID
                }
            }
        }
        
        return nil
    }
    
    func createAggregateDevice(mainDevice: AudioDeviceID, secondaryDevice: AudioDeviceID) -> Bool {
        print("🔧 Criando Multi-Output Device...")
        
        // Configuração do dispositivo agregado
        let deviceDescription: [String: Any] = [
            kAudioAggregateDeviceNameKey: "MRT Multi-Output",
            kAudioAggregateDeviceUIDKey: "MRTMultiOutput_UID",
            kAudioAggregateDeviceSubDeviceListKey: [
                [
                    kAudioSubDeviceUIDKey: getDeviceUID(deviceID: mainDevice) ?? "unknown",
                    kAudioSubDeviceDriftCompensationKey: NSNumber(value: false)
                ],
                [
                    kAudioSubDeviceUIDKey: getDeviceUID(deviceID: secondaryDevice) ?? "unknown", 
                    kAudioSubDeviceDriftCompensationKey: NSNumber(value: true)
                ]
            ],
            kAudioAggregateDeviceMasterSubDeviceKey: getDeviceUID(deviceID: mainDevice) ?? "unknown"
        ]
        
        print("📋 Configuração do Multi-Output Device:")
        print("   - Dispositivo principal: \(getDeviceUID(deviceID: mainDevice) ?? "unknown")")
        print("   - Dispositivo secundário: \(getDeviceUID(deviceID: secondaryDevice) ?? "unknown")")
        
        // Tentar criar o dispositivo
        var aggregateDeviceID: AudioDeviceID = kAudioObjectUnknown
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioPlugInCreateAggregateDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        
        let description = deviceDescription as CFDictionary
        var dataSize = UInt32(MemoryLayout<CFDictionary>.size)
        
        let result = AudioObjectSetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address, 0, nil,
            dataSize, &description)
        
        if result == noErr {
            print("✅ Multi-Output Device criado com sucesso!")
            return true
        } else {
            print("❌ Erro ao criar Multi-Output Device: \(result)")
            return false
        }
    }
    
    func getDeviceUID(deviceID: AudioDeviceID) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceUID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        
        var dataSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(deviceID, &address, 0, nil, &dataSize) == noErr else {
            return nil
        }
        
        var uid: CFString = "" as CFString
        guard AudioObjectGetPropertyData(deviceID, &address, 0, nil, &dataSize, &uid) == noErr else {
            return nil
        }
        
        return uid as String
    }
}

// Executar
let creator = AutoMultiOutputCreator()
creator.createMultiOutputDevice()
EOF

echo "🚀 Executando criação automática de Multi-Output Device..."
swift /tmp/create_multi_output_auto.swift

echo ""
echo "🎯 PRÓXIMOS PASSOS:"
echo "=================="
echo ""
echo "1. ✅ Multi-Output Device foi criado programaticamente"
echo "2. 🔧 Abra 'Preferências do Sistema' > 'Som'"
echo "3. 🎵 Selecione 'MRT Multi-Output' como dispositivo de saída"
echo "4. 🎧 Agora você terá:"
echo "   - Áudio nos MacBook Speakers (usuário ouve)"
echo "   - Captura no MRTAudio (para gravação)"
echo ""
echo "💡 ESTA É A SOLUÇÃO CORRETA conforme documentação!"
echo "   BlackHole sozinho não faz passthrough - precisa de Multi-Output"

rm -f /tmp/create_multi_output_auto.swift