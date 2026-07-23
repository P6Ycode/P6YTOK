#import "P6YDownloadManager.h"
#import "P6YManager.h"
#import <Photos/Photos.h>
#import <objc/runtime.h>

@interface P6YDownloadManager (FullQuality)
- (void)p6y_fullQuality_handleDownloadedFiles:(NSArray<NSURL *> *)files
                                         kind:(P6YMediaKind)kind
                                        title:(NSString *)title;
@end

@implementation P6YDownloadManager (FullQuality)

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Method original = class_getInstanceMethod(self, NSSelectorFromString(@"handleDownloadedFiles:kind:title:"));
        Method replacement = class_getInstanceMethod(self, @selector(p6y_fullQuality_handleDownloadedFiles:kind:title:));
        if (original && replacement) method_exchangeImplementations(original, replacement);
    });
}

- (void)p6y_fullQuality_handleDownloadedFiles:(NSArray<NSURL *> *)files
                                         kind:(P6YMediaKind)kind
                                        title:(NSString *)title {
    NSInteger destination = [P6YManager integerForKey:@"p6y_download_destination"];
    if (destination == 1 || kind == P6YMediaKindAudio || files.count == 0) {
        [self p6y_fullQuality_handleDownloadedFiles:files kind:kind title:title];
        return;
    }

    NSArray<NSURL *> *originalFiles = [files copy];
    void (^saveOriginalResources)(void) = ^{
        [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
            for (NSURL *fileURL in originalFiles) {
                if (![fileURL isFileURL]) continue;
                PHAssetCreationRequest *request = [PHAssetCreationRequest creationRequestForAsset];
                PHAssetResourceCreationOptions *options = [[PHAssetResourceCreationOptions alloc] init];
                options.originalFilename = fileURL.lastPathComponent;
                options.shouldMoveFile = NO;
                PHAssetResourceType resourceType = kind == P6YMediaKindVideo ? PHAssetResourceTypeVideo : PHAssetResourceTypePhoto;
                [request addResourceWithType:resourceType fileURL:fileURL options:options];
            }
        } completionHandler:^(BOOL success, NSError *error) {
            NSString *message = success ? (title.length ? title : @"Saved at full quality") : (error.localizedDescription ?: @"Could not save original media");
            [P6YManager showToast:message];
        }];
    };

    void (^finishAuthorization)(PHAuthorizationStatus) = ^(PHAuthorizationStatus status) {
        BOOL allowed = status == PHAuthorizationStatusAuthorized || status == PHAuthorizationStatusLimited;
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!allowed) {
                [P6YManager showToast:@"Photos permission is required"];
                return;
            }
            saveOriginalResources();
        });
    };

    if (@available(iOS 14, *)) {
        [PHPhotoLibrary requestAuthorizationForAccessLevel:PHAccessLevelAddOnly handler:finishAuthorization];
    } else {
        [PHPhotoLibrary requestAuthorization:finishAuthorization];
    }
}

@end
