#!/bin/bash

# =============================================================================
# FORÇA INICIALIZAÇÃO DO DRIVER MRT
# Problema identificado: Driver está vivo mas não está rodando
# =============================================================================

echo "🚀 FORÇANDO INICIALIZAÇÃO DO DRIVER MRT"
echo "======================================="

# Criar aplicação Swift para inicializar o driver
cat > /tmp/force_driver_start.swift << 'EOF'
import CoreAudio
import Foundation

func forceDriverStart() {
    print("🔍 Procurando driver MRTAudio...")
    
    // Encontrar nosso driver
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
                print("✅ Driver MRT encontrado: [\(deviceID)] \(name)")
                mrtDeviceID = deviceID
                break
            }
        }
    }
    
    guard mrtDeviceID != kAudioObjectUnknown else {
        print("❌ Driver MRT não encontrado!")
        return
    }
    
    // Verificar status atual
    var isRunning: UInt32 = 0
    var runningAddress = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyDeviceIsRunning,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain)
    var runningSize = UInt32(MemoryLayout<UInt32>.size)
    
    if AudioObjectGetPropertyData(mrtDeviceID, &runningAddress, 0, nil, &runningSize, &isRunning) == noErr {
        print("📊 Status atual: \(isRunning == 1 ? "RODANDO" : "PARADO")")
    }
    
    if isRunning == 0 {
        print("🚀 Tentando inicializar o driver...")
        
        // MÉTODO 1: Configurar como dispositivo padrão
        print("🎯 Método 1: Configurando como dispositivo padrão...")
        var defaultAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        
        let status1 = AudioObjectSetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &defaultAddress, 0, nil,
            UInt32(MemoryLayout<AudioDeviceID>.size), &mrtDeviceID)
        
        if status1 == noErr {
            print("✅ Configurado como dispositivo padrão")
        } else {
            print("❌ Erro ao configurar como padrão: \(status1)")
        }
        
        // Aguardar um pouco
        Thread.sleep(forTimeInterval: 1.0)
        
        // MÉTODO 2: Tentar forçar inicio manualmente
        print("🎯 Método 2: Forçando início manual...")
        var startRunning: UInt32 = 1
        let status2 = AudioObjectSetPropertyData(
            mrtDeviceID,
            &runningAddress, 0, nil,
            UInt32(MemoryLayout<UInt32>.size), &startRunning)
        
        if status2 == noErr {
            print("✅ Comando de início enviado")
        } else {
            print("❌ Erro ao enviar comando de início: \(status2)")
        }
        
        // Aguardar um pouco
        Thread.sleep(forTimeInterval: 1.0)
        
        // MÉTODO 3: Simular uso do dispositivo criando um AudioQueue
        print("🎯 Método 3: Simulando uso do dispositivo...")
        
        var format = AudioStreamBasicDescription()
        format.mSampleRate = 48000.0
        format.mFormatID = kAudioFormatLinearPCM
        format.mFormatFlags = kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked
        format.mBytesPerPacket = MemoryLayout<Float32>.size * 2
        format.mFramesPerPacket = 1
        format.mBytesPerFrame = MemoryLayout<Float32>.size * 2
        format.mChannelsPerFrame = 2
        format.mBitsPerChannel = 32
        
        var audioQueue: AudioQueueRef?
        let status3 = AudioQueueNewOutput(&format, nil, nil, nil, kCFRunLoopCommonModes, 0, &audioQueue)
        
        if status3 == noErr && audioQueue != nil {
            print("✅ AudioQueue criado")
            
            // Tentar especificar nosso device
            var deviceProperty = mrtDeviceID
            let status4 = AudioQueueSetProperty(audioQueue!, kAudioQueueProperty_CurrentDevice, &deviceProperty, UInt32(MemoryLayout<AudioDeviceID>.size))
            
            if status4 == noErr {
                print("✅ AudioQueue configurado para nosso device")
                
                // Iniciar o AudioQueue
                let status5 = AudioQueueStart(audioQueue!, nil)
                if status5 == noErr {
                    print("✅ AudioQueue iniciado")
                    
                    // Aguardar para forçar inicialização
                    Thread.sleep(forTimeInterval: 2.0)
                    
                    AudioQueueStop(audioQueue!, true)
                    print("✅ AudioQueue parado")
                } else {
                    print("❌ Erro ao iniciar AudioQueue: \(status5)")
                }
            } else {
                print("❌ Erro ao configurar device no AudioQueue: \(status4)")
            }
            
            AudioQueueDispose(audioQueue!, true)
        } else {
            print("❌ Erro ao criar AudioQueue: \(status3)")
        }
        
        // Verificar status final
        Thread.sleep(forTimeInterval: 1.0)
        
        isRunning = 0
        if AudioObjectGetPropertyData(mrtDeviceID, &runningAddress, 0, nil, &runningSize, &isRunning) == noErr {
            print("📊 Status final: \(isRunning == 1 ? "RODANDO ✅" : "AINDA PARADO ❌")")
        }
    } else {
        print("✅ Driver já está rodando!")
    }
}

forceDriverStart()
EOF

echo "🧪 Executando tentativa de inicialização..."
swift /tmp/force_driver_start.swift

echo ""
echo "🔍 Verificando resultado..."

# Testar novamente o status
swift -c "
import CoreAudio
import Foundation

var propsize: UInt32 = 0
var address = AudioObjectPropertyAddress(
    mSelector: kAudioHardwarePropertyDevices,
    mScope: kAudioObjectPropertyScopeGlobal,
    mElement: kAudioObjectPropertyElementMain)

if AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &propsize) == noErr {
    let deviceCount = Int(propsize) / MemoryLayout<AudioDeviceID>.size
    let devices = UnsafeMutablePointer<AudioDeviceID>.allocate(capacity: deviceCount)
    defer { devices.deallocate() }
    
    if AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &propsize, devices) == noErr {
        for i in 0..<deviceCount {
            let deviceID = devices[i]
            
            var nameAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyDeviceNameCFString,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain)
            
            var nameSize: UInt32 = UInt32(MemoryLayout<CFString>.size)
            var deviceName: CFString = \"\" as CFString
            
            if AudioObjectGetPropertyData(deviceID, &nameAddress, 0, nil, &nameSize, &deviceName) == noErr {
                let name = deviceName as String
                if name.contains(\"MRT\") {
                    var isRunning: UInt32 = 0
                    var runningAddress = AudioObjectPropertyAddress(
                        mSelector: kAudioDevicePropertyDeviceIsRunning,
                        mScope: kAudioObjectPropertyScopeGlobal,
                        mElement: kAudioObjectPropertyElementMain)
                    var runningSize = UInt32(MemoryLayout<UInt32>.size)
                    
                    if AudioObjectGetPropertyData(deviceID, &runningAddress, 0, nil, &runningSize, &isRunning) == noErr {
                        print(\"🎯 MRTAudio [\(deviceID)]: \(isRunning == 1 ? \"RODANDO ✅\" : \"PARADO ❌\")\")
                    }
                    break
                }
            }
        }
    }
}
"

echo ""
echo "💡 PRÓXIMOS PASSOS:"
echo "1. Se ainda estiver parado, há problema na implementação do driver"
echo "2. Se estiver rodando, teste reproduzir áudio"
echo "3. Verifique se MRTAudio está como saída padrão nas preferências"

rm -f /tmp/force_driver_start.swift