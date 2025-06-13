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
