#import "P6YDownloadManager.h"
#import "P6YManager.h"
#import <Photos/Photos.h>

@interface P6YDownloadJob : NSObject
@property (nonatomic, strong) NSURLSessionDownloadTask *task;
@property (nonatomic, assign) P6YMediaKind kind;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, assign) BOOL handleResult;
@property (nonatomic, copy, nullable) void (^completion)(NSURL * _Nullable fileURL, NSError * _Nullable error);
@end
@implementation P6YDownloadJob
@end

@interface P6YProgressOverlay : UIView
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UIProgressView *progressView;
@end

@implementation P6YProgressOverlay
- (instancetype)init {
    self = [super initWithFrame:CGRectZero];
    if (!self) return nil;
    self.backgroundColor = [UIColor colorWithWhite:0.02 alpha:0.96];
    self.layer.cornerRadius = 14;
    self.layer.borderWidth = 1;
    self.layer.borderColor = [UIColor colorWithRed:0.9 green:0 blue:0 alpha:1].CGColor;
    self.translatesAutoresizingMaskIntoConstraints = NO;

    _titleLabel = [[UILabel alloc] init];
    _titleLabel.textColor = UIColor.whiteColor;
    _titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
    _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:_titleLabel];

    _progressView = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
    _progressView.progressTintColor = [UIColor colorWithRed:0.9 green:0 blue:0 alpha:1];
    _progressView.trackTintColor = [UIColor colorWithWhite:0.22 alpha:1];
    _progressView.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:_progressView];

    [NSLayoutConstraint activateConstraints:@[
        [_titleLabel.topAnchor constraintEqualToAnchor:self.topAnchor constant:11],
        [_titleLabel.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:14],
        [_titleLabel.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-14],
        [_progressView.topAnchor constraintEqualToAnchor:_titleLabel.bottomAnchor constant:8],
        [_progressView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:14],
        [_progressView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-14],
        [_progressView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-12]
    ]];
    return self;
}
@end

@interface P6YDownloadManager () <NSURLSessionDownloadDelegate>
@property (nonatomic, strong) NSURLSession *session;
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, P6YDownloadJob *> *jobs;
@property (nonatomic, strong, nullable) P6YProgressOverlay *overlay;
@end

@implementation P6YDownloadManager

+ (instancetype)sharedManager {
    static P6YDownloadManager *manager;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ manager = [[self alloc] initPrivate]; });
    return manager;
}

- (instancetype)initPrivate {
    self = [super init];
    if (!self) return nil;
    _jobs = [NSMutableDictionary dictionary];
    NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
    configuration.timeoutIntervalForRequest = 45;
    configuration.timeoutIntervalForResource = 300;
    _session = [NSURLSession sessionWithConfiguration:configuration delegate:self delegateQueue:[NSOperationQueue mainQueue]];
    return self;
}

- (instancetype)init {
    return [P6YDownloadManager sharedManager];
}

- (void)downloadURL:(NSURL *)url kind:(P6YMediaKind)kind title:(NSString *)title {
    [self startDownloadURL:url kind:kind title:title handleResult:YES completion:nil];
}

- (void)startDownloadURL:(NSURL *)url
                    kind:(P6YMediaKind)kind
                   title:(NSString *)title
            handleResult:(BOOL)handleResult
              completion:(void (^ _Nullable)(NSURL * _Nullable, NSError * _Nullable))completion {
    if (!url) {
        [P6YManager showToast:@"Media URL is unavailable"];
        return;
    }
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setValue:@"Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15" forHTTPHeaderField:@"User-Agent"];
    NSURLSessionDownloadTask *task = [self.session downloadTaskWithRequest:request];
    P6YDownloadJob *job = [[P6YDownloadJob alloc] init];
    job.task = task;
    job.kind = kind;
    job.title = title.length ? title : @"Downloading";
    job.handleResult = handleResult;
    job.completion = completion;
    self.jobs[@(task.taskIdentifier)] = job;
    [self showProgressWithTitle:job.title progress:0];
    [task resume];
}

- (void)downloadImageURLs:(NSArray<NSURL *> *)urls title:(NSString *)title {
    if (urls.count == 0) {
        [P6YManager showToast:@"No photos were found"];
        return;
    }
    __block NSInteger remaining = urls.count;
    NSMutableArray<NSURL *> *files = [NSMutableArray arrayWithCapacity:urls.count];
    __weak typeof(self) weakSelf = self;
    [urls enumerateObjectsUsingBlock:^(NSURL *url, NSUInteger idx, __unused BOOL *stop) {
        NSString *itemTitle = [NSString stringWithFormat:@"%@ %lu/%lu", title.length ? title : @"Downloading photos", (unsigned long)idx + 1, (unsigned long)urls.count];
        [weakSelf startDownloadURL:url kind:P6YMediaKindImage title:itemTitle handleResult:NO completion:^(NSURL *fileURL, NSError *error) {
            if (fileURL && !error) [files addObject:fileURL];
            remaining -= 1;
            if (remaining == 0) {
                [weakSelf hideProgress];
                if (files.count == 0) {
                    [P6YManager showToast:@"Photo download failed"];
                } else {
                    [weakSelf handleDownloadedFiles:files kind:P6YMediaKindImage title:title];
                }
            }
        }];
    }];
}

- (void)handleImage:(UIImage *)image title:(NSString *)title {
    if (!image) return;
    if ([P6YManager integerForKey:@"p6y_download_destination"] == 1) {
        [self presentShareSheetWithItems:@[image]];
        return;
    }
    [self requestPhotoPermission:^(BOOL allowed) {
        if (!allowed) {
            [P6YManager showToast:@"Photos permission is required"];
            return;
        }
        [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
            [PHAssetChangeRequest creationRequestForAssetFromImage:image];
        } completionHandler:^(BOOL success, __unused NSError *error) {
            [P6YManager showToast:success ? (title.length ? title : @"Saved") : @"Could not save photo"];
        }];
    }];
}

- (NSString *)extensionForResponse:(NSURLResponse *)response kind:(P6YMediaKind)kind {
    NSString *extension = response.suggestedFilename.pathExtension.lowercaseString;
    if (extension.length > 0 && extension.length <= 5) return extension;

    NSString *mime = response.MIMEType.lowercaseString;
    NSDictionary *mimeExtensions = @{
        @"video/mp4": @"mp4", @"video/quicktime": @"mov",
        @"audio/mp4": @"m4a", @"audio/mpeg": @"mp3", @"audio/aac": @"aac",
        @"image/jpeg": @"jpg", @"image/png": @"png", @"image/webp": @"webp", @"image/heic": @"heic"
    };
    extension = mimeExtensions[mime];
    if (extension.length) return extension;
    if ([mime hasPrefix:@"video/"]) return @"mp4";
    if ([mime hasPrefix:@"audio/"]) return @"m4a";
    if ([mime hasPrefix:@"image/"]) return @"jpg";

    switch (kind) {
        case P6YMediaKindVideo: return @"mp4";
        case P6YMediaKindAudio: return @"m4a";
        case P6YMediaKindImage: return @"jpg";
    }
    return @"bin";
}

- (NSURL *)persistentURLForLocation:(NSURL *)location response:(NSURLResponse *)response kind:(P6YMediaKind)kind error:(NSError **)error {
    NSString *extension = [self extensionForResponse:response kind:kind];
    NSURL *directory = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:@"P6YTOK"] isDirectory:YES];
    [[NSFileManager defaultManager] createDirectoryAtURL:directory withIntermediateDirectories:YES attributes:nil error:nil];
    NSURL *destination = [directory URLByAppendingPathComponent:[NSString stringWithFormat:@"%@.%@", NSUUID.UUID.UUIDString, extension]];
    [[NSFileManager defaultManager] removeItemAtURL:destination error:nil];
    if (![[NSFileManager defaultManager] copyItemAtURL:location toURL:destination error:error]) return nil;
    return destination;
}

- (void)URLSession:(NSURLSession *)session
      downloadTask:(NSURLSessionDownloadTask *)downloadTask
      didWriteData:(int64_t)bytesWritten
 totalBytesWritten:(int64_t)totalBytesWritten
 totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite {
    if (totalBytesExpectedToWrite <= 0) return;
    P6YDownloadJob *job = self.jobs[@(downloadTask.taskIdentifier)];
    float progress = (float)totalBytesWritten / (float)totalBytesExpectedToWrite;
    [self showProgressWithTitle:job.title progress:progress];
}

- (void)URLSession:(NSURLSession *)session
      downloadTask:(NSURLSessionDownloadTask *)downloadTask
 didFinishDownloadingToURL:(NSURL *)location {
    NSNumber *key = @(downloadTask.taskIdentifier);
    P6YDownloadJob *job = self.jobs[key];
    if (!job) return;

    NSError *copyError = nil;
    NSURL *fileURL = [self persistentURLForLocation:location response:downloadTask.response kind:job.kind error:&copyError];
    [self.jobs removeObjectForKey:key];
    if (job.completion) job.completion(fileURL, copyError);
    if (!job.handleResult) return;

    [self hideProgress];
    if (!fileURL || copyError) {
        [P6YManager showToast:@"Download failed"];
        return;
    }
    [self handleDownloadedFiles:@[fileURL] kind:job.kind title:job.title];
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    if (!error) return;
    NSNumber *key = @(task.taskIdentifier);
    P6YDownloadJob *job = self.jobs[key];
    if (!job) return;
    [self.jobs removeObjectForKey:key];
    [self hideProgress];
    if (job.completion) job.completion(nil, error);
    if (job.handleResult) [P6YManager showToast:@"Download failed"];
}

- (void)handleDownloadedFiles:(NSArray<NSURL *> *)files kind:(P6YMediaKind)kind title:(NSString *)title {
    NSInteger destination = [P6YManager integerForKey:@"p6y_download_destination"];
    if (destination == 1 || kind == P6YMediaKindAudio) {
        [self presentShareSheetWithItems:files];
        return;
    }

    [self requestPhotoPermission:^(BOOL allowed) {
        if (!allowed) {
            [P6YManager showToast:@"Photos permission is required"];
            return;
        }
        [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
            for (NSURL *fileURL in files) {
                if (kind == P6YMediaKindVideo) {
                    [PHAssetChangeRequest creationRequestForAssetFromVideoAtFileURL:fileURL];
                } else if (kind == P6YMediaKindImage) {
                    NSData *data = [NSData dataWithContentsOfURL:fileURL];
                    UIImage *image = [UIImage imageWithData:data];
                    if (image) [PHAssetChangeRequest creationRequestForAssetFromImage:image];
                }
            }
        } completionHandler:^(BOOL success, __unused NSError *error) {
            [P6YManager showToast:success ? (title.length ? title : @"Saved") : @"Could not save media"];
        }];
    }];
}

- (void)requestPhotoPermission:(void (^)(BOOL allowed))completion {
    void (^finish)(PHAuthorizationStatus) = ^(PHAuthorizationStatus status) {
        BOOL allowed = status == PHAuthorizationStatusAuthorized || status == PHAuthorizationStatusLimited;
        dispatch_async(dispatch_get_main_queue(), ^{ completion(allowed); });
    };
    if (@available(iOS 14, *)) {
        [PHPhotoLibrary requestAuthorizationForAccessLevel:PHAccessLevelAddOnly handler:finish];
    } else {
        [PHPhotoLibrary requestAuthorization:finish];
    }
}

- (void)presentShareSheetWithItems:(NSArray *)items {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIViewController *controller = [P6YManager topViewController];
        if (!controller || items.count == 0) return;
        UIActivityViewController *share = [[UIActivityViewController alloc] initWithActivityItems:items applicationActivities:nil];
        share.view.tintColor = [UIColor colorWithRed:0.9 green:0 blue:0 alpha:1];
        if (share.popoverPresentationController) {
            share.popoverPresentationController.sourceView = controller.view;
            share.popoverPresentationController.sourceRect = CGRectMake(CGRectGetMidX(controller.view.bounds), CGRectGetMidY(controller.view.bounds), 1, 1);
        }
        [controller presentViewController:share animated:YES completion:nil];
    });
}

- (void)showProgressWithTitle:(NSString *)title progress:(float)progress {
    if (![P6YManager boolForKey:@"p6y_download_progress"]) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        UIViewController *controller = [P6YManager topViewController];
        UIView *host = controller.view;
        if (!host) return;
        if (!self.overlay || !self.overlay.superview) {
            self.overlay = [[P6YProgressOverlay alloc] init];
            [host addSubview:self.overlay];
            [NSLayoutConstraint activateConstraints:@[
                [self.overlay.leadingAnchor constraintEqualToAnchor:host.leadingAnchor constant:18],
                [self.overlay.trailingAnchor constraintEqualToAnchor:host.trailingAnchor constant:-18],
                [self.overlay.bottomAnchor constraintEqualToAnchor:host.safeAreaLayoutGuide.bottomAnchor constant:-18]
            ]];
        }
        self.overlay.titleLabel.text = title.length ? title : @"Downloading";
        [self.overlay.progressView setProgress:MAX(0, MIN(1, progress)) animated:YES];
    });
}

- (void)hideProgress {
    dispatch_async(dispatch_get_main_queue(), ^{
        [UIView animateWithDuration:0.2 animations:^{ self.overlay.alpha = 0; } completion:^(__unused BOOL finished) {
            [self.overlay removeFromSuperview];
            self.overlay = nil;
        }];
    });
}

@end
