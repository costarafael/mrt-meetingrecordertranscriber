#!/bin/bash

# =============================================================================
# MRT Audio Driver - Aplicar Correção de Passthrough
# =============================================================================

echo "🔧 APLICANDO CORREÇÃO DE PASSTHROUGH"
echo "====================================="
echo ""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRIVER_DIR="$(dirname "$SCRIPT_DIR")/MRTAudioDriver"

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "📋 1. BACKUP DO DRIVER ORIGINAL"
echo "--------------------------------"

if [ -f "$DRIVER_DIR/MRTAudioDriver.c" ]; then
    cp "$DRIVER_DIR/MRTAudioDriver.c" "$DRIVER_DIR/MRTAudioDriver.c.backup.$(date +%Y%m%d_%H%M%S)"
    echo -e "${GREEN}✅ Backup criado${NC}"
else
    echo -e "${RED}❌ Arquivo original não encontrado${NC}"
    exit 1
fi

echo ""
echo "📋 2. APLICANDO CORREÇÃO"
echo "------------------------"

# Cria versão corrigida do driver
cat > "$DRIVER_DIR/MRTAudioDriver_fixed.c" << 'EOF'
// Implementação real de MRT_SendAudioToDefaultOutput
static OSStatus MRT_SendAudioToDefaultOutput(const Float32* audioData, UInt32 frameCount)
{
    if (!gMRT_PassthroughEnabled || gMRT_DefaultOutputDevice == kAudioObjectUnknown) {
        return noErr; // Passthrough disabled or no output device
    }
    
    // Evita loop infinito - não enviar para nós mesmos
    // TODO: Implementar verificação mais robusta
    static bool isOurDevice = false;
    static UInt32 checkCounter = 0;
    
    if (checkCounter++ % 48000 == 0) { // Verifica uma vez por segundo
        // Verifica se o dispositivo padrão é nosso próprio driver
        // Por simplicidade, assumimos que dispositivos com ID muito alto são virtuais
        isOurDevice = (gMRT_DefaultOutputDevice > 100);
    }
    
    if (isOurDevice) {
        // Se somos o dispositivo padrão, precisamos encontrar o dispositivo físico real
        AudioDeviceID physicalDevice = MRT_FindPhysicalOutputDevice();
        if (physicalDevice != kAudioObjectUnknown && physicalDevice != gMRT_DefaultOutputDevice) {
            gMRT_DefaultOutputDevice = physicalDevice;
            isOurDevice = false;
        } else {
            return noErr; // Evita loop infinito
        }
    }
    
    // Implementação simples usando AudioQueue para reprodução
    static AudioQueueRef outputQueue = NULL;
    static AudioQueueBufferRef buffer = NULL;
    static bool queueInitialized = false;
    
    if (!queueInitialized) {
        // Configura formato de áudio
        AudioStreamBasicDescription format = {0};
        format.mSampleRate = 48000.0;
        format.mFormatID = kAudioFormatLinearPCM;
        format.mFormatFlags = kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked;
        format.mBytesPerPacket = sizeof(Float32) * 2;
        format.mFramesPerPacket = 1;
        format.mBytesPerFrame = sizeof(Float32) * 2;
        format.mChannelsPerFrame = 2;
        format.mBitsPerChannel = 32;
        
        // Cria AudioQueue para o dispositivo específico
        OSStatus status = AudioQueueNewOutput(&format, NULL, NULL, NULL, kCFRunLoopCommonModes, 0, &outputQueue);
        if (status == noErr) {
            // Configura dispositivo de saída
            status = AudioQueueSetProperty(outputQueue, kAudioQueueProperty_CurrentDevice, 
                                         &gMRT_DefaultOutputDevice, sizeof(AudioDeviceID));
            
            if (status == noErr) {
                // Aloca buffer
                status = AudioQueueAllocateBuffer(outputQueue, frameCount * sizeof(Float32) * 2, &buffer);
                if (status == noErr) {
                    queueInitialized = true;
                    AudioQueueStart(outputQueue, NULL);
                }
            }
        }
        
        if (status != noErr) {
            #if DEBUG
            printf("MRT_SendAudioToDefaultOutput: Erro ao inicializar AudioQueue: %d\n", (int)status);
            #endif
            return status;
        }
    }
    
    if (queueInitialized && outputQueue && buffer) {
        // Copia dados para o buffer
        UInt32 dataSize = frameCount * sizeof(Float32) * 2;
        if (dataSize <= buffer->mAudioDataBytesCapacity) {
            memcpy(buffer->mAudioData, audioData, dataSize);
            buffer->mAudioDataByteSize = dataSize;
            
            // Envia buffer para reprodução
            OSStatus status = AudioQueueEnqueueBuffer(outputQueue, buffer, 0, NULL);
            
            #if DEBUG
            static UInt64 successCounter = 0;
            if (successCounter++ % 48000 == 0) {
                printf("MRT_SendAudioToDefaultOutput: %u frames enviados para dispositivo %u (status: %d)\n", 
                       (unsigned int)frameCount, (unsigned int)gMRT_DefaultOutputDevice, (int)status);
            }
            #endif
        }
    }
    
    return noErr;
}

// Função para encontrar um dispositivo físico real
static AudioDeviceID MRT_FindPhysicalOutputDevice(void)
{
    UInt32 propsize = 0;
    AudioObjectPropertyAddress address = {
        kAudioHardwarePropertyDevices,
        kAudioObjectPropertyScopeGlobal,
        kAudioObjectPropertyElementMain
    };
    
    OSStatus result = AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), 
                                                     &address, 0, NULL, &propsize);
    if (result != noErr) return kAudioObjectUnknown;
    
    UInt32 deviceCount = propsize / sizeof(AudioDeviceID);
    AudioDeviceID *devices = malloc(propsize);
    if (!devices) return kAudioObjectUnknown;
    
    result = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), 
                                       &address, 0, NULL, &propsize, devices);
    
    if (result != noErr) {
        free(devices);
        return kAudioObjectUnknown;
    }
    
    // Procura por um dispositivo físico (não virtual)
    for (UInt32 i = 0; i < deviceCount; i++) {
        AudioDeviceID deviceID = devices[i];
        
        // Pula nosso próprio driver (baseado no ID ou nome)
        if (deviceID == gMRT_DefaultOutputDevice) continue;
        
        // Verifica se o dispositivo tem streams de saída
        AudioObjectPropertyAddress streamAddress = {
            kAudioDevicePropertyStreams,
            kAudioDevicePropertyScopeOutput,
            kAudioObjectPropertyElementMain
        };
        
        UInt32 streamSize = 0;
        result = AudioObjectGetPropertyDataSize(deviceID, &streamAddress, 0, NULL, &streamSize);
        
        if (result == noErr && streamSize > 0) {
            // Este dispositivo tem streams de saída, assumimos que é físico
            free(devices);
            return deviceID;
        }
    }
    
    free(devices);
    return kAudioObjectUnknown;
}
EOF

echo -e "${GREEN}✅ Arquivo de correção criado${NC}"

echo ""
echo "📋 3. INSTRUÇÕES PARA APLICAR"
echo "------------------------------"

echo -e "${YELLOW}⚠️  ATENÇÃO: Esta correção requer integração manual${NC}"
echo ""
echo "Para aplicar a correção:"
echo "1. Localize a função MRT_SendAudioToDefaultOutput no arquivo MRTAudioDriver.c"
echo "2. Substitua a implementação atual pela versão em MRTAudioDriver_fixed.c"
echo "3. Adicione a função MRT_FindPhysicalOutputDevice ao arquivo"
echo "4. Recompile e reinstale o driver"

echo ""
echo "📋 4. ALTERNATIVA: PATCH AUTOMÁTICO"
echo "-----------------------------------"

read -p "Deseja aplicar o patch automaticamente? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Aplicando patch..."
    
    # Localiza a função MRT_SendAudioToDefaultOutput e substitui
    python3 << 'PYTHON_SCRIPT'
import re
import sys

def apply_patch():
    try:
        # Lê o arquivo original
        with open('../MRTAudioDriver/MRTAudioDriver.c', 'r') as f:
            content = f.read()
        
        # Lê a correção
        with open('../MRTAudioDriver/MRTAudioDriver_fixed.c', 'r') as f:
            fixed_content = f.read()
        
        # Encontra e substitui a função MRT_SendAudioToDefaultOutput
        pattern = r'static OSStatus MRT_SendAudioToDefaultOutput\([^}]+\}[^}]*\}'
        
        # Extrai a nova implementação
        new_function = re.search(r'static OSStatus MRT_SendAudioToDefaultOutput.*?^}', 
                                fixed_content, re.MULTILINE | re.DOTALL)
        
        if new_function:
            new_content = re.sub(pattern, new_function.group(0), content, flags=re.DOTALL)
            
            # Adiciona a nova função MRT_FindPhysicalOutputDevice
            find_function = re.search(r'static AudioDeviceID MRT_FindPhysicalOutputDevice.*?^}', 
                                    fixed_content, re.MULTILINE | re.DOTALL)
            
            if find_function:
                # Insere antes da função MRT_SendAudioToDefaultOutput
                insertion_point = new_content.find('static OSStatus MRT_SendAudioToDefaultOutput')
                if insertion_point > 0:
                    new_content = (new_content[:insertion_point] + 
                                 find_function.group(0) + '\n\n' + 
                                 new_content[insertion_point:])
            
            # Salva o arquivo modificado
            with open('../MRTAudioDriver/MRTAudioDriver.c', 'w') as f:
                f.write(new_content)
            
            print("✅ Patch aplicado com sucesso!")
            return True
        else:
            print("❌ Não foi possível encontrar a função para substituir")
            return False
            
    except Exception as e:
        print(f"❌ Erro ao aplicar patch: {e}")
        return False

if apply_patch():
    sys.exit(0)
else:
    sys.exit(1)
PYTHON_SCRIPT

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ Patch aplicado automaticamente${NC}"
        echo ""
        echo "📋 5. PRÓXIMOS PASSOS"
        echo "---------------------"
        echo "1. Recompilar o driver: make clean && make"
        echo "2. Reinstalar: sudo bash Scripts/install_driver.sh"
        echo "3. Testar: bash Scripts/test_passthrough.sh"
    else
        echo -e "${RED}❌ Falha ao aplicar patch automaticamente${NC}"
        echo "Por favor, aplique manualmente usando as instruções acima"
    fi
else
    echo "Patch não aplicado. Use as instruções manuais acima."
fi

echo ""
echo -e "${BLUE}💡 Nota: Após aplicar a correção, o passthrough deve funcionar${NC}"
echo -e "${BLUE}   redirecionando áudio para o dispositivo de saída físico real.${NC}"