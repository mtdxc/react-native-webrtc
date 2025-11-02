#import "ProcessorProvider.h"

@implementation ProcessorProvider

static NSMutableDictionary<NSString *, VideoFrameProcessorFactory> *processorMap;

+ (void)initialize {
    processorMap = [[NSMutableDictionary alloc] init];
}

+ (NSObject<VideoFrameProcessorDelegate> *)getProcessor:(NSString *)name {
  VideoFrameProcessorFactory factory = [processorMap objectForKey:name];
  if (factory) return factory();
  return nil;
}

+ (void)addProcessor:(VideoFrameProcessorFactory)facotry forName:(NSString *)name {
    [processorMap setObject:facotry forKey:name];
}

+ (void)removeProcessor:(NSString *)name {
    [processorMap removeObjectForKey:name];
}

@end
