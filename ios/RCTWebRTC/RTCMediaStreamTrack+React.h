
#import <WebRTC/RTCMediaStreamTrack.h>

@class CaptureController;
@class StreamTrackRender;

@interface RTCMediaStreamTrack (React)

@property(strong, nonatomic) CaptureController *captureController;
@property(strong, nonatomic) StreamTrackRender *audioRender;

@end
