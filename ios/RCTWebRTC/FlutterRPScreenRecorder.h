#if TARGET_OS_IPHONE
#import <WebRTC/WebRTC.h>
#import "CaptureController.h"
@interface FlutterRPScreenRecorder : RTCVideoCapturer

- (void)startCapture;

// Stops the capture session asynchronously and notifies callback on completion.
- (void)stopCaptureWithCompletionHandler:(nullable void (^)(void))completionHandler;

- (void)stopCapture;

@end

@interface RPScreenCaptureController : CaptureController
- (instancetype)initWithCapturer:(FlutterRPScreenRecorder*) capturer;
- (void)startCapture;
- (void)stopCapture;
@end
#endif
