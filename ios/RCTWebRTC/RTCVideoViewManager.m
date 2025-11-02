#import <AVFoundation/AVFoundation.h>
#import <objc/runtime.h>

#import <React/RCTLog.h>
#import <React/RCTUIManager.h>
#import <React/RCTView.h>
#import <React/RCTUIManager.h>
#import <WebRTC/RTCMediaStream.h>
#if TARGET_OS_OSX
#import <WebRTC/RTCMTLNSVideoView.h>
#else
#import <WebRTC/RTCMTLVideoView.h>
#endif
#import <WebRTC/RTCCVPixelBuffer.h>
#import <WebRTC/RTCVideoFrame.h>
#import <WebRTC/RTCVideoTrack.h>
#import <WebRTC/RTCPlayer.h>
#import "PIPController.h"
#import "RTCVideoViewManager.h"
#import "WebRTCModule.h"

/**
 * Implements an equivalent of {@code HTMLVideoElement} i.e. Web's video
 * element.
 */
@interface RTCVideoView : RCTView<RTCVideoViewDelegate, RTCPlayEvent>

/**
 * The indicator which determines whether this {@code RTCVideoView} is to mirror
 * the video specified by {@link #videoTrack} during its rendering. Typically,
 * applications choose to mirror the front/user-facing camera.
 */
@property(nonatomic) BOOL mirror;

@property(nonatomic) int statInterval;
@property(nonatomic) int jitter;
@property(nonatomic) int cacheSize;
@property(nonatomic) int playMode;
@property(nonatomic) float volume;
@property(nonatomic) float rate;
@property(nonatomic) BOOL paused;
@property(nonatomic) BOOL muted;
@property(nonatomic) BOOL mutedVideo;
@property(nonatomic, copy) NSString* pid;

/**
 * In the fashion of
 * https://www.w3.org/TR/html5/embedded-content-0.html#dom-video-videowidth
 * and https://www.w3.org/TR/html5/rendering.html#video-object-fit, resembles
 * the CSS style {@code object-fit}.
 */
@property(nonatomic) RTCVideoViewObjectFit objectFit;

@property(nonatomic) BOOL enablePIP;

@property(nonatomic, strong) API_AVAILABLE(ios(15.0)) PIPController *pipController;

/**
 * The {@link RRTCVideoRenderer} which implements the actual rendering.
 */
#if TARGET_OS_OSX
@property(nonatomic, readonly) RTCMTLNSVideoView *videoView;
#else
@property(nonatomic, readonly) RTCMTLVideoView *videoView;
#endif

// Add a reference to the view manager
@property(nonatomic, weak) RTCVideoViewManager *viewManager;

/**
 * The {@link RTCVideoTrack}, if any, which this instance renders.
 */
@property(nonatomic, strong) RTCVideoTrack *videoTrack;
@property(nonatomic, strong) RTCPlayer *player;
@property(nonatomic, copy) RCTBubblingEventBlock onOpen;
@property(nonatomic, copy) RCTBubblingEventBlock onEnd;
@property(nonatomic, copy) RCTBubblingEventBlock onStat;
@property(nonatomic, copy) RCTBubblingEventBlock onSeekDone;

/**
 * Reference to the main WebRTC RN module.
 */
@property(nonatomic, weak) WebRTCModule *module;

@property(nonatomic, copy) RCTDirectEventBlock onDimensionsChange;

@end

@implementation RTCVideoView

@synthesize videoView = _videoView;
@synthesize pipController = _pipController;

/**
 * Tells this view that its window object changed.
 */
- (void)didMoveToWindow {
    // This RTCVideoView strongly retains its videoTrack. The latter strongly
    // retains the former as well though because RTCVideoTrack strongly retains
    // the RTCVideoRenderers added to it. In other words, there is a cycle of
    // strong retainments. In order to break the cycle, and avoid a leak,
    // have this RTCVideoView as the RTCVideoRenderer of its
    // videoTrack only while this view resides in a window.
    RTCVideoTrack *videoTrack = self.videoTrack;

    if (videoTrack) {
        if (self.window) {
            dispatch_async(_module.workerQueue, ^{
                [videoTrack addRenderer:self.videoView];
            });
        } else {
            dispatch_async(_module.workerQueue, ^{
                [videoTrack removeRenderer:self.videoView];
            });
        }
    }
    if (_player) {
      if (self.window) {
        _player.paused = _paused;
      } else {
        _player.paused = true;
      }
    }
}

/**
 * Initializes and returns a newly allocated view object with the specified
 * frame rectangle.
 *
 * @param frame The frame rectangle for the view, measured in points.
 */
- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
#if TARGET_OS_OSX
        RTCMTLNSVideoView *subview = [[RTCMTLNSVideoView alloc] initWithFrame:CGRectZero];
        subview.wantsLayer = true;
        _videoView = subview;
#else
        RTCMTLVideoView *subview = [[RTCMTLVideoView alloc] initWithFrame:CGRectZero];
        _videoView = subview;
#endif
        _objectFit = RTCVideoViewObjectFitCover;
        _jitter = 1200;
        _cacheSize = 512 * 1024;
        _playMode = 0;
        _volume = 1.0f;
        _rate = 1.0f;
        _paused = _muted = _mutedVideo = false;
        _pid = nil;
        [self addSubview:self.videoView];
        self.videoView.delegate = self;
    }

    return self;
}

#if TARGET_OS_OSX
- (void)layout {
    [super layout];
#else
- (void)layoutSubviews {
    [super layoutSubviews];
#endif

    CGRect bounds = self.bounds;
    self.videoView.frame = bounds;
}

/**
 * Implements the setter of the {@link #mirror} property of this
 * {@code RTCVideoView}.
 *
 * @param mirror The value to set on the {@code mirror} property of this
 * {@code RTCVideoView}.
 */
- (void)setMirror:(BOOL)mirror {
    if (_mirror != mirror) {
        _mirror = mirror;

        self.videoView.transform = mirror ? CGAffineTransformMakeScale(-1.0, 1.0) : CGAffineTransformIdentity;
    }
}

- (void)insertReactSubview:(UIView *)subview atIndex:(NSInteger)atIndex {
    // All subviews are treated as fallback views
    [_pipController insertFallbackView:subview];
}

- (void)API_AVAILABLE(ios(15.0))setPIPOptions:(NSDictionary *)pipOptions {
    if (!pipOptions) {
        _pipController = nil;
        return;
    }

    BOOL enabled = YES;
    BOOL startAutomatically = YES;
    BOOL stopAutomatically = YES;

    CGSize preferredSize = CGSizeZero;

    if ([pipOptions objectForKey:@"enabled"]) {
        enabled = [pipOptions[@"enabled"] boolValue];
    }
    if ([pipOptions objectForKey:@"startAutomatically"]) {
        startAutomatically = [pipOptions[@"startAutomatically"] boolValue];
    }
    if ([pipOptions objectForKey:@"stopAutomatically"]) {
        stopAutomatically = [pipOptions[@"stopAutomatically"] boolValue];
    }
    if ([pipOptions objectForKey:@"preferredSize"]) {
        NSDictionary *sizeDict = pipOptions[@"preferredSize"];
        id width = sizeDict[@"width"];
        id height = sizeDict[@"height"];

        if ([width isKindOfClass:[NSNumber class]] && [height isKindOfClass:[NSNumber class]]) {
            preferredSize = CGSizeMake([width doubleValue], [height doubleValue]);
        }
    }

    if (!enabled) {
        _pipController = nil;
        return;
    }

    if (!_pipController) {
        _pipController = [[PIPController alloc] initWithSourceView:self];
        _pipController.videoTrack = _videoTrack;
    }

    _pipController.startAutomatically = startAutomatically;
    _pipController.stopAutomatically = stopAutomatically;
    _pipController.objectFit = _objectFit;
    _pipController.preferredSize = preferredSize;
}

- (void)API_AVAILABLE(ios(15.0))startPIP {
    [_pipController startPIP];
}

- (void)API_AVAILABLE(ios(15.0))stopPIP {
    [_pipController stopPIP];
}

/**
 * Implements the setter of the {@link #objectFit} property of this
 * {@code RTCVideoView}.
 *
 * @param objectFit The value to set on the {@code objectFit} property of this
 * {@code RTCVideoView}.
 */
- (void)setObjectFit:(RTCVideoViewObjectFit)fit {
    if (_objectFit != fit) {
        _objectFit = fit;

#if !TARGET_OS_OSX
        if (fit == RTCVideoViewObjectFitCover) {
            self.videoView.videoContentMode = UIViewContentModeScaleAspectFill;
        } else {
            self.videoView.videoContentMode = UIViewContentModeScaleAspectFit;
        }
#endif
        if (@available(iOS 15.0, *)) {
            _pipController.objectFit = fit;
        }
    }
}

-(void)setStatInterval:(int)val{
  _statInterval = val;
  if (_player)
    _player.statInterval = val;
}

-(void)setJitter:(int)val{
  _jitter = val;
  if (_player)
    _player.jitter = val;
}

-(void)setCacheSize:(int)val{
  _cacheSize = val;
  if (_player)
    _player.cacheSize = val;
}

-(void)setPid:(NSString*)val{
  _pid = val;
  if (_player)
    _player.id = val;
}

-(void)setPlayMode:(int) val{
  _playMode = val;
  if (_player)
    _player.playMode = val;
}

-(void)setVolume:(float) val {
  _volume = val;
  if (_player)
    _player.volume = val;
}

-(void)setRate:(float) val {
  _rate = val;
  if (_player)
    _player.speed = val;
}

-(void)setPaused:(BOOL)val {
  _paused = val;
  if (_player)
    _player.paused = val;
}

-(void)setMuted:(BOOL)val {
  _muted = val;
  if (_player)
    _player.muted = val;
}

-(void)setMutedVideo:(BOOL)val {
  _mutedVideo = val;
  if (_player)
    _player.mutedVideo = val;
}

/**
 * Implements the setter of the {@link #videoTrack} property of this
 * {@code RTCVideoView}.
 *
 * @param videoTrack The value to set on the {@code videoTrack} property of this
 * {@code RTCVideoView}.
 */
- (void)setVideoTrack:(RTCVideoTrack *)videoTrack {
    RTCVideoTrack *oldValue = self.videoTrack;

    if (oldValue != videoTrack) {
        if (oldValue) {
            dispatch_async(_module.workerQueue, ^{
                [oldValue removeRenderer:self.videoView];
            });
        }

        [_pipController setVideoTrack:videoTrack];
        _videoTrack = videoTrack;
        RCTLogInfo(@"%@ setVideoTrack %@", _pid, videoTrack.trackId);
        [self clearView];
        // See "didMoveToWindow" above.
        if (videoTrack && self.window) {
            dispatch_async(_module.workerQueue, ^{
                [videoTrack addRenderer:self.videoView];
            });
        }
    }
}

-(void) clearView {
    // Clear the videoView by rendering a 2x2 blank frame.
    CVPixelBufferRef pixelBuffer;
    CVReturn err = CVPixelBufferCreate(NULL, 2, 2, kCVPixelFormatType_32BGRA, NULL, &pixelBuffer);
    if (err == kCVReturnSuccess) {
        const int kBytesPerPixel = 4;
        CVPixelBufferLockBaseAddress(pixelBuffer, 0);
        int bufferWidth = (int)CVPixelBufferGetWidth(pixelBuffer);
        int bufferHeight = (int)CVPixelBufferGetHeight(pixelBuffer);
        size_t bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer);
        uint8_t *baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer);

        for (int row = 0; row < bufferHeight; row++) {
            uint8_t *pixel = baseAddress + row * bytesPerRow;
            for (int column = 0; column < bufferWidth; column++) {
                pixel[0] = 0;  // BGRA, Blue value
                pixel[1] = 0;  // Green value
                pixel[2] = 0;  // Red value
                pixel[3] = 0;  // Alpha value
                pixel += kBytesPerPixel;
            }
        }

        CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
        int64_t time = (int64_t)(CFAbsoluteTimeGetCurrent() * 1000000000);
        RTCCVPixelBuffer *buffer = [[RTCCVPixelBuffer alloc] initWithPixelBuffer:pixelBuffer];
        RTCVideoFrame *frame = [[[RTCVideoFrame alloc] initWithBuffer:buffer
                                                           rotation:RTCVideoRotation_0
                                                        timeStampNs:time] newI420VideoFrame];

        [self.videoView renderFrame:frame];

        CVPixelBufferRelease(pixelBuffer);
    }
}

-(void)closeFlv {
  if (_player) {
    [_player stop:true];
    _player = nil;
    [self clearView];
  }
}

-(void)openFlv:(NSString*) url {
  _player = [[RTCPlayer alloc] init:self];
  _player.id = _pid;
  if ([_player start:url]) {
    _player.playMode = _playMode;
    _player.statInterval = _statInterval;
    _player.jitter = _jitter;
    _player.cacheSize = _cacheSize;
    _player.paused = _paused;
    _player.muted = _muted;
    _player.mutedVideo = _mutedVideo;
    _player.speed = _rate;
    _player.volume = _volume;
  }
}

- (void)videoView:(id)videoView didChangeVideoSize:(CGSize)size {
    RCTLogInfo(@"%@ didChangeVideoSize %dx%d", _pid, (int)size.width, (int)size.height);
    // Capture the callback block to avoid accessing it across threads
    RCTDirectEventBlock callback = self.onDimensionsChange;
    if (callback) {
        NSDictionary *eventData = @{@"width" : @(size.width), @"height" : @(size.height)};

        dispatch_async(dispatch_get_main_queue(), ^{
            callback(eventData);
        });
    }
}

-(void)OnRenderFrame:(int) tsp width:(int) width height:(int) height {
  if(!_player) return ;
  RTCVideoFrame* frame = [_player getVideoFrame];
  if (frame) {
    [self.videoView renderFrame:frame];
  }
}

-(void)OnSeekDone:(int) msTime code:(int) code {
  NSLog(@"onSeekDone %d code %d", msTime, code);
  if (self.onSeekDone)
    self.onSeekDone(@{ @"time": @(msTime),
             @"code": @(code) });
}

-(void)OnStat:(int) jitter speed: (int) speed {
  // NSLog(@"onStat %d speed %d", jitter, speed);
  if (self.onStat && _player)
    self.onStat(@{@"jitter":@(jitter),
             @"speed":@(speed),
             @"position":@(_player.position) });
}

-(void)OnOpen:(NSString*) url {
  NSLog(@"onOpen %@", url);
  if (self.onOpen && _player)
    self.onOpen(@{@"url": url,
          @"duration":  @([_player duration]),
          @"cacheSize": @(_player.cacheSize),
          @"jitter":  @(_player.jitter),
          @"audio":[_player audio_param]?[_player audio_param]:@{},
          @"video":[_player video_param]?[_player video_param]:@{}
        });
}

-(void)OnClose:(int) conn {
  NSLog(@"onClose %d", conn);
  if (self.onEnd)
    self.onEnd(@{@"reason":@(conn)});
}

@end

@implementation RTCVideoViewManager

RCT_EXPORT_MODULE()

- (RCTView *)view {
    RTCVideoView *v = [[RTCVideoView alloc] init];
    v.module = [self.bridge moduleForName:@"WebRTCModule"];
    v.viewManager = self;
    v.clipsToBounds = YES;
    return v;
}

- (dispatch_queue_t)methodQueue {
    return dispatch_get_main_queue();
}

#pragma mark - View properties

RCT_EXPORT_VIEW_PROPERTY(mirror, BOOL)

/**
 * In the fashion of
 * https://www.w3.org/TR/html5/embedded-content-0.html#dom-video-videowidth
 * and https://www.w3.org/TR/html5/rendering.html#video-object-fit, resembles
 * the CSS style {@code object-fit}.
 */
RCT_CUSTOM_VIEW_PROPERTY(objectFit, NSString *, RTCVideoView) {
    NSString *fitStr = json;
    RTCVideoViewObjectFit fit =
        (fitStr && [fitStr isEqualToString:@"cover"]) ? RTCVideoViewObjectFitCover : RTCVideoViewObjectFitContain;

    view.objectFit = fit;
}

RCT_EXPORT_VIEW_PROPERTY(onDimensionsChange, RCTDirectEventBlock)

RCT_CUSTOM_VIEW_PROPERTY(streamURL, NSString *, RTCVideoView) {
    if (!json) {
        view.videoTrack = nil;
        [view closeFlv];
        return;
    }

    NSString *streamReactTag = json;
    WebRTCModule *module = view.module;

    dispatch_async(module.workerQueue, ^{
        RTCMediaStream *stream = [module streamForReactTag:streamReactTag];
        NSArray *videoTracks = stream ? stream.videoTracks : @[];
        RTCVideoTrack *videoTrack = [videoTracks firstObject];
        if (!videoTrack) {
          // RCTLogWarn(@"No video stream for react tag: %@", streamReactTag);
          dispatch_async(dispatch_get_main_queue(), ^{
            [view closeFlv];
            if (streamReactTag && streamReactTag.length > 0)
              [view openFlv:streamReactTag];
          });
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                view.videoTrack = videoTrack;
            });
        }
    });
}

RCT_CUSTOM_VIEW_PROPERTY(iosPIP, NSDictionary *, RTCVideoView) {
    if (@available(iOS 15.0, *)) {
        [view setPIPOptions:json];
    }
}

RCT_EXPORT_METHOD(startIOSPIP : (nonnull NSNumber *)reactTag) {
    if (@available(iOS 15.0, *)) {
        RCTUIManager *uiManager = [self.bridge moduleForClass:[RCTUIManager class]];
        [uiManager addUIBlock:^(RCTUIManager *uiManager, NSDictionary<NSNumber *, UIView *> *viewRegistry) {
            UIView *view = viewRegistry[reactTag];
            if (!view || ![view isKindOfClass:[RTCVideoView class]]) {
                RCTLogError(@"Cannot find RTCVideoView with tag #%@", reactTag);
                return;
            }
            [(RTCVideoView *)view startPIP];
        }];
    }
}

RCT_EXPORT_METHOD(stopIOSPIP : (nonnull NSNumber *)reactTag) {
    if (@available(iOS 15.0, *)) {
        RCTUIManager *uiManager = [self.bridge moduleForClass:[RCTUIManager class]];
        [uiManager addUIBlock:^(RCTUIManager *uiManager, NSDictionary<NSNumber *, UIView *> *viewRegistry) {
            UIView *view = viewRegistry[reactTag];
            if (!view || ![view isKindOfClass:[RTCVideoView class]]) {
                RCTLogError(@"Cannot find RTCVideoView with tag #%@", reactTag);
                return;
            }
            [(RTCVideoView *)view stopPIP];
        }];
    }
}

RCT_EXPORT_VIEW_PROPERTY(onOpen, RCTBubblingEventBlock)
RCT_EXPORT_VIEW_PROPERTY(onSeekDone, RCTBubblingEventBlock)
RCT_EXPORT_VIEW_PROPERTY(onEnd, RCTBubblingEventBlock)
RCT_EXPORT_VIEW_PROPERTY(onStat, RCTBubblingEventBlock)
RCT_EXPORT_VIEW_PROPERTY(statInterval, int);
RCT_EXPORT_VIEW_PROPERTY(jitter, int);
RCT_EXPORT_VIEW_PROPERTY(cacheSize, int);
RCT_EXPORT_VIEW_PROPERTY(playMode, int);
RCT_EXPORT_VIEW_PROPERTY(pid, NSString*);
RCT_EXPORT_VIEW_PROPERTY(volume, float);
RCT_EXPORT_VIEW_PROPERTY(rate, float);
RCT_EXPORT_VIEW_PROPERTY(paused, BOOL);
RCT_EXPORT_VIEW_PROPERTY(muted, BOOL);
RCT_EXPORT_VIEW_PROPERTY(mutedVideo, BOOL);

RCT_CUSTOM_VIEW_PROPERTY(seek, int, RTCVideoView) {
  if (view.player)
    [view.player seek: [RCTConvert int:json]];
}

RCT_CUSTOM_VIEW_PROPERTY(stop, int, RTCVideoView) {
  if (view.player)
    [view.player stop: [RCTConvert int:json]];
}

typedef void (^RTCVideoViewBlock)(RTCPlayer *view);
-(void) uiCall:(NSNumber*) reactTag check:(bool)check block:(RTCVideoViewBlock) block {
  [self.bridge.uiManager addUIBlock:^(RCTUIManager *uiManager, NSDictionary<NSNumber *,UIView *> *viewRegistry) {
    RTCVideoView *view =(RTCVideoView *) viewRegistry[reactTag];
      if (!view || ![view isKindOfClass:[RTCVideoView class]]) {
          RCTLogError(@"Cannot find NativeView with tag #%@", reactTag);
          if (check) {
            block(nil);
          }
          return;
      }
      block(view.player);
  }];
}

RCT_EXPORT_METHOD(stop:(nonnull NSNumber*) reactTag wait:(int)wait) {
  [self uiCall:reactTag check:false block:^(RTCPlayer* p) {
    if (p)
      [p stop:wait];
  }];
}

RCT_EXPORT_METHOD(seek:(nonnull NSNumber*) reactTag msTime:(int)msTime) {
  [self uiCall:reactTag check:false block:^(RTCPlayer* p) {
    if (p)
      [p seek:msTime];
  }];
}

RCT_EXPORT_METHOD(position:(nonnull NSNumber*) reactTag 
                  resolve: (RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject) {
  [self uiCall:reactTag check:true block:^(RTCPlayer* p){
    int ret = 0;
    if (p)
      ret = [p position];
    resolve([NSNumber numberWithInt:ret]);
  }];
}

+ (BOOL)requiresMainQueueSetup {
    return NO;
}

@end
