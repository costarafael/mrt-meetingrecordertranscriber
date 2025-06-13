import Foundation
import CoreAudio

/// Gerenciador para o driver de áudio MRT
class AudioDriverManager {
    
    // MARK: - Properties
    
    private let driverBundleID = "com.mrt.audio.driver"
    private let driverName = "MRTAudio"
    
    // MARK: - Public Methods
    
    /// Verifica se o driver MRT está instalado
    func isDriverInstalled() -> Bool {
        let driverPath = "/Library/Audio/Plug-Ins/HAL/MRTAudioDriver.driver"
        return FileManager.default.fileExists(atPath: driverPath)
    }
    
    /// Verifica se o driver está ativo no Core Audio
    func isDriverActive() -> Bool {
        guard let audioDevices = getAudioDevices() else { return false }
        
        for deviceID in audioDevices {
            if let deviceName = getDeviceName(deviceID: deviceID),
               deviceName.contains(driverName) {
                return true
            }
        }
        return false
    }
    
    /// Lista todos os dispositivos de áudio do sistema
    func listAudioDevices() -> [(AudioDeviceID, String)] {
        guard let audioDevices = getAudioDevices() else { return [] }
        
        var devices: [(AudioDeviceID, String)] = []
        for deviceID in audioDevices {
            if let name = getDeviceName(deviceID: deviceID) {
                devices.append((deviceID, name))
            }
        }
        return devices
    }
    
    /// Reinicia o Core Audio daemon
    func restartCoreAudio() {
        let task = Process()
        task.launchPath = "/usr/bin/sudo"
        task.arguments = ["killall", "-9", "coreaudiod"]
        
        do {
            try task.run()
            task.waitUntilExit()
            print("Core Audio daemon reiniciado")
        } catch {
            print("Erro ao reiniciar Core Audio: \(error)")
        }
    }
    
    // MARK: - Private Helpers
    
    private func getAudioDevices() -> [AudioDeviceID]? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var dataSize: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &dataSize
        )
        
        guard status == noErr else { return nil }
        
        let deviceCount = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = [AudioDeviceID](repeating: 0, count: deviceCount)
        
        status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &dataSize,
            &deviceIDs
        )
        
        guard status == noErr else { return nil }
        return deviceIDs
    }
    
    private func getDeviceName(deviceID: AudioDeviceID) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceNameCFString,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var dataSize: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(
            deviceID,
            &address,
            0,
            nil,
            &dataSize
        )
        
        guard status == noErr else { return nil }
        
        var name: CFString?
        status = AudioObjectGetPropertyData(
            deviceID,
            &address,
            0,
            nil,
            &dataSize,
            &name
        )
        
        guard status == noErr, let deviceName = name else { return nil }
        return deviceName as String
    }
}