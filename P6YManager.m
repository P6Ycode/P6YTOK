#import "P6YManager.h"

@implementation P6YManager

+ (void)registerDefaults {
    NSDictionary *defaults = @{
        @"p6y_downloads_enabled": @YES,
        @"p6y_download_video": @YES,
        @"p6y_download_photos": @YES,
        @"p6y_download_music": @YES,
        @"p6y_copy_description": @YES,
        @"p6y_copy_video_link": @YES,
        @"p6y_copy_music_link": @YES,
        @"p6y_download_progress": @YES,
        @"p6y_download_destination": @0,

        @"p6y_hide_ads": @YES,
        @"p6y_pure_mode": @YES,
        @"p6y_transparent_comments": @NO,
        @"p6y_clean_links": @YES,
        @"p6y_disable_warnings": @NO,
        @"p6y_skip_recommendations": @NO,
        @"p6y_playback_action": @0,
        @"p6y_startup_page": @0,

        @"p6y_live_zoom": @YES,

        @"p6y_save_profile_photo": @YES,
        @"p6y_profile_follow_status": @NO,
        @"p6y_profile_video_count": @NO,
        @"p6y_profile_upload_date": @NO,
        @"p6y_profile_like_count": @NO,
        @"p6y_profile_unsensitive": @NO,
        @"p6y_extend_bio": @NO,
        @"p6y_extend_comment": @NO,

        @"p6y_confirm_like": @NO,
        @"p6y_confirm_comment_like": @NO,
        @"p6y_confirm_comment_dislike": @NO,
        @"p6y_confirm_follow": @NO,
    };

    NSUserDefaults *store = NSUserDefaults.standardUserDefaults;
    [store removeObjectForKey:@"p6y_app_lock"];
    [store registerDefaults:defaults];
}

+ (BOOL)boolForKey:(NSString *)key {
    if ([key isEqualToString:@"p6y_app_lock"]) return NO;
    return [NSUserDefaults.standardUserDefaults boolForKey:key];
}

+ (NSInteger)integerForKey:(NSString *)key {
    return [NSUserDefaults.standardUserDefaults integerForKey:key];
}

+ (UIViewController *)topViewController {
    UIWindow *window = nil;
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (scene.activationState != UISceneActivationStateForegroundActive || ![scene isKindOfClass:UIWindowScene.class]) continue;
        for (UIWindow *candidate in ((UIWindowScene *)scene).windows) {
            if (candidate.isKeyWindow) {
                window = candidate;
                break;
            }
        }
        if (window) break;
    }
    if (!window) window = UIApplication.sharedApplication.windows.firstObject;

    UIViewController *controller = window.rootViewController;
    while (controller.presentedViewController) controller = controller.presentedViewController;
    if ([controller isKindOfClass:UINavigationController.class]) {
        controller = ((UINavigationController *)controller).visibleViewController ?: controller;
    }
    if ([controller isKindOfClass:UITabBarController.class]) {
        controller = ((UITabBarController *)controller).selectedViewController ?: controller;
    }
    return controller;
}

+ (id)safeValueForKey:(NSString *)key fromObject:(id)object {
    if (!object || key.length == 0) return nil;
    @try {
        return [object valueForKey:key];
    } @catch (__unused NSException *exception) {
        return nil;
    }
}

+ (NSString *)sanitizedTikTokURLString:(NSString *)string {
    if (string.length == 0) return string;
    NSURLComponents *components = [NSURLComponents componentsWithString:string];
    NSString *host = components.host.lowercaseString;
    if (!components || (![host containsString:@"tiktok.com"] && ![host containsString:@"musical.ly"])) return string;

    NSSet<NSString *> *trackingKeys = [NSSet setWithArray:@[
        @"_r", @"_t", @"share_app_id", @"share_iid", @"share_link_id",
        @"u_code", @"ug_btm", @"ugbiz_name", @"timestamp", @"social_share_type",
        @"sender_device", @"sender_web_id", @"is_from_webapp", @"utm_source",
        @"utm_medium", @"utm_campaign", @"refer", @"referer_url"
    ]];
    NSMutableArray<NSURLQueryItem *> *cleanItems = [NSMutableArray array];
    for (NSURLQueryItem *item in components.queryItems ?: @[]) {
        if (![trackingKeys containsObject:item.name.lowercaseString]) [cleanItems addObject:item];
    }
    components.queryItems = cleanItems.count ? cleanItems : nil;
    return components.string ?: string;
}

+ (void)showToast:(NSString *)message {
    if (message.length == 0) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        UIViewController *controller = [self topViewController];
        UIView *host = controller.view;
        if (!host) return;

        UILabel *label = [[UILabel alloc] init];
        label.text = message;
        label.textColor = UIColor.whiteColor;
        label.backgroundColor = [UIColor colorWithWhite:0.03 alpha:0.94];
        label.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
        label.textAlignment = NSTextAlignmentCenter;
        label.numberOfLines = 3;
        label.layer.cornerRadius = 12;
        label.layer.borderWidth = 1;
        label.layer.borderColor = [UIColor colorWithRed:0.9 green:0 blue:0 alpha:1].CGColor;
        label.clipsToBounds = YES;
        label.translatesAutoresizingMaskIntoConstraints = NO;
        [host addSubview:label];
        [NSLayoutConstraint activateConstraints:@[
            [label.centerXAnchor constraintEqualToAnchor:host.centerXAnchor],
            [label.bottomAnchor constraintEqualToAnchor:host.safeAreaLayoutGuide.bottomAnchor constant:-24],
            [label.widthAnchor constraintLessThanOrEqualToAnchor:host.widthAnchor multiplier:0.86],
            [label.heightAnchor constraintGreaterThanOrEqualToConstant:44]
        ]];
        [UIView animateWithDuration:0.2 animations:^{ label.alpha = 1; } completion:^(__unused BOOL finished) {
            [UIView animateWithDuration:0.25 delay:1.8 options:UIViewAnimationOptionCurveEaseInOut animations:^{
                label.alpha = 0;
            } completion:^(__unused BOOL finished2) {
                [label removeFromSuperview];
            }];
        }];
    });
}

+ (void)presentConfirmationWithTitle:(NSString *)title
                               message:(NSString *)message
                                  from:(UIViewController *)controller
                             confirmed:(dispatch_block_t)confirmed {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIViewController *presenter = controller ?: [self topViewController];
        if (!presenter) return;
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
        alert.view.tintColor = [UIColor colorWithRed:0.9 green:0 blue:0 alpha:1];
        [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
        [alert addAction:[UIAlertAction actionWithTitle:@"Confirm" style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction *action) {
            if (confirmed) confirmed();
        }]];
        [presenter presentViewController:alert animated:YES completion:nil];
    });
}

+ (void)cleanTemporaryDownloads {
    NSURL *directory = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:@"P6YTOK"] isDirectory:YES];
    [NSFileManager.defaultManager removeItemAtURL:directory error:nil];
    [NSFileManager.defaultManager createDirectoryAtURL:directory withIntermediateDirectories:YES attributes:nil error:nil];
}

@end
