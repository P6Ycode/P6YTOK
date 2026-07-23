#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import "P6YManager.h"
#import "P6YDownloadManager.h"
#import "SettingsViewController.h"

@interface AppDelegate : NSObject <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@end

@interface AWESettingItemModel : NSObject
@property (nonatomic, copy) NSString *identifier;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *detail;
@property (nonatomic, strong) UIImage *iconImage;
@property (nonatomic, assign) NSInteger type;
- (instancetype)initWithIdentifier:(NSString *)identifier;
@end

@interface TTKSettingsBaseCellPlugin : NSObject
@property (nonatomic, weak) id context;
@property (nonatomic, strong) AWESettingItemModel *itemModel;
- (instancetype)initWithPluginContext:(id)context;
@end

@interface AWEBaseListSectionViewModel : NSObject
@property (nonatomic, copy) NSArray *modelsArray;
- (void)insertModel:(id)model atIndex:(NSInteger)index animated:(BOOL)animated;
@end

@interface AWESettingsNormalSectionViewModel : AWEBaseListSectionViewModel
@property (nonatomic, weak) id context;
@property (nonatomic, copy) NSString *sectionIdentifier;
@end

static const NSInteger P6YDownloadButtonTag = 46001;
static const NSInteger P6YPureButtonTag = 46002;
static const NSInteger P6YProfileBadgeTag = 46010;
static const NSInteger P6YProfileDateTag = 46021;
static const NSInteger P6YProfileLikesTag = 46022;
static const void *P6YLikeBypassKey = &P6YLikeBypassKey;
static const void *P6YCommentLikeBypassKey = &P6YCommentLikeBypassKey;
static const void *P6YCommentDislikeBypassKey = &P6YCommentDislikeBypassKey;
static const void *P6YFollowBypassKey = &P6YFollowBypassKey;
static const void *P6YStartupAppliedKey = &P6YStartupAppliedKey;

static id P6YGet(id object, NSString *key) {
    return [P6YManager safeValueForKey:key fromObject:object];
}

static BOOL P6YResponds(id object, NSString *selectorName) {
    return object && [object respondsToSelector:NSSelectorFromString(selectorName)];
}

static BOOL P6YSendBool(id object, NSString *selectorName) {
    SEL selector = NSSelectorFromString(selectorName);
    if (!object || ![object respondsToSelector:selector]) return NO;
    return ((BOOL (*)(id, SEL))objc_msgSend)(object, selector);
}

static id P6YSendObject(id object, NSString *selectorName) {
    SEL selector = NSSelectorFromString(selectorName);
    if (!object || ![object respondsToSelector:selector]) return nil;
    return ((id (*)(id, SEL))objc_msgSend)(object, selector);
}

static NSURL *P6YBestURLFromURLModel(id urlModel) {
    if (!urlModel) return nil;
    NSArray *items = P6YGet(urlModel, @"originURLList");
    if (![items isKindOfClass:[NSArray class]] || items.count == 0) items = P6YGet(urlModel, @"URLList");
    if (![items isKindOfClass:[NSArray class]]) return nil;

    NSURL *fallback = nil;
    for (id item in items) {
        NSURL *url = nil;
        if ([item isKindOfClass:[NSURL class]]) url = item;
        if ([item isKindOfClass:[NSString class]]) url = [NSURL URLWithString:item];
        if (!url) continue;
        if (!fallback) fallback = url;
        NSString *lower = url.absoluteString.lowercaseString;
        if ([lower containsString:@".m3u8"]) continue;
        if ([lower containsString:@"video_mp4"] || [lower containsString:@".mp4"] || [lower containsString:@".jpeg"] || [lower containsString:@".jpg"] || [lower containsString:@".png"] || [lower containsString:@".webp"] || [lower containsString:@".m4a"] || [lower containsString:@".mp3"]) {
            return url;
        }
        fallback = url;
    }
    return fallback;
}

static id P6YModelFromCell(id cell) {
    id controller = P6YGet(cell, @"viewController");
    id model = P6YGet(controller, @"model");
    if (!model) model = P6YGet(controller, @"currentPlayingStory");
    if (!model) model = P6YGet(controller, @"currentAweme");
    if (!model) model = P6YGet(controller, @"currentPlayingAweme");
    return model;
}

static id P6YVideoModel(id model) {
    return P6YGet(model, @"video");
}

static NSURL *P6YVideoURL(id model) {
    id video = P6YVideoModel(model);
    NSArray<NSString *> *keys = @[@"playURL", @"h264URL", @"h264DownloadURL", @"downloadURL"];
    for (NSString *key in keys) {
        NSURL *url = P6YBestURLFromURLModel(P6YGet(video, key));
        if (url) return url;
    }
    return nil;
}

static id P6YMusicModel(id model) {
    id music = P6YGet(model, @"music");
    if (!music) music = P6YSendObject(model, @"getMusicModel");
    return music;
}

static NSURL *P6YMusicURL(id model) {
    id music = P6YMusicModel(model);
    NSURL *url = P6YBestURLFromURLModel(P6YGet(music, @"playURL"));
    if (!url) url = P6YBestURLFromURLModel(P6YGet(music, @"fullSongPlayURL"));
    return url;
}

static NSArray<NSURL *> *P6YPhotoURLs(id model) {
    id album = P6YGet(model, @"photoAlbum");
    NSArray *photos = P6YGet(album, @"photos");
    if (![photos isKindOfClass:[NSArray class]]) return @[];
    NSMutableArray<NSURL *> *urls = [NSMutableArray array];
    for (id photo in photos) {
        NSURL *url = P6YBestURLFromURLModel(P6YGet(photo, @"originPhotoURL"));
        if (url) [urls addObject:url];
    }
    return urls;
}

static NSString *P6YDescriptionForModel(id model) {
    NSArray<NSString *> *keys = @[@"modernFeedDescriptionString", @"descriptionString", @"music_songName"];
    for (NSString *key in keys) {
        id value = P6YGet(model, key);
        if ([value isKindOfClass:[NSString class]] && [value length]) return value;
    }
    return @"TikTok media";
}

static void P6YCopyString(NSString *string, NSString *successMessage) {
    if (string.length == 0) {
        [P6YManager showToast:@"Nothing to copy"];
        return;
    }
    if ([P6YManager boolForKey:@"p6y_clean_links"]) string = [P6YManager sanitizedTikTokURLString:string];
    [UIPasteboard generalPasteboard].string = string;
    [P6YManager showToast:successMessage];
}

static void P6YPresentMediaMenu(id cell) {
    id model = P6YModelFromCell(cell);
    if (!model) {
        [P6YManager showToast:@"P6YTOK could not read this post"];
        return;
    }

    NSURL *videoURL = P6YVideoURL(model);
    NSURL *musicURL = P6YMusicURL(model);
    NSArray<NSURL *> *photoURLs = P6YPhotoURLs(model);
    NSString *description = P6YDescriptionForModel(model);
    UIViewController *presenter = [P6YManager topViewController];
    if (!presenter) return;

    UIAlertController *menu = [UIAlertController alertControllerWithTitle:@"P6YTOK" message:description preferredStyle:UIAlertControllerStyleActionSheet];
    menu.view.tintColor = [UIColor colorWithRed:0.9 green:0 blue:0 alpha:1];

    if ([P6YManager boolForKey:@"p6y_download_video"] && videoURL) {
        [menu addAction:[UIAlertAction actionWithTitle:@"Download Video" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
            [[P6YDownloadManager sharedManager] downloadURL:videoURL kind:P6YMediaKindVideo title:@"Video saved"];
        }]];
    }
    if ([P6YManager boolForKey:@"p6y_download_photos"] && photoURLs.count) {
        NSString *title = photoURLs.count > 1 ? [NSString stringWithFormat:@"Download All %lu Photos", (unsigned long)photoURLs.count] : @"Download Photo";
        [menu addAction:[UIAlertAction actionWithTitle:title style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
            [[P6YDownloadManager sharedManager] downloadImageURLs:photoURLs title:@"Photos saved"];
        }]];
    }
    if ([P6YManager boolForKey:@"p6y_download_music"] && musicURL) {
        [menu addAction:[UIAlertAction actionWithTitle:@"Download Music" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
            [[P6YDownloadManager sharedManager] downloadURL:musicURL kind:P6YMediaKindAudio title:@"Music downloaded"];
        }]];
    }
    if ([P6YManager boolForKey:@"p6y_copy_description"]) {
        [menu addAction:[UIAlertAction actionWithTitle:@"Copy Description" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
            P6YCopyString(description, @"Description copied");
        }]];
    }
    if ([P6YManager boolForKey:@"p6y_copy_video_link"] && videoURL) {
        [menu addAction:[UIAlertAction actionWithTitle:@"Copy Video Link" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
            P6YCopyString(videoURL.absoluteString, @"Video link copied");
        }]];
    }
    if ([P6YManager boolForKey:@"p6y_copy_music_link"] && musicURL) {
        [menu addAction:[UIAlertAction actionWithTitle:@"Copy Music Link" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
            P6YCopyString(musicURL.absoluteString, @"Music link copied");
        }]];
    }
    [menu addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    if (menu.popoverPresentationController && [cell isKindOfClass:[UIView class]]) {
        menu.popoverPresentationController.sourceView = cell;
        menu.popoverPresentationController.sourceRect = CGRectMake(30, CGRectGetMidY(((UIView *)cell).bounds), 1, 1);
    }
    [presenter presentViewController:menu animated:YES completion:nil];
}

static UIButton *P6YCreateFloatingButton(NSString *symbol, NSInteger tag, id target, SEL action) {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.tag = tag;
    button.backgroundColor = [UIColor colorWithWhite:0.02 alpha:0.86];
    button.tintColor = [UIColor colorWithRed:0.95 green:0 blue:0.04 alpha:1];
    button.layer.cornerRadius = 20;
    button.layer.borderWidth = 1;
    button.layer.borderColor = [UIColor colorWithRed:0.9 green:0 blue:0 alpha:1].CGColor;
    [button setImage:[UIImage systemImageNamed:symbol] forState:UIControlStateNormal];
    [button addTarget:target action:action forControlEvents:UIControlEventTouchUpInside];
    return button;
}

static void P6YConfigureButtonsForCell(UIView *cell, id target) {
    BOOL downloads = [P6YManager boolForKey:@"p6y_downloads_enabled"];
    UIButton *download = [cell viewWithTag:P6YDownloadButtonTag];
    if (downloads && !download) {
        download = P6YCreateFloatingButton(@"arrow.down.circle.fill", P6YDownloadButtonTag, target, NSSelectorFromString(@"p6y_downloadTapped"));
        [cell addSubview:download];
    }
    download.hidden = !downloads;

    BOOL pureMode = [P6YManager boolForKey:@"p6y_pure_mode"];
    UIButton *pure = [cell viewWithTag:P6YPureButtonTag];
    if (pureMode && !pure) {
        pure = P6YCreateFloatingButton(@"eye.slash.fill", P6YPureButtonTag, target, NSSelectorFromString(@"p6y_pureTapped:"));
        [cell addSubview:pure];
    }
    pure.hidden = !pureMode;
    [cell bringSubviewToFront:download];
    [cell bringSubviewToFront:pure];
}

static void P6YLayoutButtonsForCell(UIView *cell) {
    CGFloat y = MAX(95, CGRectGetMidY(cell.bounds) - 45);
    UIButton *download = [cell viewWithTag:P6YDownloadButtonTag];
    UIButton *pure = [cell viewWithTag:P6YPureButtonTag];
    download.frame = CGRectMake(12, y, 40, 40);
    pure.frame = CGRectMake(12, y + 50, 40, 40);
}

static BOOL P6YShouldSkipModel(id model) {
    if (!model) return NO;
    if ([P6YManager boolForKey:@"p6y_hide_ads"] && (P6YSendBool(model, @"isAds") || P6YSendBool(model, @"isAdsOrPseudoAds"))) return YES;
    if ([P6YManager boolForKey:@"p6y_skip_recommendations"] && (P6YSendBool(model, @"isUserRecommendBigCard") || P6YSendBool(model, @"isRecommendFriend"))) return YES;
    return NO;
}

static UIViewController *P6YFindFeedController(UIViewController *controller) {
    UIViewController *current = controller;
    while (current) {
        if ([NSStringFromClass(current.class) isEqualToString:@"AWENewFeedTableViewController"] || P6YResponds(current, @"scrollToNextVideo")) return current;
        current = current.parentViewController;
    }
    return nil;
}

static void P6YHandleSkippedCell(UIView *cell) {
    id model = P6YModelFromCell(cell);
    BOOL skip = P6YShouldSkipModel(model);
    cell.hidden = skip;
    if (!skip) return;
    UIViewController *controller = P6YGet(cell, @"viewController");
    dispatch_async(dispatch_get_main_queue(), ^{
        UIViewController *feed = P6YFindFeedController(controller);
        if (P6YResponds(feed, @"scrollToNextVideo")) {
            ((void (*)(id, SEL))objc_msgSend)(feed, NSSelectorFromString(@"scrollToNextVideo"));
        }
    });
}

static void P6YTogglePureMode(id cell, UIButton *sender) {
    id controller = P6YGet(cell, @"viewController");
    id interaction = P6YGet(controller, @"interactionController");
    BOOL hidden = [objc_getAssociatedObject(cell, @selector(p6y_pureTapped:)) boolValue];
    hidden = !hidden;
    objc_setAssociatedObject(cell, @selector(p6y_pureTapped:), @(hidden), OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    if (P6YResponds(interaction, @"setHide:")) {
        ((void (*)(id, SEL, BOOL))objc_msgSend)(interaction, NSSelectorFromString(@"setHide:"), hidden);
    } else if (P6YResponds(interaction, @"hideAllElements:exceptArray:")) {
        ((void (*)(id, SEL, BOOL, id))objc_msgSend)(interaction, NSSelectorFromString(@"hideAllElements:exceptArray:"), hidden, nil);
    }
    [sender setImage:[UIImage systemImageNamed:hidden ? @"eye.fill" : @"eye.slash.fill"] forState:UIControlStateNormal];
}

static NSNumber *P6YNumber(id value) {
    if ([value isKindOfClass:[NSNumber class]]) return value;
    if ([value isKindOfClass:[NSString class]]) return @([(NSString *)value longLongValue]);
    return nil;
}

static NSString *P6YCompactNumber(id value) {
    NSNumber *number = P6YNumber(value);
    if (!number) return nil;
    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    formatter.numberStyle = NSNumberFormatterDecimalStyle;
    formatter.maximumFractionDigits = 1;
    NSInteger count = number.integerValue;
    if (count >= 1000000) return [NSString stringWithFormat:@"%.1fM", count / 1000000.0];
    if (count >= 1000) return [NSString stringWithFormat:@"%.1fK", count / 1000.0];
    return [formatter stringFromNumber:number];
}

static NSString *P6YFollowStatus(id user) {
    BOOL following = P6YSendBool(user, @"following");
    NSInteger followerStatus = [P6YNumber(P6YGet(user, @"followerStatus")) integerValue];
    NSInteger friendsStatus = [P6YNumber(P6YGet(user, @"friendsStatus")) integerValue];
    if (friendsStatus > 0 || (following && followerStatus > 0)) return @"Friends";
    if (following) return @"Following";
    if (followerStatus > 0) return @"Follows you";
    return @"Not following";
}

static void P6YUpdateProfileBadge(id adaptor, id user) {
    if (![P6YManager boolForKey:@"p6y_profile_follow_status"] && ![P6YManager boolForKey:@"p6y_profile_video_count"]) {
        UIView *view = P6YGet(adaptor, @"view");
        [[view viewWithTag:P6YProfileBadgeTag] removeFromSuperview];
        return;
    }
    UIView *view = P6YGet(adaptor, @"view");
    if (![view isKindOfClass:[UIView class]] || !user) return;
    UILabel *badge = [view viewWithTag:P6YProfileBadgeTag];
    if (!badge) {
        badge = [[UILabel alloc] init];
        badge.tag = P6YProfileBadgeTag;
        badge.textColor = [UIColor colorWithRed:1 green:0.12 blue:0.16 alpha:1];
        badge.backgroundColor = [UIColor colorWithWhite:0.02 alpha:0.82];
        badge.font = [UIFont systemFontOfSize:11 weight:UIFontWeightBold];
        badge.textAlignment = NSTextAlignmentCenter;
        badge.layer.cornerRadius = 9;
        badge.layer.borderWidth = 1;
        badge.layer.borderColor = [UIColor colorWithRed:0.9 green:0 blue:0 alpha:1].CGColor;
        badge.clipsToBounds = YES;
        badge.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleBottomMargin;
        [view addSubview:badge];
    }
    NSMutableArray *parts = [NSMutableArray array];
    if ([P6YManager boolForKey:@"p6y_profile_follow_status"]) [parts addObject:P6YFollowStatus(user)];
    if ([P6YManager boolForKey:@"p6y_profile_video_count"]) {
        id count = P6YGet(user, @"visibleVideosCount") ?: P6YGet(user, @"awemeCount");
        NSString *formatted = P6YCompactNumber(count);
        if (formatted) [parts addObject:[NSString stringWithFormat:@"%@ posts", formatted]];
    }
    badge.text = [parts componentsJoinedByString:@"  •  "];
    CGFloat width = MIN(210, MAX(90, [badge sizeThatFits:CGSizeMake(220, 28)].width + 20));
    badge.frame = CGRectMake(MAX(8, view.bounds.size.width - width - 12), 8, width, 28);
    [view bringSubviewToFront:badge];
}

static void P6YUpdateProfileThumbnail(UIView *cell, id model) {
    UILabel *dateLabel = [cell viewWithTag:P6YProfileDateTag];
    UILabel *likesLabel = [cell viewWithTag:P6YProfileLikesTag];
    BOOL showDate = [P6YManager boolForKey:@"p6y_profile_upload_date"];
    BOOL showLikes = [P6YManager boolForKey:@"p6y_profile_like_count"];

    if (showDate && !dateLabel) {
        dateLabel = [[UILabel alloc] init];
        dateLabel.tag = P6YProfileDateTag;
        dateLabel.font = [UIFont systemFontOfSize:9 weight:UIFontWeightBold];
        dateLabel.textColor = UIColor.whiteColor;
        dateLabel.backgroundColor = [UIColor colorWithWhite:0 alpha:0.68];
        dateLabel.layer.cornerRadius = 4;
        dateLabel.clipsToBounds = YES;
        dateLabel.textAlignment = NSTextAlignmentCenter;
        [cell addSubview:dateLabel];
    }
    if (showLikes && !likesLabel) {
        likesLabel = [[UILabel alloc] init];
        likesLabel.tag = P6YProfileLikesTag;
        likesLabel.font = [UIFont systemFontOfSize:9 weight:UIFontWeightBold];
        likesLabel.textColor = [UIColor colorWithRed:1 green:0.14 blue:0.18 alpha:1];
        likesLabel.backgroundColor = [UIColor colorWithWhite:0 alpha:0.72];
        likesLabel.layer.cornerRadius = 4;
        likesLabel.clipsToBounds = YES;
        likesLabel.textAlignment = NSTextAlignmentCenter;
        [cell addSubview:likesLabel];
    }
    dateLabel.hidden = !showDate;
    likesLabel.hidden = !showLikes;

    if (showDate) {
        NSTimeInterval timestamp = [P6YNumber(P6YGet(model, @"createTime")) doubleValue];
        if (timestamp > 1000000000000.0) timestamp /= 1000.0;
        if (timestamp > 0) {
            NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
            formatter.dateFormat = @"M/d/yy";
            dateLabel.text = [NSString stringWithFormat:@" %@ ", [formatter stringFromDate:[NSDate dateWithTimeIntervalSince1970:timestamp]]];
        }
    }
    if (showLikes) {
        id statistics = P6YGet(model, @"statistics");
        NSString *likes = P6YCompactNumber(P6YGet(statistics, @"diggCount"));
        likesLabel.text = likes.length ? [NSString stringWithFormat:@" ♥ %@ ", likes] : nil;
    }
    dateLabel.frame = CGRectMake(4, 4, 58, 17);
    likesLabel.frame = CGRectMake(MAX(4, cell.bounds.size.width - 67), MAX(4, cell.bounds.size.height - 21), 63, 17);
    [cell bringSubviewToFront:dateLabel];
    [cell bringSubviewToFront:likesLabel];

    if ([P6YManager boolForKey:@"p6y_profile_unsensitive"]) {
        for (NSString *selectorName in @[@"hideTucMask", @"hideProhibitedLayerAndLabel"]) {
            if (P6YResponds(cell, selectorName)) ((void (*)(id, SEL))objc_msgSend)(cell, NSSelectorFromString(selectorName));
        }
        UIView *mask = P6YGet(cell, @"prohibitedContentLayer");
        if ([mask isKindOfClass:[UIView class]]) mask.hidden = YES;
        UILabel *label = P6YGet(cell, @"prohibitedContentLabel");
        if ([label isKindOfClass:[UIView class]]) label.hidden = YES;
    }
}

%hook AppDelegate
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options {
    BOOL result = %orig;
    [P6YManager registerDefaults];
    [P6YManager cleanTemporaryDownloads];
    return result;
}
%end

%hook TTKSettingsBaseCellPlugin
- (void)didSelectItemAtIndex:(NSInteger)index {
    if ([self.itemModel.identifier isEqualToString:@"p6ytok_settings"]) {
        UINavigationController *navigation = [[UINavigationController alloc] initWithRootViewController:[[SettingsViewController alloc] init]];
        navigation.modalPresentationStyle = UIModalPresentationPageSheet;
        [[P6YManager topViewController] presentViewController:navigation animated:YES completion:nil];
        return;
    }
    %orig;
}
%end

%hook AWESettingsNormalSectionViewModel
- (void)viewDidLoad {
    %orig;
    NSString *identifier = self.sectionIdentifier.lowercaseString;
    if (![identifier containsString:@"account"] && ![identifier containsString:@"general"]) return;
    for (id model in self.modelsArray ?: @[]) {
        id item = P6YGet(model, @"itemModel");
        if ([[P6YGet(item, @"identifier") description] isEqualToString:@"p6ytok_settings"]) return;
    }
    TTKSettingsBaseCellPlugin *plugin = [[%c(TTKSettingsBaseCellPlugin) alloc] initWithPluginContext:self.context];
    AWESettingItemModel *item = [[%c(AWESettingItemModel) alloc] initWithIdentifier:@"p6ytok_settings"];
    item.title = @"P6YTOK";
    item.detail = @"Downloads, feed, LIVE, profile, and tools";
    item.iconImage = [UIImage systemImageNamed:@"flame.fill"];
    item.type = 99;
    plugin.itemModel = item;
    [self insertModel:plugin atIndex:0 animated:NO];
}
%end

%hook AWEAwemeModel
- (BOOL)progressBarDraggable {
    BOOL original = %orig;
    return [P6YManager boolForKey:@"p6y_download_progress"] || original;
}

- (BOOL)progressBarVisible {
    BOOL original = %orig;
    return [P6YManager boolForKey:@"p6y_download_progress"] || original;
}

- (BOOL)shouldShowMaskView:(BOOL)argument {
    if ([P6YManager boolForKey:@"p6y_disable_warnings"]) return NO;
    return %orig(argument);
}
%end

%hook AWEFeedViewTemplateCell
- (void)configWithModel:(id)model {
    %orig;
    P6YConfigureButtonsForCell(self, self);
    P6YLayoutButtonsForCell(self);
    P6YHandleSkippedCell(self);
}
- (void)configureWithModel:(id)model {
    %orig;
    P6YConfigureButtonsForCell(self, self);
    P6YLayoutButtonsForCell(self);
    P6YHandleSkippedCell(self);
}
- (void)layoutSubviews {
    %orig;
    P6YLayoutButtonsForCell(self);
}
%new
- (void)p6y_downloadTapped {
    P6YPresentMediaMenu(self);
}
%new
- (void)p6y_pureTapped:(UIButton *)sender {
    P6YTogglePureMode(self, sender);
}
%end

%hook AWEAwemeDetailTableViewCell
- (void)configWithModel:(id)model {
    %orig;
    P6YConfigureButtonsForCell(self, self);
    P6YLayoutButtonsForCell(self);
}
- (void)configureWithModel:(id)model {
    %orig;
    P6YConfigureButtonsForCell(self, self);
    P6YLayoutButtonsForCell(self);
}
- (void)layoutSubviews {
    %orig;
    P6YLayoutButtonsForCell(self);
}
%new
- (void)p6y_downloadTapped { P6YPresentMediaMenu(self); }
%new
- (void)p6y_pureTapped:(UIButton *)sender { P6YTogglePureMode(self, sender); }
%end

%hook TTKStoryDetailTableViewCell
- (void)configWithModel:(id)model {
    %orig;
    P6YConfigureButtonsForCell(self, self);
    P6YLayoutButtonsForCell(self);
}
- (void)configureWithModel:(id)model {
    %orig;
    P6YConfigureButtonsForCell(self, self);
    P6YLayoutButtonsForCell(self);
}
- (void)layoutSubviews {
    %orig;
    P6YLayoutButtonsForCell(self);
}
%new
- (void)p6y_downloadTapped { P6YPresentMediaMenu(self); }
%new
- (void)p6y_pureTapped:(UIButton *)sender { P6YTogglePureMode(self, sender); }
%end

%hook AWEProfileImagePreviewView
- (id)initWithFrame:(CGRect)frame image:(id)image imageURL:(id)imageURL userID:(id)userID type:(NSInteger)type {
    id result = %orig;
    if ([P6YManager boolForKey:@"p6y_save_profile_photo"] && !objc_getAssociatedObject(result, @selector(p6y_profileLongPress:))) {
        UILongPressGestureRecognizer *gesture = [[UILongPressGestureRecognizer alloc] initWithTarget:result action:@selector(p6y_profileLongPress:)];
        gesture.minimumPressDuration = 0.35;
        [result addGestureRecognizer:gesture];
        objc_setAssociatedObject(result, @selector(p6y_profileLongPress:), @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return result;
}
- (id)initWithFrame:(CGRect)frame image:(id)image imageURL:(id)imageURL backgroundColor:(id)backgroundColor userID:(id)userID type:(NSInteger)type {
    id result = %orig;
    if ([P6YManager boolForKey:@"p6y_save_profile_photo"] && !objc_getAssociatedObject(result, @selector(p6y_profileLongPress:))) {
        UILongPressGestureRecognizer *gesture = [[UILongPressGestureRecognizer alloc] initWithTarget:result action:@selector(p6y_profileLongPress:)];
        gesture.minimumPressDuration = 0.35;
        [result addGestureRecognizer:gesture];
        objc_setAssociatedObject(result, @selector(p6y_profileLongPress:), @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return result;
}
%new
- (void)p6y_profileLongPress:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateBegan) return;
    UIImageView *avatar = P6YGet(self, @"avatar");
    if (avatar.image) [[P6YDownloadManager sharedManager] handleImage:avatar.image title:@"Profile photo saved"];
}
%end

static void P6YConfirmVoidAction(id object, const void *bypassKey, SEL selector, NSString *message) {
    __weak id weakObject = object;
    [P6YManager presentConfirmationWithTitle:@"P6YTOK" message:message from:nil confirmed:^{
        id strongObject = weakObject;
        if (!strongObject) return;
        objc_setAssociatedObject(strongObject, bypassKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        ((void (*)(id, SEL))objc_msgSend)(strongObject, selector);
    }];
}

static void P6YConfirmObjectAction(id object, id argument, const void *bypassKey, SEL selector, NSString *message) {
    __weak id weakObject = object;
    [P6YManager presentConfirmationWithTitle:@"P6YTOK" message:message from:nil confirmed:^{
        id strongObject = weakObject;
        if (!strongObject) return;
        objc_setAssociatedObject(strongObject, bypassKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        ((void (*)(id, SEL, id))objc_msgSend)(strongObject, selector, argument);
    }];
}

%hook AWEFeedVideoButton
- (void)_onTouchUpInside {
    NSString *imageName = [[P6YGet(self, @"imageNameString") description] lowercaseString];
    BOOL isLikeButton = [imageName containsString:@"like"] || [imageName containsString:@"digg"];
    if (![P6YManager boolForKey:@"p6y_confirm_like"] || !isLikeButton) {
        %orig;
        return;
    }
    if ([objc_getAssociatedObject(self, P6YLikeBypassKey) boolValue]) {
        objc_setAssociatedObject(self, P6YLikeBypassKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        %orig;
        return;
    }
    P6YConfirmVoidAction(self, P6YLikeBypassKey, @selector(_onTouchUpInside), @"Like this post?");
}
%end

%hook AWECommentPanelBaseCell
- (void)onLikeAction:(id)sender {
    if (![P6YManager boolForKey:@"p6y_confirm_comment_like"]) {
        %orig(sender);
        return;
    }
    if ([objc_getAssociatedObject(self, P6YCommentLikeBypassKey) boolValue]) {
        objc_setAssociatedObject(self, P6YCommentLikeBypassKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        %orig(sender);
        return;
    }
    P6YConfirmObjectAction(self, sender, P6YCommentLikeBypassKey, @selector(onLikeAction:), @"Like this comment?");
}

- (void)onDislikeAction:(id)sender {
    if (![P6YManager boolForKey:@"p6y_confirm_comment_dislike"]) {
        %orig(sender);
        return;
    }
    if ([objc_getAssociatedObject(self, P6YCommentDislikeBypassKey) boolValue]) {
        objc_setAssociatedObject(self, P6YCommentDislikeBypassKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        %orig(sender);
        return;
    }
    P6YConfirmObjectAction(self, sender, P6YCommentDislikeBypassKey, @selector(onDislikeAction:), @"Dislike this comment?");
}
%end

%hook _TtC17TikTokCommentImpl18TTKCommentItemView
- (void)onLikeTapped {
    if (![P6YManager boolForKey:@"p6y_confirm_comment_like"]) {
        %orig;
        return;
    }
    if ([objc_getAssociatedObject(self, P6YCommentLikeBypassKey) boolValue]) {
        objc_setAssociatedObject(self, P6YCommentLikeBypassKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        %orig;
        return;
    }
    P6YConfirmVoidAction(self, P6YCommentLikeBypassKey, @selector(onLikeTapped), @"Like this comment?");
}

- (void)onDislikeTapped {
    if (![P6YManager boolForKey:@"p6y_confirm_comment_dislike"]) {
        %orig;
        return;
    }
    if ([objc_getAssociatedObject(self, P6YCommentDislikeBypassKey) boolValue]) {
        objc_setAssociatedObject(self, P6YCommentDislikeBypassKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        %orig;
        return;
    }
    P6YConfirmVoidAction(self, P6YCommentDislikeBypassKey, @selector(onDislikeTapped), @"Dislike this comment?");
}
%end

%hook TTKRelationButtonViewModelV2
- (void)onRelationViewTapped {
    if (![P6YManager boolForKey:@"p6y_confirm_follow"]) {
        %orig;
        return;
    }
    if ([objc_getAssociatedObject(self, P6YFollowBypassKey) boolValue]) {
        objc_setAssociatedObject(self, P6YFollowBypassKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        %orig;
        return;
    }
    P6YConfirmVoidAction(self, P6YFollowBypassKey, @selector(onRelationViewTapped), @"Change this follow relationship?");
}
%end

%hook AWETextInputController
- (NSUInteger)maxLength {
    NSUInteger original = %orig;
    return [P6YManager boolForKey:@"p6y_extend_comment"] ? MAX((NSUInteger)240, original) : original;
}
%end

%hook AWEProfileEditTextViewController
- (NSInteger)maxTextLength {
    NSInteger original = %orig;
    return [P6YManager boolForKey:@"p6y_extend_bio"] ? MAX((NSInteger)222, original) : original;
}
%end

%hook TTKProfileHeaderAdaptor
- (void)updateUIWithModel:(id)model {
    %orig;
    P6YUpdateProfileBadge(self, model ?: P6YGet(self, @"user"));
}
- (void)configWithUser:(id)user {
    %orig;
    P6YUpdateProfileBadge(self, user);
}
- (void)updateUser:(id)user {
    %orig;
    P6YUpdateProfileBadge(self, user);
}
%end

%hook AWEUserWorkCollectionViewCell
- (void)configWithModel:(id)model isMine:(BOOL)isMine {
    %orig;
    P6YUpdateProfileThumbnail(self, model);
}
- (void)configWithModel:(id)model isMine:(BOOL)isMine repostModel:(id)repostModel repostNoteBubbleModel:(id)bubbleModel repostNoteGuide:(BOOL)guide repostStyle:(NSUInteger)style cellWidth:(double)width {
    %orig;
    P6YUpdateProfileThumbnail(self, model);
}
- (void)layoutSubviews {
    %orig;
    P6YUpdateProfileThumbnail(self, P6YGet(self, @"model"));
}
- (BOOL)isProhibited {
    if ([P6YManager boolForKey:@"p6y_profile_unsensitive"]) return NO;
    return %orig;
}
- (BOOL)isContentCheck {
    if ([P6YManager boolForKey:@"p6y_profile_unsensitive"]) return NO;
    return %orig;
}
%end

%hook TTKCommentPanelViewController
- (void)loadView {
    %orig;
    UIView *panelView = ((UIViewController *)self).view;
    if ([P6YManager boolForKey:@"p6y_transparent_comments"]) {
        panelView.backgroundColor = [UIColor colorWithWhite:0 alpha:0.62];
    }
}

- (void)viewDidLayoutSubviews {
    %orig;
    if (![P6YManager boolForKey:@"p6y_transparent_comments"]) return;
    UIView *panelView = ((UIViewController *)self).view;
    panelView.backgroundColor = [UIColor colorWithWhite:0 alpha:0.62];
    UIView *archView = P6YGet(self, @"archView");
    UITableView *list = P6YGet(self, @"listTableView");
    archView.backgroundColor = UIColor.clearColor;
    list.backgroundColor = UIColor.clearColor;
}
%end

%hook UIPasteboard
- (void)setString:(NSString *)string {
    if ([P6YManager boolForKey:@"p6y_clean_links"]) string = [P6YManager sanitizedTikTokURLString:string];
    %orig(string);
}
- (void)setStrings:(NSArray<NSString *> *)strings {
    if ([P6YManager boolForKey:@"p6y_clean_links"]) {
        NSMutableArray *clean = [NSMutableArray arrayWithCapacity:strings.count];
        for (NSString *string in strings) [clean addObject:[P6YManager sanitizedTikTokURLString:string] ?: string];
        %orig(clean);
        return;
    }
    %orig;
}
%end

%hook AWEFeedCellViewController
- (void)playerWillLoopPlaying:(id)player {
    NSInteger action = [P6YManager integerForKey:@"p6y_playback_action"];
    if (action == 0) {
        %orig(player);
        return;
    }
    if (action == 1) return;

    UIViewController *feed = P6YFindFeedController(self);
    if (P6YResponds(feed, @"scrollToNextVideo")) {
        ((void (*)(id, SEL))objc_msgSend)(feed, NSSelectorFromString(@"scrollToNextVideo"));
        return;
    }
    %orig(player);
}
%end

static void P6YScheduleStartupPage(id controller, NSInteger page) {
    __weak id weakController = controller;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.45 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        id strongSelf = weakController;
        if (!strongSelf || !P6YResponds(strongSelf, @"numberOfTabs")) return;
        NSUInteger count = ((NSUInteger (*)(id, SEL))objc_msgSend)(strongSelf, NSSelectorFromString(@"numberOfTabs"));
        for (NSUInteger index = 0; index < count; index++) {
            NSString *identifier = nil;
            if (P6YResponds(strongSelf, @"topTabIdentifierWithIndex:")) {
                identifier = [((id (*)(id, SEL, NSInteger))objc_msgSend)(strongSelf, NSSelectorFromString(@"topTabIdentifierWithIndex:"), index) description].lowercaseString;
            }
            BOOL matchFollowing = page == 1 && [identifier containsString:@"follow"];
            BOOL matchForYou = page == 0 && ([identifier containsString:@"hot"] || [identifier containsString:@"recommend"] || [identifier containsString:@"for_you"] || [identifier containsString:@"foryou"]);
            if (!matchFollowing && !matchForYou) continue;
            if (P6YResponds(strongSelf, @"tabItemTypeWithIndex:") && P6YResponds(strongSelf, @"scrollToTab:")) {
                NSInteger type = ((NSInteger (*)(id, SEL, NSInteger))objc_msgSend)(strongSelf, NSSelectorFromString(@"tabItemTypeWithIndex:"), index);
                ((void (*)(id, SEL, NSInteger))objc_msgSend)(strongSelf, NSSelectorFromString(@"scrollToTab:"), type);
            } else if (P6YResponds(strongSelf, @"setCurrentIndex:")) {
                ((void (*)(id, SEL, NSInteger))objc_msgSend)(strongSelf, NSSelectorFromString(@"setCurrentIndex:"), index);
            }
            break;
        }
    });
}

%hook AWEFeedContainerViewController
- (void)viewDidAppear:(BOOL)animated {
    %orig(animated);
    if ([objc_getAssociatedObject(self, P6YStartupAppliedKey) boolValue]) return;
    objc_setAssociatedObject(self, P6YStartupAppliedKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    NSInteger page = [P6YManager integerForKey:@"p6y_startup_page"];
    P6YScheduleStartupPage(self, page);
}
%end

%ctor {
    @autoreleasepool {
        [P6YManager registerDefaults];
        %init;
    }
}
