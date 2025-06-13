#import <Foundation/Foundation.h>
#import <os/log.h>
#import "AudioCaptureService.h"

// Log subsystem para a helper tool
os_log_t helper_log(void) {
    static os_log_t log;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        log = os_log_create("com.empresa.CoreAudioTapReal.AudioCaptureHelper", "Helper");
    });
    return log;
}

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        os_log(helper_log(), "🚀 AudioCaptureHelper REAL iniciando...");
        
        // Cria o service delegate que implementa o protocolo XPC
        AudioCaptureService *serviceDelegate = [[AudioCaptureService alloc] init];
        
        // Configura o listener XPC para aceitar conexões
        NSXPCListener *listener = [NSXPCListener serviceListener];
        listener.delegate = serviceDelegate;
        
        os_log(helper_log(), "📡 Listener XPC configurado, aguardando conexões...");
        
        // Inicia o listener
        [listener resume];
        
        // Mantém a helper tool rodando
        [[NSRunLoop currentRunLoop] run];
        
        os_log(helper_log(), "🛑 AudioCaptureHelper REAL encerrando");
    }
    return 0;
}