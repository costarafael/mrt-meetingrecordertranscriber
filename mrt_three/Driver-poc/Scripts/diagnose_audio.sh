#!/bin/bash

# =============================================================================
# MRT Audio Driver - Diagnóstico Completo de Áudio
# =============================================================================

echo "🔍 DIAGNÓSTICO COMPLETO DO SISTEMA DE ÁUDIO"
echo "=============================================="
echo ""

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Função para log com timestamp
log_with_time() {
    echo "[$(date '+%H:%M:%S')] $1"
}

echo "📋 1. DISPOSITIVOS DE ÁUDIO DISPONÍVEIS"
echo "----------------------------------------"
echo ""

# Lista todos os dispositivos de áudio
system_profiler SPAudioDataType | grep -E "(Name:|Manufacturer:|Default)" | head -20

echo ""
echo "📋 2. DRIVER MRT AUDIO STATUS"
echo "-----------------------------"

# Verifica se o driver está instalado
if ls /System/Library/Extensions/MRT* &>/dev/null || ls /Library/Audio/Plug-Ins/HAL/MRT* &>/dev/null; then
    echo -e "${GREEN}✅ Driver MRT encontrado${NC}"
    ls -la /System/Library/Extensions/MRT* /Library/Audio/Plug-Ins/HAL/MRT* 2>/dev/null | head -5
else
    echo -e "${RED}❌ Driver MRT não encontrado${NC}"
fi

echo ""
echo "📋 3. APLICAÇÃO DE CONTROLE"
echo "----------------------------"

cd "$(dirname "$0")/../ControlApp"
if [ -f "Package.swift" ]; then
    echo -e "${GREEN}✅ ControlApp encontrada${NC}"
    echo "Testando detecção de dispositivos..."
    swift run MacOSApp --test-passthrough 2>&1 | head -10
else
    echo -e "${RED}❌ ControlApp não encontrada${NC}"
fi

echo ""
echo "📋 4. CONFIGURAÇÕES DE ÁUDIO DO SISTEMA"
echo "----------------------------------------"

# Dispositivo de saída padrão atual
echo "🎯 Dispositivo de saída padrão:"
defaults read ~/Library/Preferences/com.apple.systemuiserver.plist

echo ""
echo "📋 5. TESTE DE DETECÇÃO AVANÇADA"
echo "--------------------------------"

# Usar AudioHAL para listar dispositivos
cat << 'EOF' > /tmp/audio_test.swift
import CoreAudio
import Foundation

func listAudioDevices() {
    var propsize: UInt32 = 0
    var address = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDevices,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain)
    
    var result = AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &propsize)
    guard result == noErr else { 
        print("❌ Erro ao obter tamanho da propriedade")
        return 
    }
    
    let deviceCount = Int(propsize) / MemoryLayout<AudioDeviceID>.size
    let devices = UnsafeMutablePointer<AudioDeviceID>.allocate(capacity: deviceCount)
    defer { devices.deallocate() }
    
    result = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &propsize, devices)
    guard result == noErr else { 
        print("❌ Erro ao obter dados de dispositivos")
        return 
    }
    
    print("🎵 Dispositivos encontrados: \(deviceCount)")
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
            let isMRT = name.contains("MRT") || name.contains("MRTAudio")
            let marker = isMRT ? "🎯" : "  "
            print("\(marker) [\(deviceID)] \(name)")
        }
    }
}

listAudioDevices()
EOF

echo "Executando teste avançado de detecção..."
swift /tmp/audio_test.swift

echo ""
echo "📋 6. TESTE DE FUNCIONALIDADE DE PASSTHROUGH"
echo "---------------------------------------------"

echo "🔊 Verificando se há áudio sendo processado..."

# Monitora atividade de áudio usando sample
if command -v sample &> /dev/null; then
    echo "Monitorando atividade do processo coreaudiod por 3 segundos..."
    timeout 3 sample coreaudiod 1 -f /tmp/coreaudio_sample.txt &>/dev/null
    if [ -f /tmp/coreaudio_sample.txt ]; then
        echo "✅ Sample gerado - verificando atividade..."
        if grep -q "MRT\|BlackHole" /tmp/coreaudio_sample.txt; then
            echo -e "${GREEN}🎯 Atividade MRT detectada no coreaudiod${NC}"
        else
            echo -e "${YELLOW}⚠️  Nenhuma atividade MRT detectada${NC}"
        fi
        rm -f /tmp/coreaudio_sample.txt
    fi
else
    echo -e "${YELLOW}⚠️  Comando 'sample' não disponível${NC}"
fi

echo ""
echo "📋 7. RECOMENDAÇÕES"
echo "-------------------"

echo -e "${BLUE}💡 Próximos passos para corrigir o passthrough:${NC}"
echo "   1. Implementar MRT_SendAudioToDefaultOutput real"
echo "   2. Adicionar AudioUnit para output"
echo "   3. Configurar formato de áudio apropriado"
echo "   4. Testar latência e sincronização"

echo ""
echo -e "${GREEN}✅ Diagnóstico completo finalizado${NC}"
echo "📄 Veja também: DIAGNÓSTICO_PASSTHROUGH.md"

# Cleanup
rm -f /tmp/audio_test.swift