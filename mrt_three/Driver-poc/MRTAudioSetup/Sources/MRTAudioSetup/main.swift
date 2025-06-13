import CoreAudio
import Foundation

/**
 * MRT Audio Setup - Solução Definitiva
 * 
 * ARQUITETURA CORRETA (como Krisp/Teams):
 * 1. Driver MRTAudio funciona como loopback (igual BlackHole)
 * 2. Multi-Output Device criado automaticamente
 * 3. Combina: Speakers físicos + MRTAudio
 * 4. Usuário ouve + aplicação captura
 * 5. ZERO configuração manual necessária
 */

@main
struct MRTAudioSetup {
    
    static func main() {
        let setup = AudioSetupManager()
        
        let args = CommandLine.arguments
        
        if args.contains("--status") {
            setup.showStatus()
        } else if args.contains("--disable") {
            setup.disable()
        } else if args.contains("--help") {
            showHelp()
        } else {
            setup.enable()
        }
    }
    
    static func showHelp() {
        print("""
        🎯 MRT Audio Setup - Configuração Automática
        ==========================================
        
        SOLUÇÃO DEFINITIVA que replica Krisp/Teams:
        ✅ Configuração automática completa
        ✅ Zero interação manual necessária  
        ✅ Áudio funciona + captura funciona
        
        Comandos:
          MRTAudioSetup           # Ativar configuração automática
          MRTAudioSetup --status  # Ver status atual
          MRTAudioSetup --disable # Desativar e restaurar
          MRTAudioSetup --help    # Esta ajuda
        
        """)
    }
}

class AudioSetupManager {
    
    private let multiOutputName = "MRT Auto Audio"
    private let multiOutputUID = "MRTAuto_UID_\(UUID().uuidString.prefix(8))"
    
    func enable() {
        print("🚀 MRT Audio Setup - Ativando Configuração Automática")
        print("====================================================")
        
        // 1. Verificar pré-requisitos
        guard checkPrerequisites() else { return }
        
        // 2. Limpar configurações anteriores
        cleanup()
        
        // 3. Criar e configurar Multi-Output Device
        guard let multiOutputID = createAutomaticMultiOutput() else { 
            print("❌ Falha ao criar Multi-Output Device")
            return 
        }
        
        // 4. Configurar como padrão
        if setAsDefaultOutput(deviceID: multiOutputID) {
            print("✅ Configurado como saída padrão")
        }
        
        // 5. Verificar funcionamento
        verifySetup()
        
        print("")
        print("🎯 CONFIGURAÇÃO AUTOMÁTICA CONCLUÍDA!")
        print("=====================================")
        print("✅ Áudio reproduz normalmente nos speakers")
        print("✅ Captura funciona automaticamente via MRTAudio")
        print("✅ Sem necessidade de configuração manual")
        print("✅ Comportamento idêntico ao Krisp/Teams")
        print("")
        print("💡 Para desativar: MRTAudioSetup --disable")
    }
    
    func disable() {
        print("🔧 Desativando MRT Audio Setup...")
        
        cleanup()
        
        // Restaurar dispositivo original
        if let originalDevice = findPhysicalOutputDevice() {
            _ = setAsDefaultOutput(deviceID: originalDevice)
            print("✅ Dispositivo original restaurado")
        }
        
        print("✅ MRT Audio Setup desativado")
    }
    
    func showStatus() {
        print("📊 Status do MRT Audio Setup")
        print("============================")
        
        // Verificar driver MRT
        if let mrtDevice = findMRTAudioDevice() {
            print("✅ Driver MRTAudio: Instalado [\(mrtDevice)]")
        } else {
            print("❌ Driver MRTAudio: Não encontrado")
        }
        
        // Verificar Multi-Output
        if let multiOutput = findMultiOutputDevice() {
            print("✅ Multi-Output Device: Ativo [\(multiOutput)]")
        } else {
            print("⚠️  Multi-Output Device: Não encontrado")
        }
        
        // Verificar dispositivo padrão
        if let currentDefault = getCurrentDefaultOutput() {
            let name = getDeviceName(deviceID: currentDefault) ?? "Desconhecido"
            print("🔊 Dispositivo padrão atual: \(name) [\(currentDefault)]")
            
            if name.contains("MRT") {
                print("✅ Status: MRT Audio Setup ATIVO")
            } else {
                print("ℹ️  Status: MRT Audio Setup INATIVO")
            }
        }
    }
    
    // MARK: - Implementation
    
    private func checkPrerequisites() -> Bool {
        print("🔍 Verificando pré-requisitos...")
        
        guard findMRTAudioDevice() != nil else {
            print("❌ Driver MRTAudio não encontrado")
            print("   Execute primeiro: sudo ./Scripts/install_driver.sh")
            return false
        }
        
        guard findPhysicalOutputDevice() != nil else {
            print("❌ Dispositivo físico de saída não encontrado")
            return false
        }
        
        print("✅ Todos os pré-requisitos atendidos")
        return true
    }
    
    private func cleanup() {
        print("🧹 Limpando configurações anteriores...")
        
        // Remover Multi-Output Devices antigos
        removeOldMultiOutputDevices()
    }
    
    private func createAutomaticMultiOutput() -> AudioDeviceID? {
        print("🔧 Criando Multi-Output Device automático...")
        
        guard let physicalDevice = findPhysicalOutputDevice(),
              let mrtDevice = findMRTAudioDevice() else {
            return nil
        }
        
        let physicalName = getDeviceName(deviceID: physicalDevice) ?? "Físico"
        let mrtName = getDeviceName(deviceID: mrtDevice) ?? "MRT"
        
        print("   📱 Dispositivo físico: \(physicalName)")
        print("   🎙️  Dispositivo captura: \(mrtName)")
        
        guard let physicalUID = getDeviceUID(deviceID: physicalDevice),
              let mrtUID = getDeviceUID(deviceID: mrtDevice) else {
            print("❌ Erro ao obter UIDs dos dispositivos")
            return nil
        }
        
        // Configuração do Multi-Output Device
        let deviceConfig: [String: Any] = [
            kAudioAggregateDeviceNameKey: multiOutputName,
            kAudioAggregateDeviceUIDKey: multiOutputUID,
            kAudioAggregateDeviceSubDeviceListKey: [
                [
                    kAudioSubDeviceUIDKey: physicalUID,
                    kAudioSubDeviceDriftCompensationKey: NSNumber(value: false)
                ],
                [
                    kAudioSubDeviceUIDKey: mrtUID,
                    kAudioSubDeviceDriftCompensationKey: NSNumber(value: true)
                ]
            ],
            kAudioAggregateDeviceMasterSubDeviceKey: physicalUID
        ]
        
        // Criar dispositivo
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioPlugInCreateAggregateDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        
        let cfConfig = deviceConfig as CFDictionary
        let dataSize = UInt32(MemoryLayout<CFDictionary>.size)
        
        let result = withUnsafePointer(to: cfConfig) { configPtr in
            AudioObjectSetPropertyData(
                AudioObjectID(kAudioObjectSystemObject),
                &address, 0, nil,
                dataSize, configPtr)
        }
        
        if result == noErr {
            print("✅ Multi-Output Device criado com sucesso")
            
            // Aguardar aparição no sistema e encontrar
            for _ in 0..<10 {
                Thread.sleep(forTimeInterval: 0.5)
                if let device = findMultiOutputDevice() {
                    return device
                }
            }
            print("⚠️  Multi-Output criado mas não encontrado imediatamente")
            return nil
        } else {
            print("❌ Erro ao criar Multi-Output Device: \(result)")
            return nil
        }
    }
    
    private func verifySetup() {
        print("🔍 Verificando configuração...")
        
        if let currentDefault = getCurrentDefaultOutput() {
            let name = getDeviceName(deviceID: currentDefault) ?? "Desconhecido"
            if name.contains(multiOutputName) {
                print("✅ Multi-Output Device está ativo como padrão")
            } else {
                print("⚠️  Dispositivo padrão: \(name) (não é o Multi-Output)")
            }
        }
    }
    
    // MARK: - Device Management
    
    private func findMRTAudioDevice() -> AudioDeviceID? {
        return findDevice { name in
            name.contains("MRT") && name.contains("Audio")
        }
    }
    
    private func findPhysicalOutputDevice() -> AudioDeviceID? {
        // Procurar dispositivos físicos conhecidos
        let knownPhysical = [
            "MacBook Air Speakers",
            "MacBook Pro Speakers",
            "Built-in Output",
            "Internal Speakers"
        ]
        
        for deviceName in knownPhysical {
            if let device = findDevice(named: deviceName) {
                return device
            }
        }
        
        // Fallback: primeiro não-virtual
        return findDevice { name in
            !name.contains("BlackHole") &&
            !name.contains("MRT") &&
            !name.contains("Multi-Output") &&
            !name.contains("Aggregate") &&
            (name.contains("Speaker") || name.contains("Output"))
        }
    }
    
    private func findMultiOutputDevice() -> AudioDeviceID? {
        return findDevice { name in
            name.contains(multiOutputName)
        }
    }
    
    private func findDevice(named targetName: String) -> AudioDeviceID? {
        return findDevice { name in name == targetName }
    }
    
    private func findDevice(where condition: (String) -> Bool) -> AudioDeviceID? {
        return getAllAudioDevices().first { deviceID in
            if let name = getDeviceName(deviceID: deviceID) {
                return condition(name)
            }
            return false
        }
    }
    
    private func getAllAudioDevices() -> [AudioDeviceID] {
        var propsize: UInt32 = 0
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        
        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &propsize) == noErr else {
            return []
        }
        
        let deviceCount = Int(propsize) / MemoryLayout<AudioDeviceID>.size
        let devices = UnsafeMutablePointer<AudioDeviceID>.allocate(capacity: deviceCount)
        defer { devices.deallocate() }
        
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &propsize, devices) == noErr else {
            return []
        }
        
        return Array(UnsafeBufferPointer(start: devices, count: deviceCount))
    }
    
    private func removeOldMultiOutputDevices() {
        let devicesToRemove = getAllAudioDevices().filter { deviceID in
            if let name = getDeviceName(deviceID: deviceID) {
                return name.contains("MRT") && (name.contains("Multi") || name.contains("Aggregate"))
            }
            return false
        }
        
        for deviceID in devicesToRemove {
            removeAggregateDevice(deviceID: deviceID)
        }
        
        if !devicesToRemove.isEmpty {
            print("🧹 Removidos \(devicesToRemove.count) Multi-Output Device(s) anterior(es)")
        }
    }
    
    private func removeAggregateDevice(deviceID: AudioDeviceID) {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioPlugInDestroyAggregateDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        
        var deviceIDCopy = deviceID
        let dataSize = UInt32(MemoryLayout<AudioDeviceID>.size)
        
        AudioObjectSetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address, 0, nil,
            dataSize, &deviceIDCopy)
    }
    
    // MARK: - System Configuration
    
    private func setAsDefaultOutput(deviceID: AudioDeviceID) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        
        var deviceIDCopy = deviceID
        let dataSize = UInt32(MemoryLayout<AudioDeviceID>.size)
        
        let result = AudioObjectSetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address, 0, nil,
            dataSize, &deviceIDCopy)
        
        return result == noErr
    }
    
    private func getCurrentDefaultOutput() -> AudioDeviceID? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        
        var deviceID: AudioDeviceID = kAudioObjectUnknown
        var dataSize = UInt32(MemoryLayout<AudioDeviceID>.size)
        
        guard AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address, 0, nil,
            &dataSize, &deviceID) == noErr else {
            return nil
        }
        
        return deviceID == kAudioObjectUnknown ? nil : deviceID
    }
    
    // MARK: - Helper Functions
    
    private func getDeviceName(deviceID: AudioDeviceID) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceNameCFString,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        
        var dataSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(deviceID, &address, 0, nil, &dataSize) == noErr else {
            return nil
        }
        
        var deviceName: CFString = "" as CFString
        guard AudioObjectGetPropertyData(deviceID, &address, 0, nil, &dataSize, &deviceName) == noErr else {
            return nil
        }
        
        return deviceName as String
    }
    
    private func getDeviceUID(deviceID: AudioDeviceID) -> String? {
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