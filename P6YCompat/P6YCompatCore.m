#import "P6YCompatCore.h"
#import <os/log.h>

NSString * const P6YCompatDidEnableFeatureGroupsNotification = @"P6YCompatDidEnableFeatureGroupsNotification";
NSString * const P6YCompatLoginSafeModeChangedNotification = @"P6YCompatLoginSafeModeChangedNotification";

static NSString * const kP6YCompatEnabledKey = @"P6YCompatEnabled";
static NSString * const kP6YCompatForceLoginSafeModeKey = @"P6YCompatForceLoginSafeMode";
static NSString * const kP6YCompatManualFeatureEnableKey = @"P6YCompatManualFeatureEnable";
static NSString * const kP6YCompatDebugLoggingKey = @"P6YCompatDebugLogging";

static os_log_t p6yCompatLog;
static BOOL p6yCompatBootstrapped = NO;
static BOOL p6yCompatLoginSafeMode = YES;
static BOOL p6yCompatDelayedGroupsEnabled = NO;
static BOOL p6yCompatMainUIVerificationScheduled = NO;
static NSUInteger p6yCompatNavigationGeneration = 0;
static NSString *p6yCompatLastVisibleControllerName = nil;

static NSUserDefaults *P6YCompatDefaults(void) {
    return [NSUserDefaults standardUserDefaults];
}

static BOOL P6YCompatDefaultBool(NSString *key, BOOL defaultValue) {
    id value = [P6YCompatDefaults() objectForKey:key];
    return value ? [value boolValue] : defaultValue;
}

static NSString *P6YCompatLower(NSString *value) {
    return value.length ? value.lowercaseString : @"";
}

static BOOL P6YCompatNameContainsAny(NSString *name, NSArray<NSString *> *needles) {
    NSString *lower = P6YCompatLower(name);
    for (NSString *needle in needles) {
        if ([lower containsString:P6YCompatLower(needle)]) {
            return YES;
        }
    }
    return NO;
}

static BOOL P6YCompatControllerLooksLikeLogin(NSString *className) {
    return P6YCompatNameContainsAny(className, @[
        @"login",
        @"passport",
        @"auth",
        @"signin",
        @"signup",
        @"accountrecover",
        @"verify",
        @"captcha",
        @"onboarding",
        @"welcome"
    ]);
}

static BOOL P6YCompatControllerLooksLikeMainApp(NSString *className) {
    if (!className.length || P6YCompatControllerLooksLikeLogin(className)) {
        return NO;
    }

    // Avoid broad markers such as "root" and "main" because they can appear
    // in pre-login controller names.
    return P6YCompatNameContainsAny(className, @[
        @"tabbar",
        @"feed",
        @"aweme",
        @"homepage",
        @"foryou",
        @"following",
        @"profile",
        @"inbox",
        @"discover"
    ]);
}

static UIWindow *P6YCompatKeyWindow(void) {
    UIWindow *fallbackWindow = nil;

    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:[UIWindowScene class]]) {
            continue;
        }

        if (scene.activationState != UISceneActivationStateForegroundActive &&
            scene.activationState != UISceneActivationStateForegroundInactive) {
            continue;
        }

        for (UIWindow *window in ((UIWindowScene *)scene).windows) {
            if (window.isKeyWindow) {
                return window;
            }

            if (!fallbackWindow &&
                !window.hidden &&
                window.alpha > 0.0 &&
                window.windowLevel == UIWindowLevelNormal &&
                window.rootViewController != nil) {
                fallbackWindow = window;
            }
        }
    }

    return fallbackWindow;
}

static UIViewController *P6YCompatTopViewControllerFrom(UIViewController *root) {
    if (!root) {
        return nil;
    }

    UIViewController *candidate = root;
    while (candidate.presentedViewController) {
        candidate = candidate.presentedViewController;
    }

    if ([candidate isKindOfClass:[UINavigationController class]]) {
        return P6YCompatTopViewControllerFrom(((UINavigationController *)candidate).topViewController);
    }

    if ([candidate isKindOfClass:[UITabBarController class]]) {
        UIViewController *selected = ((UITabBarController *)candidate).selectedViewController;
        if (selected) {
            return P6YCompatTopViewControllerFrom(selected);
        }
    }

    return candidate;
}

static BOOL P6YCompatControllerTreeContainsTabBar(UIViewController *controller) {
    if (!controller) {
        return NO;
    }

    if ([controller isKindOfClass:[UITabBarController class]]) {
        return ((UITabBarController *)controller).viewControllers.count >= 2;
    }

    if (controller.presentedViewController &&
        P6YCompatControllerTreeContainsTabBar(controller.presentedViewController)) {
        return YES;
    }

    for (UIViewController *child in controller.children) {
        if (P6YCompatControllerTreeContainsTabBar(child)) {
            return YES;
        }
    }

    return NO;
}

static UIViewController *P6YCompatVisibleController(void) {
    return P6YCompatTopViewControllerFrom(P6YCompatKeyWindow().rootViewController);
}

static BOOL P6YCompatMainUIIsStable(void) {
    if (UIApplication.sharedApplication.applicationState != UIApplicationStateActive) {
        return NO;
    }

    UIWindow *window = P6YCompatKeyWindow();
    UIViewController *visible = P6YCompatTopViewControllerFrom(window.rootViewController);
    NSString *className = visible ? NSStringFromClass(visible.class) : @"";

    if (!P6YCompatControllerLooksLikeMainApp(className)) {
        return NO;
    }

    BOOL hasTabBar = P6YCompatControllerTreeContainsTabBar(window.rootViewController);
    BOOL strongFeedMarker = P6YCompatNameContainsAny(className, @[
        @"feed",
        @"aweme",
        @"foryou",
        @"following"
    ]);

    return hasTabBar || strongFeedMarker;
}

void P6YCompatLog(NSString *format, ...) {
    if (!P6YCompatDefaultBool(kP6YCompatDebugLoggingKey, YES)) {
        return;
    }

    va_list args;
    va_start(args, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);

    if (!p6yCompatLog) {
        p6yCompatLog = os_log_create("com.p6ycode.p6ytok", "compat");
    }

    os_log_info(p6yCompatLog, "%{public}@", message);
}

NSString *P6YCompatTikTokVersion(void) {
    NSString *version = [NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    return version.length ? version : @"unknown";
}

BOOL P6YCompatLooksLikeInjectedIPA(void) {
    NSString *bundlePath = NSBundle.mainBundle.bundlePath ?: @"";
    BOOL hasEmbeddedProvision = [NSFileManager.defaultManager fileExistsAtPath:[bundlePath stringByAppendingPathComponent:@"embedded.mobileprovision"]];
    NSString *bundleIdentifier = NSBundle.mainBundle.bundleIdentifier.lowercaseString ?: @"";
    BOOL isTikTokBundle = [bundleIdentifier containsString:@"tiktok"] || [bundleIdentifier containsString:@"musically"];
    return isTikTokBundle && hasEmbeddedProvision;
}

BOOL P6YCompatClassExists(NSString *className) {
    return NSClassFromString(className) != Nil;
}

BOOL P6YCompatInstanceSelectorExists(NSString *className, SEL selector) {
    Class cls = NSClassFromString(className);
    return cls && [cls instancesRespondToSelector:selector];
}

BOOL P6YCompatClassSelectorExists(NSString *className, SEL selector) {
    Class cls = NSClassFromString(className);
    return cls && [cls respondsToSelector:selector];
}

NSString *P6YCompatFeatureGroupName(P6YCompatFeatureGroup group) {
    switch (group) {
        case P6YCompatFeatureGroupSettings: return @"settings";
        case P6YCompatFeatureGroupDownloads: return @"downloads";
        case P6YCompatFeatureGroupFeedUI: return @"feed-ui";
        case P6YCompatFeatureGroupProfile: return @"profile";
        case P6YCompatFeatureGroupAdFiltering: return @"ad-filtering";
        case P6YCompatFeatureGroupBrowserRedirects: return @"browser-redirects";
    }
    return @"unknown";
}

BOOL P6YCompatIsEnabled(void) {
    return P6YCompatDefaultBool(kP6YCompatEnabledKey, YES);
}

BOOL P6YCompatIsLoginSafeModeEnabled(void) {
    if (!P6YCompatIsEnabled()) {
        return NO;
    }
    if (P6YCompatDefaultBool(kP6YCompatForceLoginSafeModeKey, NO)) {
        return YES;
    }
    return p6yCompatLoginSafeMode;
}

BOOL P6YCompatAreDelayedFeatureGroupsEnabled(void) {
    return P6YCompatIsEnabled() &&
           p6yCompatDelayedGroupsEnabled &&
           !P6YCompatIsLoginSafeModeEnabled();
}

BOOL P6YCompatShouldRunFeatureGroup(P6YCompatFeatureGroup group) {
    if (!P6YCompatAreDelayedFeatureGroupsEnabled()) {
        return NO;
    }

    NSString *key = [NSString stringWithFormat:@"P6YCompatGroup.%@.enabled", P6YCompatFeatureGroupName(group)];
    return P6YCompatDefaultBool(key, YES);
}

void P6YCompatObserveViewController(UIViewController *viewController) {
    if (!viewController || !P6YCompatIsEnabled()) {
        return;
    }

    NSString *className = NSStringFromClass(viewController.class);
    if ([className isEqualToString:p6yCompatLastVisibleControllerName]) {
        return;
    }

    p6yCompatLastVisibleControllerName = className;
    p6yCompatNavigationGeneration += 1;
    NSUInteger observedGeneration = p6yCompatNavigationGeneration;

    P6YCompatLog(@"visible controller=%@ tiktok=%@ ipa=%@",
                 className,
                 P6YCompatTikTokVersion(),
                 P6YCompatLooksLikeInjectedIPA() ? @"yes" : @"no");

    if (P6YCompatControllerLooksLikeLogin(className)) {
        p6yCompatLoginSafeMode = YES;
        p6yCompatMainUIVerificationScheduled = NO;
        [NSNotificationCenter.defaultCenter postNotificationName:P6YCompatLoginSafeModeChangedNotification object:nil];
        return;
    }

    if (!P6YCompatControllerLooksLikeMainApp(className) || p6yCompatMainUIVerificationScheduled) {
        return;
    }

    p6yCompatMainUIVerificationScheduled = YES;
    P6YCompatLog(@"main UI candidate observed; verifying after grace period: %@", className);

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        p6yCompatMainUIVerificationScheduled = NO;

        if (observedGeneration != p6yCompatNavigationGeneration) {
            P6YCompatLog(@"main UI verification cancelled because navigation changed");
            return;
        }

        if (!P6YCompatMainUIIsStable()) {
            UIViewController *visible = P6YCompatVisibleController();
            P6YCompatLog(@"main UI verification rejected: %@",
                         visible ? NSStringFromClass(visible.class) : @"none");
            return;
        }

        P6YCompatEnableFeatureGroupsIfReady();
    });
}

void P6YCompatEnableFeatureGroupsIfReady(void) {
    if (!P6YCompatIsEnabled() || p6yCompatDelayedGroupsEnabled) {
        return;
    }

    if (P6YCompatDefaultBool(kP6YCompatForceLoginSafeModeKey, NO)) {
        P6YCompatLog(@"login-safe mode forced; delayed feature payload remains off");
        return;
    }

    if (!P6YCompatDefaultBool(kP6YCompatManualFeatureEnableKey, NO) &&
        !P6YCompatMainUIIsStable()) {
        return;
    }

    p6yCompatLoginSafeMode = NO;
    p6yCompatDelayedGroupsEnabled = YES;
    P6YCompatLog(@"delayed P6YTOK feature payload enabled after verified main UI");

    [NSNotificationCenter.defaultCenter postNotificationName:P6YCompatLoginSafeModeChangedNotification object:nil];
    [NSNotificationCenter.defaultCenter postNotificationName:P6YCompatDidEnableFeatureGroupsNotification object:nil];
}

void P6YCompatBootstrap(void) {
    if (p6yCompatBootstrapped) {
        return;
    }

    p6yCompatBootstrapped = YES;
    p6yCompatLog = os_log_create("com.p6ycode.p6ytok", "compat");
    p6yCompatLoginSafeMode = YES;
    p6yCompatDelayedGroupsEnabled = NO;
    p6yCompatMainUIVerificationScheduled = NO;
    p6yCompatNavigationGeneration = 0;

    P6YCompatLog(@"bootstrapped login-safe compat tiktok=%@ ipa=%@",
                 P6YCompatTikTokVersion(),
                 P6YCompatLooksLikeInjectedIPA() ? @"yes" : @"no");
}
