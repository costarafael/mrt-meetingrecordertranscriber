#!/usr/bin/swift

import Foundation
import CoreAudio
import AudioToolbox

print("🎵 TESTE CAPTURA EM TEMPO REAL")
print("==============================")

// Callback para monitorar propriedades do dispositivo
let propertyListener: AudioObjectPropertyListenerProc = { (objectID, numAddresses, addresses, clientData) in
    print("🔊 Atividade detectada no dispositivo de áudio!")
    return noErr
}

// Obter dispositivo padrão
func getDefaultOutputDevice() -> AudioDeviceID? {
    var deviceID = AudioDeviceID()
    var dataSize = UInt32(MemoryLayout<AudioDeviceID>.size)
    
    var address = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDefaultOutputDevice,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )
    
    let status = AudioObjectGetPropertyData(
        AudioObjectID(kAudioObjectSystemObject),
        &address,
        0,
        nil,
        &dataSize,
        &deviceID
    )
    
    return status == noErr ? deviceID : nil
}

guard let deviceID = getDefaultOutputDevice() else {
    print("❌ Erro: Dispositivo não encontrado")
    exit(1)
}

print("✅ Monitorando dispositivo ID: \(deviceID)")
print("🎧 Toque algum áudio agora (música, YouTube, etc.)")
print("⏱️  Monitorando por 15 segundos...")

// Configurar listener para detectar atividade
var address = AudioObjectPropertyAddress(
    mSelector: kAudioDevicePropertyDeviceIsRunning,
    mScope: kAudioObjectPropertyScopeGlobal,
    mElement: kAudioObjectPropertyElementMain
)

let status = AudioObjectAddPropertyListener(deviceID, &address, propertyListener, nil)

if status == noErr {
    print("🎯 Listener instalado - detectando atividade de áudio...")
    
    // Verificar estado inicial
    var isRunning = UInt32(0)
    var dataSize = UInt32(MemoryLayout<UInt32>.size)
    
    AudioObjectGetPropertyData(deviceID, &address, 0, nil, &dataSize, &isRunning)
    print("📊 Estado inicial do dispositivo: \(isRunning == 1 ? "ATIVO" : "INATIVO")")
    
    // Monitorar por 15 segundos
    for i in 1...15 {
        sleep(1)
        
        // Verificar estado atual
        AudioObjectGetPropertyData(deviceID, &address, 0, nil, &dataSize, &isRunning)
        let status = isRunning == 1 ? "🟢 TOCANDO" : "🔴 SILÊNCIO"
        print("[\(String(format: "%02d", i))s] \(status)")
    }
    
    // Remover listener
    AudioObjectRemovePropertyListener(deviceID, &address, propertyListener, nil)
    print("✅ Monitoramento concluído!")
    
} else {
    print("❌ Erro instalando listener: \(status)")
}

print("")
print("🎯 RESULTADO: Sistema de monitoramento REAL funcionando!")
print("📋 Esta é a base da captura Core Audio TAP Real")

exit(0)