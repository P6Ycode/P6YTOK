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
static NSString *p6yCompatLastVisibleControllerName = nil;

static NSUserDefaults *P6YCompatDefaults(void) {
    return [NSUserDefaults standardUserDefaults];
}

static BOOL P6YCompatDefaultBool(NSString *key, BOOL defaultValue) {
    id value = [P6YCompatDefaults() objectForKey:key];
    return value ? [value boolValue] : defaultValue;
}

static NSString *P6YCompatLower(NSString *value) {
    return value.length ? [value lowercaseString] : @"";
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
        @"sign",
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

    return P6YCompatNameContainsAny(className, @[
        @"tabbar",
        @"tabbarcontroller",
        @"feed",
        @"aweme",
        @"home",
        @"main",
        @"root",
        @"profile",
        @"inbox",
        @"discover"
    ]);
}

static UIViewController *P6YCompatTopViewControllerFrom(UIViewController *root) {
    UIViewController *candidate = root;
    while (candidate.presentedViewController) {
        candidate = candidate.presentedViewController;
    }

    if ([candidate isKindOfClass:[UINavigationController class]]) {
        return P6YCompatTopViewControllerFrom([(UINavigationController *)candidate topViewController]);
    }

    if ([candidate isKindOfClass:[UITabBarController class]]) {
        UIViewController *selected = [(UITabBarController *)candidate selectedViewController];
        if (selected) {
            return P6YCompatTopViewControllerFrom(selected);
        }
    }

    return candidate;
}

static UIViewController *P6YCompatVisibleController(void) {
    UIWindow *window = nil;

    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
            if (scene.activationState != UISceneActivationStateForegroundActive || ![scene isKindOfClass:[UIWindowScene class]]) {
                continue;
            }
            for (UIWindow *sceneWindow in ((UIWindowScene *)scene).windows) {
                if (sceneWindow.isKeyWindow) {
                    window = sceneWindow;
                    break;
                }
            }
            if (window) {
                break;
            }
        }
    }

    if (!window) {
        window = UIApplication.sharedApplication.keyWindow;
    }

    return P6YCompatTopViewControllerFrom(window.rootViewController);
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
    NSString *version = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    return version.length ? version : @"unknown";
}

BOOL P6YCompatLooksLikeInjectedIPA(void) {
    NSString *bundlePath = NSBundle.mainBundle.bundlePath ?: @"";
    BOOL hasEmbeddedProvision = [[NSFileManager defaultManager] fileExistsAtPath:[bundlePath stringByAppendingPathComponent:@"embedded.mobileprovision"]];
    BOOL isTikTokBundle = [NSBundle.mainBundle.bundleIdentifier.lowercaseString containsString:@"tiktok"] || [NSBundle.mainBundle.bundleIdentifier.lowercaseString containsString:@"musically"];

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
        case P6YCompatFeatureGroupSettings:
            return @"settings";
        case P6YCompatFeatureGroupDownloads:
            return @"downloads";
        case P6YCompatFeatureGroupFeedUI:
            return @"feed-ui";
        case P6YCompatFeatureGroupProfile:
            return @"profile";
        case P6YCompatFeatureGroupAdFiltering:
            return @"ad-filtering";
        case P6YCompatFeatureGroupBrowserRedirects:
            return @"browser-redirects";
    }
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
    return P6YCompatIsEnabled() && p6yCompatDelayedGroupsEnabled && !P6YCompatIsLoginSafeModeEnabled();
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
    P6YCompatLog(@"visible controller=%@ tiktok=%@ ipa=%@", className, P6YCompatTikTokVersion(), P6YCompatLooksLikeInjectedIPA() ? @"yes" : @"no");

    if (P6YCompatControllerLooksLikeLogin(className)) {
        p6yCompatLoginSafeMode = YES;
        [[NSNotificationCenter defaultCenter] postNotificationName:P6YCompatLoginSafeModeChangedNotification object:nil];
        return;
    }

    if (P6YCompatControllerLooksLikeMainApp(className)) {
        P6YCompatEnableFeatureGroupsIfReady();
    }
}

void P6YCompatEnableFeatureGroupsIfReady(void) {
    if (!P6YCompatIsEnabled() || p6yCompatDelayedGroupsEnabled) {
        return;
    }

    if (P6YCompatDefaultBool(kP6YCompatForceLoginSafeModeKey, NO)) {
        P6YCompatLog(@"login-safe mode forced; delayed feature groups remain off");
        return;
    }

    if (!P6YCompatDefaultBool(kP6YCompatManualFeatureEnableKey, NO)) {
        UIViewController *visible = P6YCompatVisibleController();
        NSString *className = visible ? NSStringFromClass(visible.class) : @"";
        if (!P6YCompatControllerLooksLikeMainApp(className)) {
            return;
        }
    }

    p6yCompatLoginSafeMode = NO;
    p6yCompatDelayedGroupsEnabled = YES;
    P6YCompatLog(@"delayed P6YTOK feature groups enabled after login-safe startup");

    [[NSNotificationCenter defaultCenter] postNotificationName:P6YCompatLoginSafeModeChangedNotification object:nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:P6YCompatDidEnableFeatureGroupsNotification object:nil];
}

void P6YCompatBootstrap(void) {
    if (p6yCompatBootstrapped) {
        return;
    }

    p6yCompatBootstrapped = YES;
    p6yCompatLog = os_log_create("com.p6ycode.p6ytok", "compat");
    p6yCompatLoginSafeMode = YES;
    p6yCompatDelayedGroupsEnabled = NO;

    P6YCompatLog(@"bootstrapped login-safe compat tiktok=%@ ipa=%@", P6YCompatTikTokVersion(), P6YCompatLooksLikeInjectedIPA() ? @"yes" : @"no");
}
