#import "VideoFrameProcessor.h"
typedef NSObject<VideoFrameProcessorDelegate>* (^VideoFrameProcessorFactory)(void);
@interface ProcessorProvider : NSObject

+ (NSObject<VideoFrameProcessorDelegate> *)getProcessor:(NSString *)name;
+ (void)addProcessor:(VideoFrameProcessorFactory) factory forName:(NSString *)name;
+ (void)removeProcessor:(NSString *)name;

@end
