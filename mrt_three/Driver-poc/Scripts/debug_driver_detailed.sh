#!/bin/bash

# =============================================================================
# DEBUG DETALHADO - Capturar logs durante reprodução de áudio
# =============================================================================

echo "🔍 DEBUG DETALHADO DO DRIVER MRT"
echo "==============================="

LOG_DIR="/Users/rafaelaredes/Documents/mrt_macos/mrt_three/Driver-poc/logs"
mkdir -p "$LOG_DIR"

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="$LOG_DIR/debug_detailed_$TIMESTAMP.log"

echo "📋 Logs serão salvos em: $LOG_FILE"

# Função para capturar logs em tempo real
start_logging() {
    echo "🚀 Iniciando monitoramento de logs..." | tee -a "$LOG_FILE"
    
    # Capturar logs do CoreAudio em tempo real
    log stream --predicate 'category == "CoreAudio" || eventMessage contains "MRT" || eventMessage contains "AudioServerPlugIn" || eventMessage contains "IOWorkLoop"' --style syslog >> "$LOG_FILE" &
    LOG_PID=$!
    
    echo "📊 Processo de log iniciado: PID $LOG_PID" | tee -a "$LOG_FILE"
    return $LOG_PID
}

# Função para parar logs
stop_logging() {
    if [ ! -z "$LOG_PID" ]; then
        kill $LOG_PID 2>/dev/null
        echo "✅ Monitoramento de logs parado" | tee -a "$LOG_FILE"
    fi
}

# Verificar status inicial
echo ""
echo "🔍 1. STATUS INICIAL:" | tee -a "$LOG_FILE"
echo "====================" | tee -a "$LOG_FILE"

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
                        print(\"📊 MRTAudio [\(deviceID)]: \(isRunning == 1 ? \"RODANDO\" : \"PARADO\")\")
                    }
                    break
                }
            }
        }
    }
}
" | tee -a "$LOG_FILE"

echo ""
echo "🎵 2. TESTE COM ÁUDIO:" | tee -a "$LOG_FILE"
echo "=====================" | tee -a "$LOG_FILE"
echo ""
echo "INSTRUÇÕES:" | tee -a "$LOG_FILE"
echo "1. Vou iniciar o monitoramento de logs" | tee -a "$LOG_FILE"
echo "2. Você deve reproduzir áudio (YouTube, Spotify, etc)" | tee -a "$LOG_FILE"
echo "3. Mantenha MRTAudio como saída padrão" | tee -a "$LOG_FILE"
echo "4. Pressione ENTER quando terminar o teste" | tee -a "$LOG_FILE"

# Iniciar logging em background
start_logging

echo ""
echo "🚀 Monitoramento iniciado! Reproduza áudio agora..."
echo "   (Os logs estão sendo capturados em tempo real)"
echo ""
read -p "Pressione ENTER quando terminar o teste de áudio..."

# Parar logging
stop_logging

echo ""
echo "🔍 3. STATUS FINAL:" | tee -a "$LOG_FILE"
echo "==================" | tee -a "$LOG_FILE"

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
                        print(\"📊 MRTAudio [\(deviceID)]: \(isRunning == 1 ? \"RODANDO\" : \"PARADO\")\")
                    }
                    break
                }
            }
        }
    }
}
" | tee -a "$LOG_FILE"

echo ""
echo "🔍 4. ANÁLISE DOS LOGS:" | tee -a "$LOG_FILE"
echo "======================" | tee -a "$LOG_FILE"

echo ""
echo "📊 Contagem de eventos:"
echo "- Inicializações:" $(grep -c "starting" "$LOG_FILE") | tee -a "$LOG_FILE"
echo "- Finalizações:" $(grep -c "stopping" "$LOG_FILE") | tee -a "$LOG_FILE"
echo "- Erros:" $(grep -c "error" "$LOG_FILE") | tee -a "$LOG_FILE"

echo ""
echo "🚨 Padrões de problemas encontrados:" | tee -a "$LOG_FILE"
grep -E "(stopping|error|fail)" "$LOG_FILE" | tail -10 | tee -a "$LOG_FILE"

echo ""
echo "📋 RELATÓRIO SALVO EM: $LOG_FILE"
echo ""
echo "💡 PRÓXIMOS PASSOS:"
echo "- Analise o arquivo de log para padrões"
echo "- Verifique se há ciclos de start/stop"
echo "- Identifique mensagens de erro específicas"