#import <WebRTC/RTCVideoCapturer.h>
#import <WebRTC/RTCVideoFrame.h>

@protocol VideoFrameProcessorDelegate

- (RTCVideoFrame *)capturer:(RTCVideoCapturer *)capturer didCaptureVideoFrame:(RTCVideoFrame *)frame;

@optional
- (BOOL) setProperty:(NSString*) name value:(NSString*) value;
- (NSString*) getProperty:(NSString*) name;
@end
