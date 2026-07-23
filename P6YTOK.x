#import "TikTokHeaders.h"

static NSString *const P6YTOKSettingsIdentifier = @"p6ytok_settings";

static UIViewController *P6YTopViewController(void) {
    UIWindow *window = nil;
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (scene.activationState != UISceneActivationStateForegroundActive || ![scene isKindOfClass:UIWindowScene.class]) {
            continue;
        }
        for (UIWindow *candidate in ((UIWindowScene *)scene).windows) {
            if (candidate.isKeyWindow) {
                window = candidate;
                break;
            }
        }
        if (window) break;
    }

    if (!window) {
        window = UIApplication.sharedApplication.windows.firstObject;
    }

    UIViewController *controller = window.rootViewController;
    while (controller.presentedViewController) {
        controller = controller.presentedViewController;
    }
    if ([controller isKindOfClass:UINavigationController.class]) {
        controller = ((UINavigationController *)controller).visibleViewController;
    }
    if ([controller isKindOfClass:UITabBarController.class]) {
        controller = ((UITabBarController *)controller).selectedViewController;
    }
    return controller;
}

static void P6YShowConfirmation(NSString *action, void (^confirmed)(void)) {
    UIViewController *presenter = P6YTopViewController();
    if (!presenter) {
        if (confirmed) confirmed();
        return;
    }

    NSString *message = [NSString stringWithFormat:@"Continue with %@?", action ?: @"this action"];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"P6YTOK"
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Confirm" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *button) {
        if (confirmed) confirmed();
    }]];
    [presenter presentViewController:alert animated:YES completion:nil];
}

%hook AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    BOOL result = %orig;
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;

    if (![defaults boolForKey:@"P6YTOKFirstRunCompleted"]) {
        [defaults setBool:YES forKey:@"hide_ads"];
        [defaults setBool:YES forKey:@"dw_videos"];
        [defaults setBool:YES forKey:@"dw_musics"];
        [defaults setBool:YES forKey:@"remove_elements_button"];
        [defaults setBool:YES forKey:@"copy_decription"];
        [defaults setBool:YES forKey:@"copy_video_link"];
        [defaults setBool:YES forKey:@"copy_music_link"];
        [defaults setBool:YES forKey:@"show_porgress_bar"];
        [defaults setBool:YES forKey:@"save_profile"];
        [defaults setBool:YES forKey:@"copy_profile_information"];
        [defaults setBool:YES forKey:@"extended_bio"];
        [defaults setBool:YES forKey:@"extendedComment"];
        [defaults setBool:YES forKey:@"P6YTOKFirstRunCompleted"];
        [defaults synchronize];
    }

    [BHIManager cleanCache];
    return result;
}

static BOOL P6YAuthenticationPresented = NO;

- (void)applicationDidBecomeActive:(UIApplication *)application {
    %orig;
    if (![BHIManager appLock] || P6YAuthenticationPresented) return;

    UIViewController *presenter = P6YTopViewController();
    if (!presenter) return;

    SecurityViewController *securityController = [SecurityViewController new];
    securityController.modalPresentationStyle = UIModalPresentationOverFullScreen;
    [presenter presentViewController:securityController animated:YES completion:nil];
    P6YAuthenticationPresented = YES;
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
    %orig;
    P6YAuthenticationPresented = NO;
}

%end

%hook TTKSettingsBaseCellPlugin

- (void)didSelectItemAtIndex:(NSInteger)index {
    if (![self.itemModel.identifier isEqualToString:P6YTOKSettingsIdentifier]) {
        %orig;
        return;
    }

    SettingsViewController *settingsController = [SettingsViewController new];
    UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:settingsController];
    navigationController.modalPresentationStyle = UIModalPresentationPageSheet;
    [P6YTopViewController() presentViewController:navigationController animated:YES completion:nil];
}

%end

%hook AWESettingsNormalSectionViewModel

- (void)viewDidLoad {
    %orig;
    if (![self.sectionIdentifier isEqualToString:@"account"]) return;

    for (id model in self.modelsArray) {
        if ([model respondsToSelector:@selector(itemModel)] && [[[model itemModel] identifier] isEqualToString:P6YTOKSettingsIdentifier]) {
            return;
        }
    }

    TTKSettingsBaseCellPlugin *pluginCell = [[%c(TTKSettingsBaseCellPlugin) alloc] initWithPluginContext:self.context];
    AWESettingItemModel *itemModel = [[%c(AWESettingItemModel) alloc] initWithIdentifier:P6YTOKSettingsIdentifier];
    itemModel.title = @"P6YTOK";
    itemModel.detail = @"P6YTOK settings";
    itemModel.iconImage = [UIImage systemImageNamed:@"gearshape.fill"];
    itemModel.type = 99;
    pluginCell.itemModel = itemModel;
    [self insertModel:pluginCell atIndex:0 animated:YES];
}

%end

%hook AWEAwemeModel

- (id)initWithDictionary:(id)dictionary error:(id *)error {
    id model = %orig;
    return [BHIManager hideAds] && self.isAds ? nil : model;
}

- (id)init {
    id model = %orig;
    return [BHIManager hideAds] && self.isAds ? nil : model;
}

- (BOOL)progressBarDraggable {
    return [BHIManager progressBar] || %orig;
}

- (BOOL)progressBarVisible {
    return [BHIManager progressBar] || %orig;
}

%end

%hook AWEFeedVideoButton

- (void)_onTouchUpInside {
    if ([BHIManager likeConfirmation] && [self.imageNameString isEqualToString:@"icon_home_like_before"]) {
        P6YShowConfirmation(@"like", ^{ %orig; });
        return;
    }
    %orig;
}

%end

%hook AWECommentPanelCell

- (void)likeButtonTapped {
    if ([BHIManager likeCommentConfirmation]) {
        P6YShowConfirmation(@"comment like", ^{ %orig; });
        return;
    }
    %orig;
}

- (void)dislikeButtonTapped {
    if ([BHIManager dislikeCommentConfirmation]) {
        P6YShowConfirmation(@"comment dislike", ^{ %orig; });
        return;
    }
    %orig;
}

%end

%hook AWEPlayInteractionUserAvatarElement

- (void)onFollowViewClicked:(id)sender {
    if ([BHIManager followConfirmation]) {
        P6YShowConfirmation(@"follow", ^{ %orig; });
        return;
    }
    %orig;
}

%end

%hook AWETextInputController

- (NSUInteger)maxLength {
    return [BHIManager extendedComment] ? 240 : %orig;
}

%end

%hook AWEProfileEditTextViewController

- (NSInteger)maxTextLength {
    return [BHIManager extendedBio] ? 222 : %orig;
}

%end

%hook SparkViewController

- (void)viewWillAppear:(BOOL)animated {
    if (![BHIManager alwaysOpenSafari]) {
        %orig;
        return;
    }

    NSURLComponents *components = [NSURLComponents componentsWithURL:self.originURL resolvingAgainstBaseURL:NO];
    NSString *externalURLString = nil;
    for (NSURLQueryItem *item in components.queryItems) {
        if ([item.name isEqualToString:@"url"]) {
            externalURLString = item.value;
            break;
        }
    }

    NSURL *externalURL = [NSURL URLWithString:externalURLString ?: @""];
    if (!externalURL || !externalURL.scheme.length) {
        %orig;
        return;
    }

    [UIApplication.sharedApplication openURL:externalURL options:@{} completionHandler:nil];
    [self didTapCloseButton];
}

%end
