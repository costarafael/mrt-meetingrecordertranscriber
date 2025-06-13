#import <Foundation/Foundation.h>

typedef void (^StatusReplyBlock)(BOOL success, NSError* _Nullable error);

NS_ASSUME_NONNULL_BEGIN

@protocol AudioHelperProtocol
@required
- (void)getVersionWithReply:(void (^_Nonnull)(NSString* _Nonnull version))reply;
- (void)startAudioCaptureForPID:(pid_t)processID withReply:(StatusReplyBlock _Nonnull)reply;
- (void)stopAudioCaptureWithReply:(StatusReplyBlock _Nonnull)reply;
- (void)getCaptureStatusWithReply:(void (^_Nonnull)(BOOL isCapturing, NSString* _Nullable deviceName))reply;
@end

NS_ASSUME_NONNULL_END