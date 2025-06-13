#import <Foundation/Foundation.h>
#import <os/log.h>
#import <CoreAudio/CoreAudio.h>
#import "../Shared/AudioHelperProtocol.h"

// Função para acessar o log subsystem da helper
os_log_t helper_log(void);

NS_ASSUME_NONNULL_BEGIN

/**
 * AudioCaptureService implementa o protocolo XPC e gerencia a captura de áudio
 * usando Core Audio TAP REAL. Esta classe executa com privilégios elevados.
 */
@interface AudioCaptureService : NSObject <NSXPCListenerDelegate, AudioHelperProtocol>

@end

NS_ASSUME_NONNULL_END