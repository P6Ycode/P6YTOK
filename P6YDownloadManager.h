#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, P6YMediaKind) {
    P6YMediaKindVideo,
    P6YMediaKindImage,
    P6YMediaKindAudio,
};

@interface P6YDownloadManager : NSObject
+ (instancetype)sharedManager;
- (void)downloadURL:(NSURL *)url kind:(P6YMediaKind)kind title:(NSString *)title;
- (void)downloadImageURLs:(NSArray<NSURL *> *)urls title:(NSString *)title;
- (void)handleImage:(UIImage *)image title:(NSString *)title;
@end

NS_ASSUME_NONNULL_END
