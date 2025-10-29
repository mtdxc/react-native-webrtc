#import <map>
#import "WebRTC/RTCLogging.h"
#import "WebRTC/AudioEngine.h"
#import "WebRTC/AudioUtil.h"
#import "RtcAudioEngineController.h"

@implementation RtcAudioEngineController

RCT_EXPORT_MODULE();

RCT_EXPORT_METHOD(cache:(NSString*) path
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject){
  bool ret = [AudioEngine cache:path];
  resolve([[NSNumber alloc] initWithInt:ret]);
}

RCT_EXPORT_METHOD(uncache:(NSString*) path
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject){
  bool ret = [AudioEngine uncache:path];
  resolve([[NSNumber alloc] initWithInt:ret]);
}

RCT_EXPORT_METHOD(isCached:(NSString*) path
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject){
  bool ret = [AudioEngine isCached:path];
  resolve([[NSNumber alloc] initWithInt:ret]);
}

RCT_EXPORT_METHOD(uncacheAll:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject){
  int ret = [AudioEngine uncacheAll];
  resolve([[NSNumber alloc] initWithInt:ret]);
}

RCT_EXPORT_METHOD(play2d:(NSString*) path
                  loop:(int) loop
                  vol:(float)vol
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject){
  int ret = [AudioEngine play2d:path loop:loop vol:vol];
  resolve([[NSNumber alloc] initWithInt:ret]);
}

RCT_EXPORT_METHOD(play:(NSString*) path
                  loop:(int) loop
                  vol:(float)vol
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject){
  int ret = [AudioEngine play:path loop:loop vol:vol];
  resolve([[NSNumber alloc] initWithInt:ret]);
}

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

RCT_EXPORT_METHOD(getMemCache:(int) audioId
                  resolve: (RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject){
  resolve([NSNumber numberWithInt:[AudioEngine getMemCache:audioId]]);
}

RCT_EXPORT_METHOD(fillMem2:(int) audioId
                  pcm:(NSArray*) pcm
                  type:(int)type
                  resolve: (RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject){
  int samples = pcm.count;
  std::vector<uint8_t> bytes(samples * (type?2:1));
  for (int i =0; i<samples; i++){
    if (type){
      short val = type == 3 ? [pcm[i] floatValue] * 32768 : [pcm[i] shortValue];
      bytes[2*i] = val & 0xFF;
      bytes[2*i + 1] = val >> 8 & 0xFF;
    }
    else{
      bytes[i] = [pcm[i] unsignedCharValue];
    }
  }
  int ret = [AudioEngine fillMem:audioId data:[NSData dataWithBytes: bytes.data() length:bytes.size()]];
  resolve([NSNumber numberWithInt:ret]);
}

RCT_EXPORT_METHOD(AudioEncClose:(int) handle){
  [AudioUtil AudioEncClose:handle];
}

RCT_EXPORT_METHOD(WavTpMp3:(NSString*) src
                  mp3:(NSString*) mp3
                  bitrate:(int) bitrate
                  resolve: (RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject){
  int ret = [AudioUtil WavToMp3:src mp3:mp3 bitrate:bitrate];
  resolve([NSNumber numberWithInt:ret]);
}

RCT_EXPORT_METHOD(WavToAac:(NSString*) src
                  aac:(NSString*) aac
                  bitrate:(int) bitrate
                  resolve: (RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject){
  int ret = [AudioUtil WavToAac:src aac:aac bitrate:bitrate];
  resolve([NSNumber numberWithInt:ret]);
}

RCT_EXPORT_METHOD(AacToWav:(NSString*) src
                  wav:(NSString*) wav
                  resolve: (RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject){
  int ret = [AudioUtil AacToWav:src wav:wav];
  resolve([NSNumber numberWithInt:ret]);
}

RCT_EXPORT_METHOD(Mp3ToWav:(NSString*) src
                  wav:(NSString*) wav
                  resolve: (RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject){
  int ret = [AudioUtil Mp3ToWav:src wav:wav];
  resolve([NSNumber numberWithInt:ret]);
}

RCT_EXPORT_METHOD(FlacToWav:(NSString*) src
                  wav:(NSString*) wav
                  resolve: (RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject){
  int ret = [AudioUtil FlacToWav:src wav:wav];
  resolve([NSNumber numberWithInt:ret]);
}

RCT_EXPORT_METHOD(playMem:(int) samplerate
                  channel:(int) channel
                  format:(int) fmt
                  vol:(float) vol
                  resolve: (RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject){
  int ret = [AudioEngine playMem:samplerate channel:channel fmt:fmt vol:vol];
  resolve([NSNumber numberWithInt:ret]);
}

RCT_EXPORT_METHOD(fillMem:(int) audioId
                  data: (NSString*) base64Data
                  resolve: (RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject){
  NSData* pcm = [[NSData alloc] initWithBase64EncodedString:base64Data options:0];
  int ret = [AudioEngine fillMem:audioId data:pcm];
  resolve([NSNumber numberWithInt:ret]);
}

RCT_EXPORT_METHOD(clearMem:(int) audioId
                  resolve: (RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject){
  int ret = [AudioEngine clearMem:audioId];
  resolve([NSNumber numberWithInt:ret]);
}

RCT_EXPORT_METHOD(getCacheDir:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject){
  NSString* ret = [AudioEngine GetCacheDir];
  resolve(ret);
}

RCT_EXPORT_METHOD(setCacheDir:(NSString*) path){
  [AudioEngine SetCacheDir: path];
}

RCT_EXPORT_METHOD(isFileExist:(NSString*) path
                  resolve :(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject){
  resolve([NSNumber numberWithBool:access(path.UTF8String, 0) == 0]);
}

RCT_EXPORT_METHOD(clearCache){
  [AudioEngine ClearCache];
}

RCT_EXPORT_METHOD(getFileDuration:(NSString*) path
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
  float ret = [AudioEngine getFileDuration:path];
  resolve([[NSNumber alloc] initWithFloat:ret]);
}

RCT_EXPORT_METHOD(setVolume:(int) audioId
                  vol:(float)vol){
  [AudioEngine setVolume:audioId vol:vol];
}

RCT_EXPORT_METHOD(setLoop:(int) audioId
                  val:(BOOL)val){
  [AudioEngine setLoop:audioId loop:val];
}

RCT_EXPORT_METHOD(paused:(int) audioId
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject){
  bool ret = [AudioEngine paused:audioId];
  resolve([NSNumber numberWithBool:ret]);
}

RCT_EXPORT_METHOD(pause:(int) audioId){
  [AudioEngine pause:audioId];
}

RCT_EXPORT_METHOD(resume:(int) audioId){
  [AudioEngine resume:audioId];
}

RCT_EXPORT_METHOD(stop:(int) audioId){
  [AudioEngine stop: audioId];
}

RCT_EXPORT_METHOD(stopAll){
  [AudioEngine stopAll];
}

RCT_EXPORT_METHOD(getDuration:(int) audioId
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject){
  float ret = [AudioEngine getDuration:audioId];
  resolve([[NSNumber alloc] initWithFloat:ret]);
}

RCT_EXPORT_METHOD(getState:(int) audioId
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject){
  int ret = [AudioEngine getState:audioId];
  resolve([[NSNumber alloc] initWithInt:ret]);
}

RCT_EXPORT_METHOD(speed:(int) audioId
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject){
  float ret = [AudioEngine getSpeed:audioId];
  resolve([[NSNumber alloc] initWithFloat:ret]);
}

RCT_EXPORT_METHOD(setSpeed:(int) audioId
                  time:(float) val
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject){
  bool ret = [AudioEngine setSpeed:audioId val:val];
  resolve([[NSNumber alloc] initWithInt:ret]);
}

RCT_EXPORT_METHOD(getCurrentTime:(int) audioId
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject){
  float ret = [AudioEngine getCurrentTime:audioId];
  resolve([[NSNumber alloc] initWithFloat:ret]);
}

RCT_EXPORT_METHOD(setCurrentTime:(int) audioId
                  time:(float) time
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject){
  float ret = [AudioEngine setCurrentTime:audioId pos:time];
  resolve([[NSNumber alloc] initWithFloat:ret]);
}

static std::map<int, RCTPromiseResolveBlock> finishMap;
void MyFinishCallback(int audioId, const char* path, void* agrs){
  if(finishMap.count(audioId)){
    RCTPromiseResolveBlock resolve = finishMap[audioId];
    resolve([[NSNumber alloc] initWithInt:audioId]);
    finishMap.erase(audioId);
  }
};
RCT_EXPORT_METHOD(setFinishCallback:(int) audioId
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject){
  if([AudioEngine setFinishCallback:audioId callback:MyFinishCallback args:nullptr]){
    finishMap[audioId] = resolve;
  }
}

static std::map<int, RCTPromiseResolveBlock> startedMap;
void MyStartCallback(int audioId, const char* path, void* args){
  if(startedMap.count(audioId)){
    RCTPromiseResolveBlock resolve = startedMap[audioId];
    resolve([[NSNumber alloc] initWithInt:audioId]);
    startedMap.erase(audioId);
  }
}

RCT_EXPORT_METHOD(setStartCallback:(int) audioId
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject){
  startedMap[audioId] = resolve;
  if(![AudioEngine setStartCallback:audioId callback:MyStartCallback args:nullptr]){
    startedMap.erase(audioId);
  }
}

static std::map<std::string, RCTPromiseResolveBlock> cachedMap;
void MyCachedCallback(int audioId, const char* path, void* args){
  if (cachedMap.count(path)){
    RCTPromiseResolveBlock resolve = cachedMap[path];
    resolve([NSString stringWithUTF8String:path]);
    cachedMap.erase(path);
  }
}

RCT_EXPORT_METHOD(setCachedCallback:(NSString*) path
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject){
  std::string p = path.UTF8String;
  cachedMap[p] = resolve;
  if(![AudioEngine setCachedCallback:path callback:MyCachedCallback args:nullptr]){
    cachedMap.erase(p);
  }
}
@end

