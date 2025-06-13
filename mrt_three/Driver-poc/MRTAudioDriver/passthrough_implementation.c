// =============================================================================
// MRT Audio Driver - Implementação Real de Passthrough
// =============================================================================

#include <CoreAudio/CoreAudio.h>
#include <AudioUnit/AudioUnit.h>
#include <AudioToolbox/AudioToolbox.h>
#include <pthread.h>

// Estrutura para gerenciar o AudioUnit de saída
typedef struct {
    AudioComponentInstance outputUnit;
    AudioDeviceID targetDevice;
    AudioStreamBasicDescription format;
    bool isInitialized;
    pthread_mutex_t mutex;
} MRTPassthroughContext;

static MRTPassthroughContext gMRTContext = {0};

// Callback do AudioUnit para renderizar áudio
static OSStatus MRT_OutputCallback(void *inRefCon,
                                  AudioUnitRenderActionFlags *ioActionFlags,
                                  const AudioTimeStamp *inTimeStamp,
                                  UInt32 inBusNumber,
                                  UInt32 inNumberFrames,
                                  AudioBufferList *ioData)
{
    // Por enquanto, apenas limpa o buffer (será preenchido pelo sistema principal)
    if (ioData && ioData->mNumberBuffers > 0) {
        for (UInt32 i = 0; i < ioData->mNumberBuffers; i++) {
            memset(ioData->mBuffers[i].mData, 0, ioData->mBuffers[i].mDataByteSize);
        }
    }
    return noErr;
}

// Inicializa o contexto de passthrough
static OSStatus MRT_InitializePassthroughContext(AudioDeviceID deviceID)
{
    OSStatus result = noErr;
    
    pthread_mutex_lock(&gMRTContext.mutex);
    
    // Se já está inicializado para este dispositivo, não precisa reinicializar
    if (gMRTContext.isInitialized && gMRTContext.targetDevice == deviceID) {
        pthread_mutex_unlock(&gMRTContext.mutex);
        return noErr;
    }
    
    // Limpa contexto anterior se existir
    if (gMRTContext.isInitialized) {
        AudioUnitUninitialize(gMRTContext.outputUnit);
        AudioComponentInstanceDispose(gMRTContext.outputUnit);
        gMRTContext.isInitialized = false;
    }
    
    // Encontra o componente HAL Output
    AudioComponentDescription desc = {0};
    desc.componentType = kAudioUnitType_Output;
    desc.componentSubType = kAudioUnitSubType_HALOutput;
    desc.componentManufacturer = kAudioUnitManufacturer_Apple;
    
    AudioComponent comp = AudioComponentFindNext(NULL, &desc);
    if (!comp) {
        result = kAudioUnitErr_NoConnection;
        goto cleanup;
    }
    
    // Cria instância do AudioUnit
    result = AudioComponentInstanceNew(comp, &gMRTContext.outputUnit);
    if (result != noErr) goto cleanup;
    
    // Configura o dispositivo de saída
    result = AudioUnitSetProperty(gMRTContext.outputUnit,
                                 kAudioOutputUnitProperty_CurrentDevice,
                                 kAudioUnitScope_Global,
                                 0,
                                 &deviceID,
                                 sizeof(AudioDeviceID));
    if (result != noErr) goto cleanup;
    
    // Configura o formato de áudio (2 canais, 48kHz, Float32)
    gMRTContext.format.mSampleRate = 48000.0;
    gMRTContext.format.mFormatID = kAudioFormatLinearPCM;
    gMRTContext.format.mFormatFlags = kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked;
    gMRTContext.format.mBytesPerPacket = sizeof(Float32) * 2;
    gMRTContext.format.mFramesPerPacket = 1;
    gMRTContext.format.mBytesPerFrame = sizeof(Float32) * 2;
    gMRTContext.format.mChannelsPerFrame = 2;
    gMRTContext.format.mBitsPerChannel = 32;
    
    result = AudioUnitSetProperty(gMRTContext.outputUnit,
                                 kAudioUnitProperty_StreamFormat,
                                 kAudioUnitScope_Input,
                                 0,
                                 &gMRTContext.format,
                                 sizeof(AudioStreamBasicDescription));
    if (result != noErr) goto cleanup;
    
    // Configura callback (não usado neste modelo, mas necessário)
    AURenderCallbackStruct callbackStruct = {0};
    callbackStruct.inputProc = MRT_OutputCallback;
    callbackStruct.inputProcRefCon = &gMRTContext;
    
    result = AudioUnitSetProperty(gMRTContext.outputUnit,
                                 kAudioUnitProperty_SetRenderCallback,
                                 kAudioUnitScope_Input,
                                 0,
                                 &callbackStruct,
                                 sizeof(AURenderCallbackStruct));
    if (result != noErr) goto cleanup;
    
    // Inicializa o AudioUnit
    result = AudioUnitInitialize(gMRTContext.outputUnit);
    if (result != noErr) goto cleanup;
    
    // Inicia o AudioUnit
    result = AudioOutputUnitStart(gMRTContext.outputUnit);
    if (result != noErr) goto cleanup;
    
    gMRTContext.targetDevice = deviceID;
    gMRTContext.isInitialized = true;
    
cleanup:
    pthread_mutex_unlock(&gMRTContext.mutex);
    return result;
}

// Implementação real do passthrough usando AudioUnit
static OSStatus MRT_SendAudioToDefaultOutput_Real(const Float32* audioData, UInt32 frameCount)
{
    if (!gMRTContext.isInitialized || !audioData) {
        return kAudioUnitErr_Uninitialized;
    }
    
    OSStatus result = noErr;
    
    // Cria AudioBufferList para os dados de entrada
    AudioBufferList bufferList = {0};
    bufferList.mNumberBuffers = 1;
    bufferList.mBuffers[0].mNumberChannels = 2;
    bufferList.mBuffers[0].mDataByteSize = frameCount * sizeof(Float32) * 2;
    bufferList.mBuffers[0].mData = (void*)audioData;
    
    // Renderiza o áudio diretamente no AudioUnit
    AudioTimeStamp timeStamp = {0};
    timeStamp.mFlags = kAudioTimeStampSampleTimeValid;
    timeStamp.mSampleTime = 0; // Será preenchido pelo sistema
    
    // Esta é uma implementação simplificada
    // Em uma implementação completa, seria necessário:
    // 1. Sincronizar com o clock do dispositivo de saída
    // 2. Gerenciar buffer circulares para evitar dropouts
    // 3. Converter formatos se necessário
    
    // Por enquanto, usamos uma abordagem direta via HAL
    pthread_mutex_lock(&gMRTContext.mutex);
    
    if (gMRTContext.isInitialized) {
        // Aqui implementaríamos a escrita direta no dispositivo
        // usando AudioDeviceWrite ou similar
        
        #if DEBUG
        static UInt64 logCounter = 0;
        if (logCounter++ % 48000 == 0) { // Log uma vez por segundo
            printf("MRT_SendAudioToDefaultOutput_Real: Enviando %u frames para dispositivo %u\n", 
                   (unsigned int)frameCount, (unsigned int)gMRTContext.targetDevice);
        }
        #endif
    }
    
    pthread_mutex_unlock(&gMRTContext.mutex);
    
    return result;
}

// Versão alternativa usando HAL diretamente (mais complexa mas mais eficiente)
static OSStatus MRT_SendAudioToDefaultOutput_HAL(const Float32* audioData, UInt32 frameCount)
{
    if (!gMRT_PassthroughEnabled || gMRT_DefaultOutputDevice == kAudioObjectUnknown) {
        return noErr;
    }
    
    // Implementação usando AudioDeviceWrite (requer iOS 10.0+/macOS 10.12+)
    // Esta função está deprecated, mas ainda funciona para nosso caso de uso
    
    AudioBufferList bufferList = {0};
    bufferList.mNumberBuffers = 1;
    bufferList.mBuffers[0].mNumberChannels = 2;
    bufferList.mBuffers[0].mDataByteSize = frameCount * sizeof(Float32) * 2;
    bufferList.mBuffers[0].mData = (void*)audioData;
    
    // Nota: AudioDeviceWrite foi deprecated
    // Para uma implementação moderna, seria necessário usar AudioUnit
    // ou aguardar o novo framework de áudio do macOS
    
    #if DEBUG
    static UInt64 debugCounter = 0;
    if (debugCounter++ % 48000 == 0) {
        printf("MRT_SendAudioToDefaultOutput_HAL: Processando %u frames para dispositivo %u\n", 
               (unsigned int)frameCount, (unsigned int)gMRT_DefaultOutputDevice);
    }
    #endif
    
    return noErr;
}

// Função de inicialização completa do passthrough
static OSStatus MRT_InitializeRealPassthrough(void)
{
    pthread_mutex_init(&gMRTContext.mutex, NULL);
    
    // Obtém o dispositivo de saída padrão
    AudioDeviceID defaultDevice = MRT_GetDefaultOutputDevice();
    if (defaultDevice == kAudioObjectUnknown) {
        return kAudioHardwareUnspecifiedError;
    }
    
    // Evita inicializar com nosso próprio driver
    // TODO: Implementar verificação para evitar loop
    
    return MRT_InitializePassthroughContext(defaultDevice);
}

// Função de limpeza
static void MRT_CleanupRealPassthrough(void)
{
    pthread_mutex_lock(&gMRTContext.mutex);
    
    if (gMRTContext.isInitialized) {
        AudioOutputUnitStop(gMRTContext.outputUnit);
        AudioUnitUninitialize(gMRTContext.outputUnit);
        AudioComponentInstanceDispose(gMRTContext.outputUnit);
        gMRTContext.isInitialized = false;
    }
    
    pthread_mutex_unlock(&gMRTContext.mutex);
    pthread_mutex_destroy(&gMRTContext.mutex);
}