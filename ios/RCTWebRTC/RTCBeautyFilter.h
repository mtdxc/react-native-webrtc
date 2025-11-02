#import <Foundation/Foundation.h>
#import <CoreVideo/CVPixelBuffer.h>
#import <WebRTC/RTCVideoFrame.h>
#import "videoEffects/VideoFrameProcessor.h"
NS_ASSUME_NONNULL_BEGIN

@interface RTCBeautyFilter : NSObject<VideoFrameProcessorDelegate>
@property float lipstickValue;
@property float beautyValue;
@property float whithValue;
@property float blusherValue;
@property float thinFaceValue;
@property float eyeValue;
@property bool lite;

- (instancetype)init:(BOOL) lite;
- (RTCVideoFrame*)processVideoFrame:(CVPixelBufferRef)imageBuffer ts:(int64_t) ts;
- (RTCVideoFrame*)processFrame:(RTCVideoFrame*)frame;
- (RTCVideoFrame *)capturer:(RTCVideoCapturer *)capturer didCaptureVideoFrame:(RTCVideoFrame *)frame;
- (bool)setProperty:(NSString*)name val:(NSString*) val;
- (NSString*)getProperty:(NSString*)name;
- (int)getLandmarks:(float*) val size:(int)size;
- (int)getLandmarkCount;
- (void)setEnable:(bool)enable;
- (bool)enable;
- (void)close;
@end

NS_ASSUME_NONNULL_END
