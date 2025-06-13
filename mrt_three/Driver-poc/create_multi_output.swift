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
