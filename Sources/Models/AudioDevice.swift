import Foundation
import CoreAudio

struct AudioDevice: Identifiable, Hashable {
    let id: AudioDeviceID
    let deviceID: AudioDeviceID
    let name: String
    let hasInputStreams: Bool
    let hasOutputStreams: Bool
    
    init?(deviceID: AudioDeviceID) {
        self.id = deviceID
        self.deviceID = deviceID
        
        // Obter nome do dispositivo
        var size: UInt32 = 0
        var namePropertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceNameCFString,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        AudioObjectGetPropertyDataSize(deviceID, &namePropertyAddress, 0, nil, &size)
        var deviceName: CFString?
        let status = withUnsafeMutablePointer(to: &deviceName) { pointer in
            AudioObjectGetPropertyData(deviceID, &namePropertyAddress, 0, nil, &size, pointer)
        }
        
        guard status == noErr, let name = deviceName as String? else {
            return nil
        }
        
        self.name = name
        
        // Verificar se tem streams de entrada
        var inputStreamsPropertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreams,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        
        AudioObjectGetPropertyDataSize(deviceID, &inputStreamsPropertyAddress, 0, nil, &size)
        self.hasInputStreams = size > 0
        
        // Verificar se tem streams de saída
        var outputStreamsPropertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreams,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        
        AudioObjectGetPropertyDataSize(deviceID, &outputStreamsPropertyAddress, 0, nil, &size)
        self.hasOutputStreams = size > 0
    }
} 