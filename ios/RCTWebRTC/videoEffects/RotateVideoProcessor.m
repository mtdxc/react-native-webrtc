#import "RotateVideoProcessor.h"

@implementation RotateVideoProcessor

- (RTCVideoFrame *)capturer:(RTCVideoCapturer *)capturer didCaptureVideoFrame:(RTCVideoFrame *)frame {
  if (_rotate == 0)
    return frame;
  int rotate = (_rotate + frame.rotation) % 360;
  return  [[RTCVideoFrame alloc] initWithBuffer:frame.buffer rotation:rotate timeStampNs:frame.timeStampNs];
}

- (BOOL) setProperty:(NSString*) name value:(NSString*) value {
  if ([name isEqualToString:@"rotate"]) {
    _rotate = [value intValue] / 90 * 90;
    return true;
  }
  return false;
}

- (NSString*) getProperty:(NSString*) name {
  if ([name isEqualToString:@"rotate"]) {
    return [NSString stringWithFormat:@"%d", _rotate];
  }
  return nil;
}

@end
