#import <map>
#import "WebRTC/RTCLogging.h"
#import "WebRTC/AudioUtil.h"
#import "RtcAudioUtil.h"
@implementation RtcAudioUtil

RCT_EXPORT_MODULE();

RCT_EXPORT_METHOD(ZipLog:(NSString*) path
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject){
  bool ret = RTCZipLog(path.UTF8String);
  return resolve([NSNumber numberWithBool:ret]);
}

RCT_EXPORT_METHOD(LogOut:(NSString*) tag
                  msg:(NSString*) msg){
  RTCLogOut(RTCLoggingSeverityInfo, tag.UTF8String, msg.UTF8String);
}

RCT_EXPORT_METHOD(FormatExt:(int) fmt
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject){
  resolve([AudioUtil FormatExt:fmt]);
}

RCT_EXPORT_METHOD(GetFormat:(NSString*) fmt
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject){
  resolve([NSNumber numberWithInt:[AudioUtil GetFormat:fmt]]);
}

RCT_EXPORT_METHOD(AudioEncOpen:(int) fmt
                  samplerate:(int) samplerate
                  channel:(int) channel
                  bitrate:(int) bitrate
                  resolve: (RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
  int ret = [AudioUtil AudioEncOpen:fmt samplerate:samplerate channel:channel bitrate:bitrate];
  resolve([NSNumber numberWithInt:ret]);
}

RCT_EXPORT_METHOD(AudioEncFrameSample:(int) eid
                  resolve: (RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
  int ret = [AudioUtil AudioEncFrameSample:eid];
  resolve([NSNumber numberWithInt:ret]);
}

RCT_EXPORT_METHOD(AudioEncode:(int) eid
                  pcm:(NSArray*) pcm
                  resolve: (RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
  int samples = [AudioUtil AudioEncFrameSample:eid];
  if (pcm.count < samples) {
    reject(@"size error", [NSString stringWithFormat:@"len < %d", samples], nil);
    return ;
  }
  
  bool isFloat = true;
  std::vector<short> p(samples);
  for (int i =0; i<samples; i++) {
    if ([pcm[i] floatValue]>1.0f) {
      isFloat = false;
      break;
    }
  }
  for (int i =0; i<samples; i++) {
    p[i] = isFloat ? [pcm[i] floatValue] * 32768 : [pcm[i] shortValue];
  }
  NSData* ret = [AudioUtil AudioEncode:eid pcm:p.data()];
  resolve([ret base64EncodedStringWithOptions:0]);
}

RCT_EXPORT_METHOD(WavSamplerate:(int)handle
                  resolve: (RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject) {
  resolve([NSNumber numberWithInt:[AudioUtil WavSamplerate:handle]]);
}

RCT_EXPORT_METHOD(WavChannels:(int)handle
                  resolve: (RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject) {
  resolve([NSNumber numberWithInt:[AudioUtil WavChannels:handle]]);
}

RCT_EXPORT_METHOD(WavTotalSamples:(int)handle
                  resolve: (RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject) {
  resolve([NSNumber numberWithInt:[AudioUtil WavTotalSamples:handle]]);
}

RCT_EXPORT_METHOD(WavOpen:(NSString*) path
                  channels:(int)channels
                  samplerate:(int) samplerate
                  resolve: (RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject) {
  int handle = [AudioUtil WavOpen:path channels:channels samplerate:samplerate];
  resolve([NSNumber numberWithInt:handle]);
}

RCT_EXPORT_METHOD(WavRead:(int) handle
                  samples:(int) samples
                  type:(int)type
                  resolve: (RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
  std::vector<short> buff(samples);
  int ret = [AudioUtil WavRead:handle pcm:buff.data() samples:samples];
  NSMutableArray* ary = [[NSMutableArray alloc] initWithCapacity:ret];
  for (int i = 0; i<ret; i++) {
    if (type == 0) {
      ary[i] = [NSNumber numberWithInt:buff[i]];
    }
    else{
      ary[i] = [NSNumber numberWithFloat:buff[i]/32768.0];
    }
  }
  resolve(ary);
}

RCT_EXPORT_METHOD(WavWrite:(int) handle
                  pcm:(NSArray*) pcm
                  type:(int)type
                  resolve: (RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
  int samples = pcm.count;
  std::vector<short> buff(samples);
  for (int i =0; i<samples; i++) {
    if (type == 0) {
      buff[i] = [pcm[i] shortValue];
    }
    else{
      buff[i] = [pcm[i] floatValue] * 32768;
    }
  }
  int ret = [AudioUtil WavWrite:handle pcm:buff.data() samples:samples];
  resolve([NSNumber numberWithInt:ret]);
}

RCT_EXPORT_METHOD(AudioEncClose:(int) handle)
{
  [AudioUtil AudioEncClose:handle];
}

RCT_EXPORT_METHOD(WavToMp3:(NSString*) src
                  mp3:(NSString*) mp3
                  bitrate:(int) bitrate
                  resolve: (RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
  int ret = [AudioUtil WavToMp3:src mp3:mp3 bitrate:bitrate];
  resolve([NSNumber numberWithInt:ret]);
}

RCT_EXPORT_METHOD(WavToAac:(NSString*) src
                  aac:(NSString*) aac
                  bitrate:(int) bitrate
                  resolve: (RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
  int ret = [AudioUtil WavToAac:src aac:aac bitrate:bitrate];
  resolve([NSNumber numberWithInt:ret]);
}

RCT_EXPORT_METHOD(AacToWav:(NSString*) src
                  wav:(NSString*) wav
                  resolve: (RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
  int ret = [AudioUtil AacToWav:src wav:wav];
  resolve([NSNumber numberWithInt:ret]);
}

RCT_EXPORT_METHOD(Mp3ToWav:(NSString*) src
                  wav:(NSString*) wav
                  resolve: (RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
  int ret = [AudioUtil Mp3ToWav:src wav:wav];
  resolve([NSNumber numberWithInt:ret]);
}

RCT_EXPORT_METHOD(FlacToWav:(NSString*) src
                  wav:(NSString*) wav
                  resolve: (RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
  int ret = [AudioUtil FlacToWav:src wav:wav];
  resolve([NSNumber numberWithInt:ret]);
}

RCT_EXPORT_METHOD(OggToWav:(NSString*) src
                  wav:(NSString*) wav
                  resolve: (RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
  int ret = [AudioUtil OggToWav:src wav:wav];
  resolve([NSNumber numberWithInt:ret]);
}

RCT_EXPORT_METHOD(WavToFmt:(NSString*) wav
                  wav:(NSString*) path
                  bitrate:(int) bitrate
                  fmt:(int) fmt
                  resolve: (RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
  int ret = [AudioUtil WavToFmt:wav dstPath:path bitrate:bitrate fmt:fmt];
  resolve([NSNumber numberWithInt:ret]);
}
@end

