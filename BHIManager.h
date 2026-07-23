#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface BHIManager : NSObject
+ (BOOL)hideAds;
+ (BOOL)downloadVideos;
+ (BOOL)downloadMusics;
+ (BOOL)hideElementButton;
+ (BOOL)copyVideoDecription;
+ (BOOL)copyMusicLink;
+ (BOOL)copyVideoLink;
+ (BOOL)progressBar;
+ (BOOL)likeConfirmation;
+ (BOOL)likeCommentConfirmation;
+ (BOOL)dislikeCommentConfirmation;
+ (BOOL)followConfirmation;
+ (BOOL)profileSave;
+ (BOOL)profileCopy;
+ (BOOL)alwaysOpenSafari;
+ (BOOL)extendedBio;
+ (BOOL)extendedComment;
+ (BOOL)appLock;
+ (void)showSaveVC:(id)item;
+ (void)cleanCache;
+ (BOOL)isEmpty:(NSURL *)url;
+ (NSString *)getDownloadingPersent:(float)progress;
@end
