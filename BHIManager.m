#import "BHIManager.h"

@implementation BHIManager

+ (BOOL)preferenceForKey:(NSString *)key {
    return [NSUserDefaults.standardUserDefaults boolForKey:key];
}

+ (BOOL)hideAds { return [self preferenceForKey:@"hide_ads"]; }
+ (BOOL)downloadVideos { return [self preferenceForKey:@"dw_videos"]; }
+ (BOOL)downloadMusics { return [self preferenceForKey:@"dw_musics"]; }
+ (BOOL)hideElementButton { return [self preferenceForKey:@"remove_elements_button"]; }
+ (BOOL)copyVideoDecription { return [self preferenceForKey:@"copy_decription"]; }
+ (BOOL)copyMusicLink { return [self preferenceForKey:@"copy_music_link"]; }
+ (BOOL)copyVideoLink { return [self preferenceForKey:@"copy_video_link"]; }
+ (BOOL)progressBar { return [self preferenceForKey:@"show_porgress_bar"]; }
+ (BOOL)likeConfirmation { return [self preferenceForKey:@"like_confirm"]; }
+ (BOOL)likeCommentConfirmation { return [self preferenceForKey:@"like_comment_confirm"]; }
+ (BOOL)dislikeCommentConfirmation { return [self preferenceForKey:@"dislike_comment_confirm"]; }
+ (BOOL)followConfirmation { return [self preferenceForKey:@"follow_confirm"]; }
+ (BOOL)profileSave { return [self preferenceForKey:@"save_profile"]; }
+ (BOOL)profileCopy { return [self preferenceForKey:@"copy_profile_information"]; }
+ (BOOL)alwaysOpenSafari { return [self preferenceForKey:@"openInBrowser"]; }
+ (BOOL)extendedBio { return [self preferenceForKey:@"extended_bio"]; }
+ (BOOL)extendedComment { return [self preferenceForKey:@"extendedComment"]; }
+ (BOOL)appLock { return [self preferenceForKey:@"padlock"]; }

+ (NSURL *)cacheDirectory {
    NSURL *baseURL = [NSFileManager.defaultManager URLsForDirectory:NSCachesDirectory inDomains:NSUserDomainMask].firstObject;
    return [baseURL URLByAppendingPathComponent:@"P6YTOK" isDirectory:YES];
}

+ (void)cleanCache {
    NSURL *cacheURL = [self cacheDirectory];
    [NSFileManager.defaultManager removeItemAtURL:cacheURL error:nil];
    [NSFileManager.defaultManager createDirectoryAtURL:cacheURL
                           withIntermediateDirectories:YES
                                            attributes:nil
                                                 error:nil];
}

+ (BOOL)isEmpty:(NSURL *)url {
    NSArray *contents = [NSFileManager.defaultManager contentsOfDirectoryAtURL:url
                                                   includingPropertiesForKeys:@[]
                                                                      options:NSDirectoryEnumerationSkipsHiddenFiles
                                                                        error:nil];
    return contents.count == 0;
}

+ (void)showSaveVC:(id)item {
    if (!item) return;

    NSArray *items = [item isKindOfClass:NSArray.class] ? item : @[item];
    UIActivityViewController *activityController = [[UIActivityViewController alloc] initWithActivityItems:items applicationActivities:nil];

    UIWindow *window = UIApplication.sharedApplication.windows.firstObject;
    UIViewController *presenter = window.rootViewController;
    while (presenter.presentedViewController) {
        presenter = presenter.presentedViewController;
    }

    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        activityController.popoverPresentationController.sourceView = presenter.view;
        activityController.popoverPresentationController.sourceRect = CGRectMake(CGRectGetMidX(presenter.view.bounds), CGRectGetMidY(presenter.view.bounds), 1.0, 1.0);
    }

    [presenter presentViewController:activityController animated:YES completion:nil];
}

+ (NSString *)getDownloadingPersent:(float)progress {
    NSNumberFormatter *formatter = [NSNumberFormatter new];
    formatter.numberStyle = NSNumberFormatterPercentStyle;
    return [formatter stringFromNumber:@(progress)];
}

@end
