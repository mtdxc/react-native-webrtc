#if !TARGET_OS_OSX
#import <UIKit/UIKit.h>
#endif

#import <React/RCTBridge.h>
#import <React/RCTEventDispatcher.h>
#import <React/RCTLog.h>
#import <React/RCTUtils.h>
#import <WebRTC/RTCLogging.h>
#import "WebRTCModule+RTCPeerConnection.h"
#import "WebRTCModule.h"
#import "WebRTCModuleOptions.h"
#import "RotateVideoProcessor.h"
#import "ProcessorProvider.h"
#import "RTCBeautyFilter.h"

@interface WebRTCModule ()
@end

@implementation WebRTCModule

+ (BOOL)requiresMainQueueSetup {
    return NO;
}

- (void)dealloc {
    [_localTracks removeAllObjects];
    _localTracks = nil;
    [_localStreams removeAllObjects];
    _localStreams = nil;

    for (NSNumber *peerConnectionId in _peerConnections) {
        RTCPeerConnection *peerConnection = _peerConnections[peerConnectionId];
        peerConnection.delegate = nil;
        [peerConnection close];
    }
    [_peerConnections removeAllObjects];

    _peerConnectionFactory = nil;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        WebRTCModuleOptions *options = [WebRTCModuleOptions sharedInstance];
        id<RTCAudioDevice> audioDevice = options.audioDevice;
        id<RTCVideoDecoderFactory> decoderFactory = options.videoDecoderFactory;
        id<RTCVideoEncoderFactory> encoderFactory = options.videoEncoderFactory;
        NSDictionary *fieldTrials = options.fieldTrials;
        RTCLoggingSeverity loggingSeverity = options.loggingSeverity;

        // Initialize field trials.
        if (fieldTrials == nil) {
            // Fix for dual-sim connectivity:
            // https://bugs.chromium.org/p/webrtc/issues/detail?id=10966
            fieldTrials = @{kRTCFieldTrialUseNWPathMonitor : kRTCFieldTrialEnabledValue};
        }
        RTCInitFieldTrialDictionary(fieldTrials);

        // Initialize logging.
        RTCSetMinDebugLogLevel(loggingSeverity);
        NSString* writeDir = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
        RTCInitLog(writeDir.UTF8String, loggingSeverity, 8);
        [ProcessorProvider addProcessor:^{return [[RotateVideoProcessor alloc] init];} forName:@"rotate"];
        [ProcessorProvider addProcessor:^{return [[RTCBeautyFilter alloc] init:FALSE];} forName:@"gpupixel"];
        [ProcessorProvider addProcessor:^{return [[RTCBeautyFilter alloc] init:TRUE]; } forName:@"gpupixel_lite"];
#if 1
        RCTSetLogThreshold((RCTLogLevel)loggingSeverity);
        RCTSetLogFunction(^( RCTLogLevel level,
                             __unused RCTLogSource source,
                             NSString *fileName,
                             NSNumber *lineNumber,
                             NSString *message)
        {
          int aslLevel;
          switch(level) {
            case RCTLogLevelTrace:
              aslLevel = RTCLoggingSeverityVerbose;
              break;
            case RCTLogLevelInfo:
              aslLevel = RTCLoggingSeverityInfo;
              break;
            case RCTLogLevelWarning:
              aslLevel = RTCLoggingSeverityWarning;
              break;
            case RCTLogLevelError:
              aslLevel = RTCLoggingSeverityError;
              break;
            case RCTLogLevelFatal:
              aslLevel = RTCLoggingSeverityError;
              break;
          }
          if (fileName && lineNumber) {
            RTCLogFile(fileName.UTF8String, lineNumber.integerValue, aslLevel, "react", message.UTF8String);
          } else {
            RTCLogOut(aslLevel, "react", message.UTF8String);
          }
        });
#endif
        if (encoderFactory == nil) {
            encoderFactory = [[RTCDefaultVideoEncoderFactory alloc] init];
        }
        if (decoderFactory == nil) {
            decoderFactory = [[RTCDefaultVideoDecoderFactory alloc] init];
        }
        _encoderFactory = encoderFactory;
        _decoderFactory = decoderFactory;

        RCTLogInfo(@"Using video encoder factory: %@", NSStringFromClass([encoderFactory class]));
        RCTLogInfo(@"Using video decoder factory: %@", NSStringFromClass([decoderFactory class]));

        _peerConnectionFactory = [[RTCPeerConnectionFactory alloc] initWithEncoderFactory:encoderFactory
                                                                           decoderFactory:decoderFactory
                                                                              audioDevice:audioDevice];

        _peerConnections = [NSMutableDictionary new];
        _localStreams = [NSMutableDictionary new];
        _localTracks = [NSMutableDictionary new];

        dispatch_queue_attr_t attributes =
            dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL, QOS_CLASS_USER_INITIATED, -1);
        _workerQueue = dispatch_queue_create("WebRTCModule.queue", attributes);
    }

    return self;
}

- (RTCMediaStream *)streamForReactTag:(NSString *)reactTag {
    RTCMediaStream *stream = _localStreams[reactTag];
    if (!stream) {
        for (NSNumber *peerConnectionId in _peerConnections) {
            RTCPeerConnection *peerConnection = _peerConnections[peerConnectionId];
            stream = peerConnection.remoteStreams[reactTag];
            if (stream) {
                break;
            }
        }
    }
    return stream;
}

RCT_EXPORT_MODULE();

- (dispatch_queue_t)methodQueue {
    return _workerQueue;
}

- (NSArray<NSString *> *)supportedEvents {
    return @[
        kEventPeerConnectionSignalingStateChanged,
        kEventPeerConnectionStateChanged,
        kEventPeerConnectionOnRenegotiationNeeded,
        kEventPeerConnectionIceConnectionChanged,
        kEventPeerConnectionIceGatheringChanged,
        kEventPeerConnectionGotICECandidate,
        kEventPeerConnectionDidOpenDataChannel,
        kEventDataChannelDidChangeBufferedAmount,
        kEventDataChannelStateChanged,
        kEventDataChannelReceiveMessage,
        kEventMediaStreamTrackMuteChanged,
        kEventMediaStreamData,
        kEventMediaStreamTrackData,
        kEventMediaStreamTrackEnded,
        kEventPeerConnectionOnRemoveTrack,
        kEventPeerConnectionOnTrack
    ];
}

RCT_EXPORT_METHOD(loadRnNoiseModel : (NSString *)path
                  resolver : (RCTPromiseResolveBlock)resolve
                  rejecter : (RCTPromiseRejectBlock)reject) {
  resolve([NSNumber numberWithBool:[_peerConnectionFactory loadRnNoiseModel:path]]);
}

RCT_EXPORT_METHOD(setMicrophoneScale : (float)val
                  resolver : (RCTPromiseResolveBlock)resolve
                  rejecter : (RCTPromiseRejectBlock)reject) {
  resolve([NSNumber numberWithBool:[_peerConnectionFactory setMicrophoneScale:val]]);
}
RCT_EXPORT_METHOD(getMicrophoneScale : (RCTPromiseResolveBlock)resolve
                  rejecter : (RCTPromiseRejectBlock)reject) {
  resolve([NSNumber numberWithFloat:[_peerConnectionFactory getMicrophoneScale]]);
}
@end
