#import <objc/runtime.h>

#import <WebRTC/RTCCameraVideoCapturer.h>
#import <WebRTC/RTCMediaConstraints.h>
#import <WebRTC/RTCMediaStreamTrack.h>
#import <WebRTC/RTCVideoTrack.h>

#import "RTCMediaStreamTrack+React.h"
#import "WebRTCModule+RTCMediaStream.h"
#import "WebRTCModule+RTCPeerConnection.h"
#import "WebRTCModuleOptions.h"

#import "ProcessorProvider.h"
#import "ScreenCaptureController.h"
#import "ScreenCapturer.h"
#import "TrackCapturerEventsEmitter.h"
#import "VideoCaptureController.h"
#import "RTCBeautyFilter.h"

@interface StreamTrackRender : NSObject<RTCAudioRender, RTCRecordSink>
-(instancetype)init:(WebRTCModule*) module dict:(NSDictionary*) dict;
@end

@implementation StreamTrackRender {
  WebRTCModule* module_;
  NSMutableDictionary* dict_;
  bool stream_;
  short* buff_;
  int bpos_;
  int _type;
  int _size;
}

- (void)dealloc {
  if (buff_) {
    free(buff_);
    buff_ = 0;
  }
  //[super dealloc];
}

-(instancetype)init:(WebRTCModule*) module id:(NSString*) id pcId:(int) pcId stream:(bool)stream {
  if([super init]) {
    module_ = module;
    dict_ = [[NSMutableDictionary alloc] init];
    dict_[@"pcId"] = [NSNumber numberWithInt:pcId];
    dict_[stream?@"streamId":@"trackId"] = id;
    stream_ = stream;
    buff_ = 0;
    bpos_ = 0;
    _type = 0;
    _size = 0;
  }
  return self;
}

- (void)setupData:(int) type size:(int) size {
  _type = type;
  _size = size;
}

- (NSString*)eventName {
  return stream_ ? kEventMediaStreamData : kEventMediaStreamTrackData;
}

- (void)onTextOut: (NSString*)text {
  NSMutableDictionary* body = [dict_ mutableCopy];
  body[@"data"] = text;
  body[@"type"] =  @"text";
  [module_ sendEventWithName:[self eventName] body:body];
}

- (void)onAudioData: (NSData *)data tsp:(long) tsp {
  NSMutableDictionary* body = [dict_ mutableCopy];
  body[@"data"] = [data base64Encoding];
  body[@"tsp"] = [NSNumber numberWithLong:tsp];
  body[@"type"] =  @"audio";
  [module_ sendEventWithName:[self eventName] body:body];
}

- (void)onVideoData: (NSData *)data tsp:(long) tsp {
  NSMutableDictionary* body = [dict_ mutableCopy];
  body[@"data"] = [data base64Encoding];
  body[@"tsp"] = [NSNumber numberWithLong:tsp];
  body[@"type"] =  @"video";
  [module_ sendEventWithName:[self eventName] body:body];
}

- (void)onPcmData: (short *)pcmBuffer samplerate:(int)samplerate channel:(int)channel samples:(int)samples tsp_ms:(int64_t) tsp_ms {
  if (samples < _size) {
    if (!buff_) {
      buff_ = (short*)malloc(channel * 2 * (samples + _size));
      bpos_ = 0;
    }
    memcpy(buff_ + bpos_ * channel, pcmBuffer, samples * channel * 2);
    bpos_ += samples;
    int pos = 0;
    while (bpos_ - pos >= _size) {
      [self onPcmData:buff_ + pos * channel samplerate:samplerate channel:channel samples:_size tsp_ms:tsp_ms];
      pos += _size;
    }
    if (pos) {
      bpos_ -= pos;
      if (bpos_)
        memmove(buff_, buff_ + pos * channel, bpos_ * channel * 2);
    }
    return ;
  }
  
  NSMutableDictionary* body = [dict_ mutableCopy];
  if(_type == 1){
    NSData* data = [NSData dataWithBytes:pcmBuffer length:samples * channel * 2];
    body[@"data"] = [data base64Encoding];
  }
  else {
    NSMutableArray* ary = [[NSMutableArray alloc] init];
    for (int i = 0; i<samples * channel;i++) {
      if(_type == 2)
        [ary addObject: [NSNumber numberWithInt:pcmBuffer[i]]];
      if(_type == 3)
        [ary addObject: [NSNumber numberWithFloat:pcmBuffer[i]/32768.0f]];
    }
    body[@"data"] = ary;
  }
  body[@"samplerate"] = [NSNumber numberWithInt:samplerate];
  body[@"channel"] = [NSNumber numberWithInt:channel];
  body[@"samples"] = [NSNumber numberWithInt:samples];
  body[@"type"] =  @"data";
  [module_ sendEventWithName:[self eventName] body:body];
}
@end

@implementation WebRTCModule (RTCMediaStream)

- (VideoEffectProcessor *)videoEffectProcessor {
    return objc_getAssociatedObject(self, _cmd);
}

- (void)setVideoEffectProcessor:(VideoEffectProcessor *)videoEffectProcessor {
    objc_setAssociatedObject(
        self, @selector(videoEffectProcessor), videoEffectProcessor, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

#pragma mark - getUserMedia

/**
 * Initializes a new {@link RTCAudioTrack} which satisfies the given constraints.
 *
 * @param constraints The {@code MediaStreamConstraints} which the new
 * {@code RTCAudioTrack} instance is to satisfy.
 */
- (RTCAudioTrack *)createAudioTrack:(NSDictionary *)constraints {
  NSString *trackId = [[NSUUID UUID] UUIDString];
    RTCAudioTrack *audioTrack = [self.peerConnectionFactory audioTrackWithTrackId:trackId];
    return audioTrack;
}
/**
 * Initializes a new {@link RTCVideoTrack} with the given capture controller
 */
- (RTCVideoTrack *)createVideoTrackWithCaptureController:
    (CaptureController * (^)(RTCVideoSource *))captureControllerCreator {
#if TARGET_OS_TV
    return nil;
#else

    RTCVideoSource *videoSource = [self.peerConnectionFactory videoSource];

    NSString *trackUUID = [[NSUUID UUID] UUIDString];
    RTCVideoTrack *videoTrack = [self.peerConnectionFactory videoTrackWithSource:videoSource trackId:trackUUID];

    CaptureController *captureController = captureControllerCreator(videoSource);
    videoTrack.captureController = captureController;
    [captureController startCapture];

    return videoTrack;
#endif
}

/**
 * Initializes a new {@link RTCMediaTrack} with the given tracks.
 *
 * @return An array with the mediaStreamId in index 0, and track infos in index 1.
 */
- (NSArray *)createMediaStream:(NSArray<RTCMediaStreamTrack *> *)tracks {
#if TARGET_OS_TV
    return nil;
#else
    NSString *mediaStreamId = [[NSUUID UUID] UUIDString];
    RTCMediaStream *mediaStream = [self.peerConnectionFactory mediaStreamWithStreamId:mediaStreamId];
    NSMutableArray<NSDictionary *> *trackInfos = [NSMutableArray array];

    for (RTCMediaStreamTrack *track in tracks) {
        if ([track.kind isEqualToString:@"audio"]) {
            [mediaStream addAudioTrack:(RTCAudioTrack *)track];
        } else if ([track.kind isEqualToString:@"video"]) {
            [mediaStream addVideoTrack:(RTCVideoTrack *)track];
        }

        NSString *trackId = track.trackId;

        self.localTracks[trackId] = track;

        NSDictionary *settings = @{};
        if ([track.kind isEqualToString:@"video"]) {
            RTCVideoTrack *videoTrack = (RTCVideoTrack *)track;
            if ([videoTrack.captureController isKindOfClass:[CaptureController class]]) {
                settings = [videoTrack.captureController getSettings];
            }
        } else if ([track.kind isEqualToString:@"audio"]) {
            settings = @{
                @"deviceId" : @"audio",
                @"groupId" : @"",
            };
        }

        [trackInfos addObject:@{
            @"enabled" : @(track.isEnabled),
            @"id" : trackId,
            @"kind" : track.kind,
            @"readyState" : @"live",
            @"remote" : @(NO),
            @"settings" : settings
        }];
    }

    self.localStreams[mediaStreamId] = mediaStream;
    return @[ mediaStreamId, trackInfos ];
#endif
}

/**
 * Initializes a new {@link RTCVideoTrack} which satisfies the given constraints.
 */
- (RTCVideoTrack *)createVideoTrack:(NSDictionary *)constraints {
#if TARGET_OS_TV
    return nil;
#else
    RTCVideoSource *videoSource = [self.peerConnectionFactory videoSource];

    NSString *trackUUID = [[NSUUID UUID] UUIDString];
    RTCVideoTrack *videoTrack = [self.peerConnectionFactory videoTrackWithSource:videoSource trackId:trackUUID];

#if !TARGET_IPHONE_SIMULATOR
    RTCCameraVideoCapturer *videoCapturer = [[RTCCameraVideoCapturer alloc] initWithDelegate:videoSource];
    VideoCaptureController *videoCaptureController =
        [[VideoCaptureController alloc] initWithCapturer:videoCapturer andConstraints:constraints[@"video"]];
    videoCaptureController.enableMultitaskingCameraAccess =
        [WebRTCModuleOptions sharedInstance].enableMultitaskingCameraAccess;
    videoTrack.captureController = videoCaptureController;
    [videoCaptureController startCapture];
#endif

    return videoTrack;
#endif
}

- (RTCVideoTrack *)createScreenCaptureVideoTrack {
#if TARGET_IPHONE_SIMULATOR || TARGET_OS_OSX || TARGET_OS_TV
    return nil;
#endif

    RTCVideoSource *videoSource = [self.peerConnectionFactory videoSourceForScreenCast:YES];

    NSString *trackUUID = [[NSUUID UUID] UUIDString];
    RTCVideoTrack *videoTrack = [self.peerConnectionFactory videoTrackWithSource:videoSource trackId:trackUUID];

    ScreenCapturer *screenCapturer = [[ScreenCapturer alloc] initWithDelegate:videoSource];
    ScreenCaptureController *screenCaptureController =
        [[ScreenCaptureController alloc] initWithCapturer:screenCapturer];

    TrackCapturerEventsEmitter *emitter = [[TrackCapturerEventsEmitter alloc] initWith:trackUUID webRTCModule:self];
    screenCaptureController.eventsDelegate = emitter;
    videoTrack.captureController = screenCaptureController;
    [screenCaptureController startCapture];

    return videoTrack;
}

RCT_EXPORT_METHOD(getDisplayMedia : (RCTPromiseResolveBlock)resolve rejecter : (RCTPromiseRejectBlock)reject) {
#if TARGET_OS_TV
    reject(@"unsupported_platform", @"tvOS is not supported", nil);
    return;
#else

    RTCVideoTrack *videoTrack = [self createScreenCaptureVideoTrack];

    if (videoTrack == nil) {
        reject(@"DOMException", @"AbortError", nil);
        return;
    }

    NSString *mediaStreamId = [[NSUUID UUID] UUIDString];
    RTCMediaStream *mediaStream = [self.peerConnectionFactory mediaStreamWithStreamId:mediaStreamId];
    [mediaStream addVideoTrack:videoTrack];

    NSString *trackId = videoTrack.trackId;
    self.localTracks[trackId] = videoTrack;

    NSDictionary *trackInfo = @{
        @"enabled" : @(videoTrack.isEnabled),
        @"id" : videoTrack.trackId,
        @"kind" : videoTrack.kind,
        @"readyState" : @"live",
        @"remote" : @(NO)
    };

    self.localStreams[mediaStreamId] = mediaStream;
    resolve(@{@"streamId" : mediaStreamId, @"track" : trackInfo});
#endif
}

/**
 * Implements {@code getUserMedia}. Note that at this point constraints have
 * been normalized and permissions have been granted. The constraints only
 * contain keys for which permissions have already been granted, that is,
 * if audio permission was not granted, there will be no "audio" key in
 * the constraints dictionary.
 */
RCT_EXPORT_METHOD(getUserMedia : (NSDictionary *)constraints successCallback : (RCTResponseSenderBlock)
                      successCallback errorCallback : (RCTResponseSenderBlock)errorCallback) {
#if TARGET_OS_TV
    errorCallback(@[ @"PlatformNotSupported", @"getUserMedia is not supported on tvOS." ]);
    return;
#else
    RTCAudioTrack *audioTrack = nil;
    RTCVideoTrack *videoTrack = nil;

    if (constraints[@"audio"]) {
        audioTrack = [self createAudioTrack:constraints];
    }
    if (constraints[@"video"]) {
        videoTrack = [self createVideoTrack:constraints];
    }

    if (audioTrack == nil && videoTrack == nil) {
        // Fail with DOMException with name AbortError as per:
        // https://www.w3.org/TR/mediacapture-streams/#dom-mediadevices-getusermedia
        errorCallback(@[ @"DOMException", @"AbortError" ]);
        return;
    }

    NSString *mediaStreamId = [[NSUUID UUID] UUIDString];
    RTCMediaStream *mediaStream = [self.peerConnectionFactory mediaStreamWithStreamId:mediaStreamId];
    NSMutableArray *tracks = [NSMutableArray array];
    NSMutableArray *tmp = [NSMutableArray array];
    if (audioTrack)
        [tmp addObject:audioTrack];
    if (videoTrack)
        [tmp addObject:videoTrack];

    for (RTCMediaStreamTrack *track in tmp) {
        if ([track.kind isEqualToString:@"audio"]) {
            [mediaStream addAudioTrack:(RTCAudioTrack *)track];
        } else if ([track.kind isEqualToString:@"video"]) {
            [mediaStream addVideoTrack:(RTCVideoTrack *)track];
        }

        NSString *trackId = track.trackId;

        self.localTracks[trackId] = track;

        NSDictionary *settings = @{};
        if ([track.kind isEqualToString:@"video"]) {
            RTCVideoTrack *videoTrack = (RTCVideoTrack *)track;
            if ([videoTrack.captureController isKindOfClass:[CaptureController class]]) {
                settings = [videoTrack.captureController getSettings];
            }
        } else if ([track.kind isEqualToString:@"audio"]) {
            settings = @{
                @"deviceId" : @"audio",
                @"groupId" : @"",
            };
        }

        [tracks addObject:@{
            @"enabled" : @(track.isEnabled),
            @"id" : trackId,
            @"kind" : track.kind,
            @"readyState" : @"live",
            @"remote" : @(NO),
            @"settings" : settings
        }];
    }

    self.localStreams[mediaStreamId] = mediaStream;
    successCallback(@[ mediaStreamId, tracks ]);
#endif
}

#pragma mark - Other stream related APIs

RCT_EXPORT_METHOD(enumerateDevices : (RCTResponseSenderBlock)callback) {
#if TARGET_OS_TV
    callback(@[]);
#else
    NSMutableArray *devices = [NSMutableArray array];
    NSMutableArray *deviceTypes = [NSMutableArray array];
    [deviceTypes addObjectsFromArray:@[
        AVCaptureDeviceTypeBuiltInWideAngleCamera,
        AVCaptureDeviceTypeBuiltInUltraWideCamera,
        AVCaptureDeviceTypeBuiltInTelephotoCamera,
        AVCaptureDeviceTypeBuiltInDualCamera,
        AVCaptureDeviceTypeBuiltInDualWideCamera,
        AVCaptureDeviceTypeBuiltInTripleCamera
    ]];
    if (@available(macos 14.0, ios 17.0, tvos 17.0, *)) {
        [deviceTypes addObject:AVCaptureDeviceTypeExternal];
    }
    AVCaptureDeviceDiscoverySession *videoDevicesSession =
        [AVCaptureDeviceDiscoverySession discoverySessionWithDeviceTypes:deviceTypes
                                                               mediaType:AVMediaTypeVideo
                                                                position:AVCaptureDevicePositionUnspecified];
    for (AVCaptureDevice *device in videoDevicesSession.devices) {
        NSString *position = @"unknown";
        if (device.position == AVCaptureDevicePositionBack) {
            position = @"environment";
        } else if (device.position == AVCaptureDevicePositionFront) {
            position = @"front";
        }
        NSString *label = @"Unknown video device";
        if (device.localizedName != nil) {
            label = device.localizedName;
        }

        [devices addObject:@{
            @"facing" : position,
            @"deviceId" : device.uniqueID,
            @"groupId" : @"",
            @"label" : label,
            @"kind" : @"videoinput",
        }];
    }
    AVCaptureDeviceDiscoverySession *audioDevicesSession =
        [AVCaptureDeviceDiscoverySession discoverySessionWithDeviceTypes:@[ AVCaptureDeviceTypeBuiltInMicrophone ]
                                                               mediaType:AVMediaTypeAudio
                                                                position:AVCaptureDevicePositionUnspecified];
    for (AVCaptureDevice *device in audioDevicesSession.devices) {
        NSString *label = @"Unknown audio device";
        if (device.localizedName != nil) {
            label = device.localizedName;
        }
        [devices addObject:@{
            @"deviceId" : device.uniqueID,
            @"groupId" : @"",
            @"label" : label,
            @"kind" : @"audioinput",
        }];
    }
    callback(@[ devices ]);
#endif
}

RCT_EXPORT_METHOD(mediaStreamCreate : (nonnull NSString *)streamID) {
    RTCMediaStream *mediaStream = [self.peerConnectionFactory mediaStreamWithStreamId:streamID];
    self.localStreams[streamID] = mediaStream;
}

RCT_EXPORT_METHOD(mediaStreamAddTrack : (nonnull NSString *)streamID : (nonnull NSNumber *)pcId : (nonnull NSString *)
                      trackID) {
    RTCMediaStream *mediaStream = self.localStreams[streamID];
    if (mediaStream == nil) {
        return;
    }

    RTCMediaStreamTrack *track = [self trackForId:trackID pcId:pcId];
    if (track == nil) {
        return;
    }

    if ([track.kind isEqualToString:@"audio"]) {
        [mediaStream addAudioTrack:(RTCAudioTrack *)track];
    } else if ([track.kind isEqualToString:@"video"]) {
        [mediaStream addVideoTrack:(RTCVideoTrack *)track];
    }
}

RCT_EXPORT_METHOD(mediaStreamRemoveTrack : (nonnull NSString *)streamID : (nonnull NSNumber *)
                      pcId : (nonnull NSString *)trackID) {
    RTCMediaStream *mediaStream = self.localStreams[streamID];
    if (mediaStream == nil) {
        return;
    }

    RTCMediaStreamTrack *track = [self trackForId:trackID pcId:pcId];
    if (track == nil) {
        return;
    }

    if ([track.kind isEqualToString:@"audio"]) {
        [mediaStream removeAudioTrack:(RTCAudioTrack *)track];
    } else if ([track.kind isEqualToString:@"video"]) {
        [mediaStream removeVideoTrack:(RTCVideoTrack *)track];
    }
}

RCT_EXPORT_METHOD(mediaStreamRelease : (nonnull NSString *)streamID) {
    RTCMediaStream *stream = self.localStreams[streamID];
    if (stream) {
        [self.localStreams removeObjectForKey:streamID];
        [stream stopRecord];
    }
}

RCT_EXPORT_METHOD(mediaStreamTrackRelease : (nonnull NSString *)trackID) {
#if TARGET_OS_TV
    return;
#else

    RTCMediaStreamTrack *track = self.localTracks[trackID];
    if (track) {
        track.isEnabled = NO;
        [track.captureController stopCapture];
        [self.localTracks removeObjectForKey:trackID];
        [track stopRecord];
    }
#endif
}

RCT_EXPORT_METHOD(mediaStreamTrackSetEnabled : (nonnull NSNumber *)pcId : (nonnull NSString *)trackID : (BOOL)enabled) {
    RTCMediaStreamTrack *track = [self trackForId:trackID pcId:pcId];
    if (track == nil) {
        return;
    }

    track.isEnabled = enabled;
#if !TARGET_OS_TV
    if (track.captureController) {  // It could be a remote track!
        if (enabled) {
            [track.captureController startCapture];
        } else {
            [track.captureController stopCapture];
        }
    }
#endif
}

RCT_EXPORT_METHOD(mediaStreamStartRecord : (nonnull NSString *)streamID
                    path    : (NSString*)path 
                    cb      : (int) cb
                    resolve : (RCTPromiseResolveBlock)resolve
                    reject  : (RCTPromiseRejectBlock)reject) {
    RTCMediaStream *mediaStream = [self streamForReactTag:streamID];
    if (mediaStream == nil) {
        reject(@"not_found", @"stream not found", nil);
        return;
    }
    bool ret = [mediaStream startRecord:path];
    if (ret && cb) {
      StreamTrackRender* render = [[StreamTrackRender alloc] init:self id:streamID pcId:-1 stream:true];
      [mediaStream setRecordSink:render];
    }
    resolve([NSNumber numberWithBool: ret]);
}

RCT_EXPORT_METHOD(mediaStreamStopRecord : (nonnull NSString *)streamID
                    resolve : (RCTPromiseResolveBlock)resolve
                    reject  : (RCTPromiseRejectBlock)reject) {
    RTCMediaStream *mediaStream = [self streamForReactTag:streamID];
    if (mediaStream == nil) {
        reject(@"not_found", @"stream not found", nil);
        return;
    }
    bool ret = [mediaStream stopRecord];
    resolve([NSNumber numberWithBool: ret]);
}

RCT_EXPORT_METHOD(mediaStreamTrackMonitorData : (nonnull NSNumber *)pcId
                    trackID : (nonnull NSString *)trackID
                    type    : (int)type
                    size    : (int) size
                    resolve : (RCTPromiseResolveBlock)resolve
                    reject  : (RCTPromiseRejectBlock)reject) {
    RTCMediaStreamTrack *track = [self trackForId:trackID pcId:pcId];
    if (track == nil) {
        reject(@"not_found", @"track not found", nil);
        return;
    }
    bool ret = false;
    if ([track.kind isEqualToString:@"audio"]) {
      RTCAudioTrack* audio = (RTCAudioTrack*)track;
      if(audio.audioRender) {
        [audio removeRender : audio.audioRender];
        audio.audioRender = NULL;
      }
      if (type) {
        if(!audio.audioRender)
          audio.audioRender = [[StreamTrackRender alloc] init:self id:trackID pcId:pcId stream:false];
        [audio.audioRender setupData:type size:size];
        [audio addRender:audio.audioRender];
      }
    }
    resolve([NSNumber numberWithBool: ret]);
}

RCT_EXPORT_METHOD(mediaStreamTrackStartRecord : (nonnull NSNumber *)pcId 
                    trackID : (nonnull NSString *)trackID 
                    path    : (NSString*)path
                    cb      : (int)cb
                    resolve : (RCTPromiseResolveBlock)resolve
                    reject  : (RCTPromiseRejectBlock)reject) {
    RTCMediaStreamTrack *track = [self trackForId:trackID pcId:pcId];
    if (track == nil) {
        reject(@"not_found", @"track not found", nil);
        return;
    }
    bool ret = [track startRecord:path];
    if (ret && cb) {
      StreamTrackRender* render = [[StreamTrackRender alloc] init:self id:trackID pcId:pcId stream:false];
      [track setRecordSink:render];
    }
    resolve([NSNumber numberWithBool: ret]);
}

RCT_EXPORT_METHOD(mediaStreamTrackStopRecord : (nonnull NSNumber *)pcId
                    trackID : (nonnull NSString *)trackID
                    resolve : (RCTPromiseResolveBlock)resolve
                    reject  : (RCTPromiseRejectBlock)reject) {
    RTCMediaStreamTrack *track = [self trackForId:trackID pcId:pcId];
    if (track == nil) {
        reject(@"not_found", @"track not found", nil);
        return;
    }
    bool ret = [track stopRecord];
    resolve([NSNumber numberWithBool: ret]);
}

RCT_EXPORT_METHOD(mediaStreamTrackApplyConstraints : (nonnull NSString *)trackID : (NSDictionary *)
                      constraints : (RCTPromiseResolveBlock)resolve : (RCTPromiseRejectBlock)reject) {
#if TARGET_OS_TV
    reject(@"unsupported_platform", @"tvOS is not supported", nil);
    return;
#else
    RTCMediaStreamTrack *track = self.localTracks[trackID];
    if (track) {
        if ([track.kind isEqualToString:@"video"]) {
        RTCVideoTrack *videoTrack = (RTCVideoTrack *)track;
            if ([videoTrack.captureController isKindOfClass:[CaptureController class]]) {
                CaptureController *vcc = (CaptureController *)videoTrack.captureController;
                NSError *error = nil;
                [vcc applyConstraints:constraints error:&error];
                if (error) {
                    reject(@"E_INVALID", error.localizedDescription, error);
                } else {
                    resolve([vcc getSettings]);
                }
            }
        } else {
            RCTLogWarn(@"mediaStreamTrackApplyConstraints() track is not video");
            reject(@"E_INVALID", @"Can't apply constraints on audio tracks", nil);
        }
    } else {
        RCTLogWarn(@"mediaStreamTrackApplyConstraints() track is null");
        reject(@"E_INVALID", @"Could not get track", nil);
    }
#endif
}

RCT_EXPORT_METHOD(mediaStreamTrackSetVolume : (nonnull NSNumber *)pcId : (nonnull NSString *)trackID : (double)volume) {
    RTCMediaStreamTrack *track = [self trackForId:trackID pcId:pcId];
    if (track && [track.kind isEqualToString:@"audio"]) {
        RTCAudioTrack *audioTrack = (RTCAudioTrack *)track;
        audioTrack.source.volume = volume;
    }
}

RCT_EXPORT_METHOD(mediaStreamTrackSetVideoEffects : (nonnull NSString *)trackID names : (nonnull NSArray<NSString *> *)
                      names) {
    RTCMediaStreamTrack *track = self.localTracks[trackID];
    if (track == nil) {
        return;
    }

    RTCVideoTrack *videoTrack = (RTCVideoTrack *)track;
    RTCVideoSource *videoSource = videoTrack.source;

    NSMutableArray *processors = [[NSMutableArray alloc] init];
    for (NSString *name in names) {
        NSObject<VideoFrameProcessorDelegate> *processor = [ProcessorProvider getProcessor:name];
        if (processor != nil) {
            [processors addObject:processor];
        }
    }

    self.videoEffectProcessor = [[VideoEffectProcessor alloc] initWithProcessors:processors videoSource:videoSource];

    VideoCaptureController *vcc = (VideoCaptureController *)videoTrack.captureController;
    RTCVideoCapturer *capturer = vcc.capturer;

    capturer.delegate = self.videoEffectProcessor;
}

RCT_EXPORT_METHOD(mediaStreamTrackSetVideoEffectProperty : (nonnull NSString *)trackID
                  name :(NSString*) name
                  value :(NSString*) value
                  index :(int) index
                  resolve : (RCTPromiseResolveBlock)resolve
                  reject  : (RCTPromiseRejectBlock)reject) {
  RTCMediaStreamTrack *track = self.localTracks[trackID];
  if (track == nil) {
      reject(@"400", @"no such track", nil);
      return ;
  }
  RTCVideoTrack *videoTrack = (RTCVideoTrack *)track;
  VideoCaptureController *vcc = (VideoCaptureController *)videoTrack.captureController;
  VideoEffectProcessor* pcs = vcc.capturer.delegate;
  BOOL ret = false;
  if (index < 0 || index >= pcs.videoFrameProcessors.count) {
    for (id<VideoFrameProcessorDelegate> process in pcs.videoFrameProcessors) {
      if([process setProperty:name value:value]) {
        ret = true;
        break;
      }
    }
  } else {
    id<VideoFrameProcessorDelegate> process = [pcs.videoFrameProcessors objectAtIndex:index];
    if (process) {
      ret = [process setProperty:name value:value];
    }
  }
  RCTLogInfo(@"setVideoEffectProperty %@ %@ %@ %d return %d", trackID, name, value, index, ret);
  resolve([NSNumber numberWithBool:ret]);
}

RCT_EXPORT_METHOD(mediaStreamTrackGetVideoEffectProperty : (nonnull NSString *)trackID
                  name :(NSString*) name
                  index :(int) index
                  resolve : (RCTPromiseResolveBlock)resolve
                  reject  : (RCTPromiseRejectBlock)reject) {
  RTCMediaStreamTrack *track = self.localTracks[trackID];
  if (track == nil) {
      reject(@"400", @"no such track", nil);
      return ;
  }
  RTCVideoTrack *videoTrack = (RTCVideoTrack *)track;
  VideoCaptureController *vcc = (VideoCaptureController *)videoTrack.captureController;
  VideoEffectProcessor* pcs = vcc.capturer.delegate;
  NSString* ret = nil;
  if (index < 0 || index >= pcs.videoFrameProcessors.count) {
    for (id<VideoFrameProcessorDelegate> process in pcs.videoFrameProcessors) {
      ret = [process getProperty:name];
      if(ret) {
        break;
      }
    }
  } else {
    id<VideoFrameProcessorDelegate> process = [pcs.videoFrameProcessors objectAtIndex:index];
    if (process) {
      ret = [process getProperty:name];
    }
  }
  resolve(ret);
}

#pragma mark - Helpers

- (RTCMediaStreamTrack *)trackForId:(nonnull NSString *)trackId pcId:(nonnull NSNumber *)pcId {
    if ([pcId isEqualToNumber:[NSNumber numberWithInt:-1]]) {
        return self.localTracks[trackId];
    }

    RTCPeerConnection *peerConnection = self.peerConnections[pcId];
    if (peerConnection == nil) {
        return nil;
    }

    return peerConnection.remoteTracks[trackId];
}

@end
