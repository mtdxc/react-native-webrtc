#import "RTCBeautyFilter.h"
#import "gpupixel/gpupixel.h"
#import <WebRTC/RTCI420Buffer.h>
#import <WebRTC/RTCNativeI420Buffer.h>
#import <WebRTC/RTCCVPixelBuffer.h>
using namespace gpupixel;

@interface RTCBeautyFilter () {
  std::shared_ptr<SourceRawData> raw_input_;
  std::shared_ptr<SourceRawData> lite_input_;
  std::shared_ptr<BeautyFaceFilter> beauty_face_filter_;
  std::shared_ptr<SinkRawData> raw_output_;
  std::shared_ptr<FaceReshapeFilter> face_reshape_filter_;
  std::shared_ptr<FaceMakeupFilter> lipstick_filter_;
  std::shared_ptr<FaceMakeupFilter> blusher_filter_;
  std::shared_ptr<FaceDetector> face_detect_;
  std::vector<float> face_landmarks_;
  std::atomic<int> frame_count_;
  bool _enable;
}

@end

@implementation RTCBeautyFilter
@synthesize lite = _lite;

- (void)setLite:(bool)lite{
  _lite = lite;
  if (lite) {
    face_landmarks_.clear();
  }
  else{
    [self getLandmarkCount];
  }
}

- (int)getLandmarks:(float*) val size:(int)size{
  if (val && size) {
    if(size > face_landmarks_.size())
      size = face_landmarks_.size();
    memcpy(val, face_landmarks_.data(), size * sizeof(float));
    return size;
  }
  return face_landmarks_.size();
}

- (int)getLandmarkCount {
  if (_lite) return 0;
  if (!face_detect_) {
      face_detect_ = FaceDetector::Create();
  }
  return face_landmarks_.size();
}

- (bool)setProperty:(NSString*)name val:(NSString*)v{
  std::string pname = name.UTF8String;
  float val = [v floatValue];
  if ([name isEqualToString:@"lipstick_level"]) {
    if (lipstick_filter_)
       lipstick_filter_->SetBlendLevel(val);
    return true;
  }
  return beauty_face_filter_->SetProperty(pname, val)
    && (face_reshape_filter_ && face_reshape_filter_->SetProperty(pname, val))
    && (blusher_filter_ && blusher_filter_->SetProperty(pname, val));
}

- (NSString*)getProperty:(NSString*)name{
  float val = 0;
  std::string pname = name.UTF8String;
  if([name isEqualToString:@"lipstick_level"]){
    if (lipstick_filter_)
       lipstick_filter_->GetProperty("blend_level", val);
  }
  else{
    beauty_face_filter_->GetProperty(pname, val)
      || (face_reshape_filter_ && face_reshape_filter_->GetProperty(pname, val))
      || (blusher_filter_ && blusher_filter_->GetProperty(pname, val));
  }
  return [NSString stringWithFormat:@"%f", val];
}

- (instancetype)init:(BOOL) lite {
    self = [super init];
    if (self) {
        _enable = true;
        self.lite = lite;
        [self initVideoFilter];
    }
    return self;
}

- (void)initVideoFilter {
    raw_input_ = SourceRawData::Create();
    lite_input_ = SourceRawData::Create();
    // Create filter
    raw_output_ = SinkRawData::Create();

    beauty_face_filter_ = BeautyFaceFilter::Create();
    beauty_face_filter_->AddSink(raw_output_);

    face_landmarks_.clear();
    // Create filters
    lipstick_filter_ = LipstickFilter::Create();
    blusher_filter_ = BlusherFilter::Create();
    face_reshape_filter_ = FaceReshapeFilter::Create();

    raw_input_->AddSink(lipstick_filter_)
      ->AddSink(blusher_filter_)
      ->AddSink(face_reshape_filter_)
      ->AddSink(beauty_face_filter_);
    lite_input_->AddSink(beauty_face_filter_);
}

- (void) close {
  NSLog(@"RTCBeautyFilter close");
  frame_count_ = 0;
  raw_output_ = nullptr;
  lite_input_ = nullptr;
  lipstick_filter_ = nullptr;
  blusher_filter_ = nullptr;
  face_reshape_filter_ = nullptr;
  raw_input_ = nullptr;
  face_detect_ = nullptr;
}

#pragma mark - Property assignment
- (RTCVideoFrame*)processARGB:(const uint8_t*) pixels
              width: (int) width
             height: (int) height
            rotation:(int) rotation
                 ts: (int64_t) ts {
  auto input = self.lite ? lite_input_ : raw_input_;
  std::vector<uint8_t> temp;
  if (rotation) {
    temp.resize(width * height * 4);
    GPUPixel::ARGBRotation(pixels, temp.data(), width, height, rotation);
    pixels = temp.data();
    if (rotation != 180) {
      std::swap(width, height);
    }
  }

  int stride = width * 4;
  if (face_detect_) {
      face_landmarks_ = face_detect_->Detect(pixels, width, height, stride, GPUPIXEL_MODE_FMT_VIDEO, GPUPIXEL_FRAME_TYPE_BGRA);
      if (lipstick_filter_)
          lipstick_filter_->SetFaceLandmarks(face_landmarks_);
      if (blusher_filter_)
          blusher_filter_->SetFaceLandmarks(face_landmarks_);
      if (face_reshape_filter_)
          face_reshape_filter_->SetFaceLandmarks(face_landmarks_);
  }
  input->ProcessData(pixels, width, height, stride, GPUPIXEL_FRAME_TYPE_BGRA);
  if (auto data = raw_output_->GetI420Buffer()) {
      RTCI420Buffer* i420 = [[RTCI420Buffer alloc] initWithWidth:width height:height dataY:data dataU: data+width*height dataV: data+width*height*5/4];
      RTCVideoFrame* frame = [[RTCVideoFrame alloc] initWithBuffer:i420 rotation:RTCVideoRotation_0 timeStampNs:ts];
      return frame;
  }
  return nil;
}

- (RTCVideoFrame*)processVideoFrame:(CVPixelBufferRef)imageBuffer rotation:(int) rotation ts:(int64_t) ts {
    CVPixelBufferLockBaseAddress(imageBuffer, 0);
    int width = CVPixelBufferGetWidth(imageBuffer);
    int height = CVPixelBufferGetHeight(imageBuffer);
    int stride = CVPixelBufferGetBytesPerRow(imageBuffer) / 4;
    auto pixels = (const uint8_t *)CVPixelBufferGetBaseAddress(imageBuffer);
    RTCVideoFrame* ret = [self processARGB:pixels width:width height:height rotation:rotation ts:ts];
    CVPixelBufferUnlockBaseAddress(imageBuffer, 0);
    return ret;
}

- (RTCVideoFrame*)processFrame:(RTCVideoFrame*)frame {
  if ([frame.buffer isKindOfClass:RTCCVPixelBuffer.class]) {
    RTCCVPixelBuffer* buffer = frame.buffer;
    if (buffer.pixelBuffer && CVPixelBufferGetPixelFormatType(buffer.pixelBuffer) == kCVPixelFormatType_32BGRA) {
      return [self processVideoFrame:buffer.pixelBuffer rotation:frame.rotation ts:frame.timeStampNs];
    }
  }
  id<RTCI420Buffer> i420 = [frame.buffer toI420];
  std::vector<uint8_t> pixel(frame.width*frame.height*4);
  GPUPixel::I420ToARGB(pixel.data(),
                       frame.width, frame.height,
                       i420.dataY, i420.strideY,
                       i420.dataV, i420.strideV,
                       i420.dataU, i420.strideU);
  return [self processARGB:pixel.data() width:frame.width height:frame.height rotation:frame.rotation ts:frame.timeStampNs];
}

- (RTCVideoFrame *)capturer:(RTCVideoCapturer *)capturer didCaptureVideoFrame:(RTCVideoFrame *)frame {
  frame_count_++;
  RTCVideoFrame* ret = [self processFrame:frame];
  if (ret) {
    frame_count_--;
  }
  return ret;
}

@end
 
