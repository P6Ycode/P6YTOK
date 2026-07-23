#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <math.h>
#import "P6YManager.h"
#import "P6YDownloadManager.h"

static const NSInteger P6YLikesSelectButtonTag = 46040;
static const NSInteger P6YLikesSelectionOverlayTag = 46041;
static const NSInteger P6YLikesBrokenBadgeTag = 46042;
static const NSInteger P6YLikesToolbarTag = 46043;
static const void *P6YLikesSessionKey = &P6YLikesSessionKey;
static const void *P6YLikesOverlayModelKey = &P6YLikesOverlayModelKey;

static id P6YLikesGet(id object, NSString *key) {
    return [P6YManager safeValueForKey:key fromObject:object];
}

static BOOL P6YLikesSet(id object, NSString *key, id value) {
    if (!object || key.length == 0) return NO;
    @try {
        [object setValue:value forKey:key];
        return YES;
    } @catch (__unused NSException *exception) {
        return NO;
    }
}

static BOOL P6YLikesBool(id object, NSString *key, BOOL *found) {
    id value = P6YLikesGet(object, key);
    if ([value isKindOfClass:NSNumber.class]) {
        if (found) *found = YES;
        return [value boolValue];
    }
    if ([value isKindOfClass:NSString.class]) {
        NSString *lower = [(NSString *)value lowercaseString];
        if ([lower isEqualToString:@"true"] || [lower isEqualToString:@"yes"] || [lower isEqualToString:@"1"]) {
            if (found) *found = YES;
            return YES;
        }
        if ([lower isEqualToString:@"false"] || [lower isEqualToString:@"no"] || [lower isEqualToString:@"0"]) {
            if (found) *found = YES;
            return NO;
        }
    }
    return NO;
}

static NSString *P6YLikesString(id value) {
    if ([value isKindOfClass:NSString.class]) return value;
    if ([value respondsToSelector:@selector(stringValue)]) return [value stringValue];
    return nil;
}

static id P6YLikesResolveModel(id object) {
    if (!object) return nil;
    NSString *name = NSStringFromClass([object class]).lowercaseString;
    if ([name containsString:@"aweme"] || P6YLikesGet(object, @"video") || P6YLikesGet(object, @"photoAlbum")) return object;

    for (NSString *key in @[@"aweme", @"model", @"itemModel", @"workModel", @"dataModel", @"currentAweme", @"awemeModel", @"item"]) {
        id value = P6YLikesGet(object, key);
        if (!value || value == object) continue;
        NSString *valueName = NSStringFromClass([value class]).lowercaseString;
        if ([valueName containsString:@"aweme"] || P6YLikesGet(value, @"video") || P6YLikesGet(value, @"photoAlbum")) return value;
    }
    return object;
}

static NSString *P6YLikesModelIdentifier(id rawModel) {
    id model = P6YLikesResolveModel(rawModel);
    for (NSString *key in @[@"awemeID", @"itemID", @"aid", @"groupID", @"objectID", @"idStr", @"idString"]) {
        NSString *value = P6YLikesString(P6YLikesGet(model, key));
        if (value.length) return [NSString stringWithFormat:@"%@:%@", key, value];
    }
    return [NSString stringWithFormat:@"ptr:%p", model];
}

static BOOL P6YLikesLooksLikePlaceholder(id rawModel) {
    NSString *name = NSStringFromClass([rawModel class]).lowercaseString;
    return [name containsString:@"placeholder"] || [name containsString:@"skeleton"] || [name containsString:@"shimmer"];
}

static BOOL P6YLikesExplicitBrokenFlag(id object) {
    if (!object) return NO;
    NSArray<NSString *> *keys = @[
        @"isDeleted", @"deleted", @"isDelete", @"delete", @"statusIsDeleted", @"isAwemeDidDelete",
        @"isInvalid", @"invalid", @"isUnavailable", @"unavailable", @"isRemoved", @"removed",
        @"isContentDeleted", @"contentDeleted", @"isNotFound", @"notFound", @"isTakedown", @"takenDown"
    ];
    for (NSString *key in keys) {
        BOOL found = NO;
        if (P6YLikesBool(object, key, &found) && found) return YES;
    }

    for (NSString *selectorName in @[@"statusIsDeleted", @"isAwemeDidDelete", @"isDeleted", @"isInvalid", @"isUnavailable", @"isRemoved"]) {
        SEL selector = NSSelectorFromString(selectorName);
        if (![object respondsToSelector:selector]) continue;
        NSMethodSignature *signature = [object methodSignatureForSelector:selector];
        if (signature.numberOfArguments != 2) continue;
        BOOL result = ((BOOL (*)(id, SEL))objc_msgSend)(object, selector);
        if (result) return YES;
    }

    for (NSString *key in @[@"statusText", @"statusMessage", @"invalidReason", @"deleteReason", @"unavailableReason", @"message"]) {
        NSString *text = [P6YLikesString(P6YLikesGet(object, key)) lowercaseString];
        if ([text containsString:@"deleted"] || [text containsString:@"removed"] ||
            [text containsString:@"unavailable"] || [text containsString:@"not found"] ||
            [text containsString:@"invalid aweme"] || [text containsString:@"taken down"]) return YES;
    }
    return NO;
}

static BOOL P6YLikesModelIsBroken(id rawModel) {
    if (!rawModel || P6YLikesLooksLikePlaceholder(rawModel)) return NO;
    id model = P6YLikesResolveModel(rawModel);
    if (P6YLikesExplicitBrokenFlag(model)) return YES;

    for (NSString *key in @[@"status", @"awemeStatus", @"itemStatus", @"reviewStatus", @"contentStatus"]) {
        if (P6YLikesExplicitBrokenFlag(P6YLikesGet(model, key))) return YES;
    }
    return NO;
}

static NSURL *P6YLikesURL(id value) {
    if ([value isKindOfClass:NSURL.class]) return value;
    if ([value isKindOfClass:NSString.class]) return [NSURL URLWithString:value];
    return nil;
}

static NSInteger P6YLikesURLScore(NSURL *url) {
    if (!url) return NSIntegerMin;
    NSString *lower = url.absoluteString.lowercaseString;
    NSInteger score = 0;
    if ([lower containsString:@".m3u8"]) score -= 1000000;
    if ([lower containsString:@"origin"] || [lower containsString:@"source"] || [lower containsString:@"original"]) score += 700000;
    if ([lower containsString:@"2160"] || [lower containsString:@"4k"]) score += 600000;
    if ([lower containsString:@"1440"]) score += 500000;
    if ([lower containsString:@"1080"]) score += 400000;
    if ([lower containsString:@"720"]) score += 250000;
    if ([lower containsString:@"video_mp4"] || [lower containsString:@".mp4"]) score += 100000;
    if ([lower containsString:@"watermark"] || [lower containsString:@"wm_"]) score -= 500000;
    score += MIN((NSInteger)lower.length, 10000);
    return score;
}

static NSURL *P6YLikesBestURLFromURLModel(id urlModel) {
    if (!urlModel) return nil;
    NSURL *direct = P6YLikesURL(urlModel);
    if (direct) return direct;

    NSMutableArray *items = [NSMutableArray array];
    for (NSString *key in @[@"originURLList", @"URLList", @"urlList", @"urls", @"downloadURLList"]) {
        id value = P6YLikesGet(urlModel, key);
        if ([value isKindOfClass:NSArray.class]) [items addObjectsFromArray:value];
        else if (value) [items addObject:value];
    }

    NSURL *best = nil;
    NSInteger bestScore = NSIntegerMin;
    for (id item in items) {
        NSURL *url = P6YLikesURL(item);
        if (!url) url = P6YLikesURL(P6YLikesGet(item, @"URL"));
        if (!url) url = P6YLikesURL(P6YLikesGet(item, @"url"));
        NSInteger score = P6YLikesURLScore(url);
        if (score > bestScore) {
            best = url;
            bestScore = score;
        }
    }
    return best;
}

static NSURL *P6YLikesBestVideoURL(id rawModel) {
    id model = P6YLikesResolveModel(rawModel);
    id video = P6YLikesGet(model, @"video");
    if (!video) return nil;

    NSURL *best = nil;
    long long bestBitrate = -1;
    NSArray *bitRates = P6YLikesGet(video, @"bitRate");
    if (![bitRates isKindOfClass:NSArray.class]) bitRates = P6YLikesGet(video, @"bitRates");
    for (id variant in bitRates ?: @[]) {
        long long bitrate = [P6YLikesGet(variant, @"bitRate") longLongValue];
        if (bitrate <= 0) bitrate = [P6YLikesGet(variant, @"bitrate") longLongValue];
        NSURL *url = nil;
        for (NSString *key in @[@"playAddr", @"playURL", @"url", @"downloadURL"]) {
            url = P6YLikesBestURLFromURLModel(P6YLikesGet(variant, key));
            if (url) break;
        }
        if (url && bitrate >= bestBitrate) {
            best = url;
            bestBitrate = bitrate;
        }
    }
    if (best) return best;

    NSInteger bestScore = NSIntegerMin;
    for (NSString *key in @[@"h264DownloadURL", @"downloadURL", @"playURL", @"h264URL", @"playAddr", @"originVideoURL"]) {
        NSURL *candidate = P6YLikesBestURLFromURLModel(P6YLikesGet(video, key));
        NSInteger score = P6YLikesURLScore(candidate);
        if (score > bestScore) {
            best = candidate;
            bestScore = score;
        }
    }
    return best;
}

static NSArray<NSURL *> *P6YLikesPhotoURLs(id rawModel) {
    id model = P6YLikesResolveModel(rawModel);
    id album = P6YLikesGet(model, @"photoAlbum");
    NSArray *photos = P6YLikesGet(album, @"photos");
    if (![photos isKindOfClass:NSArray.class]) photos = P6YLikesGet(model, @"images");
    if (![photos isKindOfClass:NSArray.class]) return @[];

    NSMutableArray<NSURL *> *urls = [NSMutableArray array];
    for (id photo in photos) {
        NSURL *url = nil;
        for (NSString *key in @[@"originPhotoURL", @"originURL", @"downloadURL", @"displayImage", @"urlModel"]) {
            url = P6YLikesBestURLFromURLModel(P6YLikesGet(photo, key));
            if (url) break;
        }
        if (url) [urls addObject:url];
    }
    return urls;
}

static UICollectionView *P6YLikesFindCollectionView(UIView *view) {
    if (!view) return nil;
    UICollectionView *best = [view isKindOfClass:UICollectionView.class] ? (UICollectionView *)view : nil;
    CGFloat bestArea = best ? CGRectGetWidth(best.bounds) * CGRectGetHeight(best.bounds) : 0;
    for (UIView *child in view.subviews) {
        UICollectionView *candidate = P6YLikesFindCollectionView(child);
        CGFloat area = candidate ? CGRectGetWidth(candidate.bounds) * CGRectGetHeight(candidate.bounds) : 0;
        if (area > bestArea) {
            best = candidate;
            bestArea = area;
        }
    }
    return best;
}

static void P6YLikesAppendModels(id value, NSMutableArray *result, NSMutableSet<NSString *> *seen, NSUInteger depth) {
    if (!value || depth > 4 || result.count >= 3000) return;
    if ([value isKindOfClass:NSArray.class]) {
        for (id item in (NSArray *)value) P6YLikesAppendModels(item, result, seen, depth + 1);
        return;
    }
    if ([value isKindOfClass:NSDictionary.class]) {
        for (id item in [(NSDictionary *)value allValues]) P6YLikesAppendModels(item, result, seen, depth + 1);
        return;
    }

    id resolved = P6YLikesResolveModel(value);
    NSString *name = NSStringFromClass([resolved class]).lowercaseString;
    BOOL looksLikeAweme = [name containsString:@"aweme"] || P6YLikesGet(resolved, @"video") || P6YLikesGet(resolved, @"photoAlbum");
    if (looksLikeAweme && !P6YLikesLooksLikePlaceholder(resolved)) {
        NSString *key = P6YLikesModelIdentifier(resolved);
        if (![seen containsObject:key]) {
            [seen addObject:key];
            [result addObject:resolved];
        }
        return;
    }

    for (NSString *key in @[@"items", @"models", @"dataArray", @"dataList", @"list", @"awemeList", @"works", @"dataSource", @"filteredDataSource", @"currentItems", @"sectionModels", @"objects"]) {
        id nested = P6YLikesGet(value, key);
        if (nested && nested != value) P6YLikesAppendModels(nested, result, seen, depth + 1);
    }
}

static NSArray *P6YLikesLoadedModels(UIViewController *controller) {
    NSMutableArray *models = [NSMutableArray array];
    NSMutableSet *seen = [NSMutableSet set];
    id dataManager = P6YLikesGet(controller, @"dataManager");
    P6YLikesAppendModels(dataManager, models, seen, 0);
    if (models.count == 0) P6YLikesAppendModels(controller, models, seen, 0);
    return models;
}

static id P6YLikesModelForCell(UIView *cell, NSIndexPath *indexPath, UIViewController *controller) {
    for (NSString *key in @[@"model", @"aweme", @"itemModel", @"workModel", @"dataModel", @"awemeModel"]) {
        id model = P6YLikesGet(cell, key);
        if (model) return P6YLikesResolveModel(model);
    }

    NSArray *models = P6YLikesLoadedModels(controller);
    if (indexPath && indexPath.item < models.count) return models[indexPath.item];
    return nil;
}

static BOOL P6YLikesCallObject(id target, NSString *selectorName, id argument) {
    SEL selector = NSSelectorFromString(selectorName);
    if (!target || ![target respondsToSelector:selector]) return NO;
    NSMethodSignature *signature = [target methodSignatureForSelector:selector];
    if (signature.numberOfArguments != 3) return NO;
    ((void (*)(id, SEL, id))objc_msgSend)(target, selector, argument);
    return YES;
}

static BOOL P6YLikesCallObjectBool(id target, NSString *selectorName, id argument, BOOL flag) {
    SEL selector = NSSelectorFromString(selectorName);
    if (!target || ![target respondsToSelector:selector]) return NO;
    NSMethodSignature *signature = [target methodSignatureForSelector:selector];
    if (signature.numberOfArguments != 4) return NO;
    ((void (*)(id, SEL, id, BOOL))objc_msgSend)(target, selector, argument, flag);
    return YES;
}

@class P6YLikesCleanupSession;

@interface P6YLikesOverlayButton : UIButton
@property (nonatomic, weak) P6YLikesCleanupSession *cleanupSession;
@end
@implementation P6YLikesOverlayButton
@end

@interface P6YLikesCleanupSession : NSObject
@property (nonatomic, weak) UIViewController *controller;
@property (nonatomic, weak) UICollectionView *collectionView;
@property (nonatomic, strong) NSMutableDictionary<NSString *, id> *selectedModels;
@property (nonatomic, assign) BOOL selecting;
@property (nonatomic, strong) UIButton *selectButton;
@property (nonatomic, strong) UIView *toolbar;
@property (nonatomic, strong) UILabel *countLabel;
- (instancetype)initWithController:(UIViewController *)controller;
- (void)install;
- (void)layout;
- (void)refreshVisibleCells;
- (void)finishSelection;
@end

@implementation P6YLikesCleanupSession

- (instancetype)initWithController:(UIViewController *)controller {
    self = [super init];
    if (self) {
        _controller = controller;
        _selectedModels = [NSMutableDictionary dictionary];
    }
    return self;
}

- (UIButton *)toolbarButton:(NSString *)title action:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    [button setTitle:title forState:UIControlStateNormal];
    [button setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    button.titleLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightSemibold];
    button.backgroundColor = [UIColor colorWithWhite:0.12 alpha:1.0];
    button.layer.cornerRadius = 8;
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return button;
}

- (void)install {
    UIView *host = self.controller.view;
    if (!host) return;
    self.collectionView = P6YLikesFindCollectionView(host);

    if (![P6YManager boolForKey:@"p6y_likes_cleanup"]) {
        [self.selectButton removeFromSuperview];
        [self.toolbar removeFromSuperview];
        self.selectButton = nil;
        self.toolbar = nil;
        self.selecting = NO;
        [self.selectedModels removeAllObjects];
        [self refreshVisibleCells];
        return;
    }

    if (!self.selectButton) {
        UIButton *select = [UIButton buttonWithType:UIButtonTypeSystem];
        select.tag = P6YLikesSelectButtonTag;
        select.backgroundColor = [UIColor colorWithWhite:0.02 alpha:0.90];
        select.layer.cornerRadius = 10;
        select.layer.borderWidth = 1;
        select.layer.borderColor = [UIColor colorWithRed:0.90 green:0 blue:0.04 alpha:1.0].CGColor;
        [select setTitle:@"Select" forState:UIControlStateNormal];
        [select setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
        select.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightBold];
        [select addTarget:self action:@selector(beginSelection) forControlEvents:UIControlEventTouchUpInside];
        [host addSubview:select];
        self.selectButton = select;
    }

    if (!self.toolbar) {
        UIView *toolbar = [[UIView alloc] init];
        toolbar.tag = P6YLikesToolbarTag;
        toolbar.backgroundColor = [UIColor colorWithWhite:0.025 alpha:0.96];
        toolbar.layer.cornerRadius = 14;
        toolbar.layer.borderWidth = 1;
        toolbar.layer.borderColor = [UIColor colorWithRed:0.90 green:0 blue:0.04 alpha:1.0].CGColor;
        toolbar.hidden = YES;

        UILabel *count = [[UILabel alloc] init];
        count.textColor = UIColor.whiteColor;
        count.font = [UIFont monospacedDigitSystemFontOfSize:11 weight:UIFontWeightSemibold];
        count.textAlignment = NSTextAlignmentCenter;
        [toolbar addSubview:count];
        self.countLabel = count;

        NSArray *titles = @[@"Broken", @"All", @"Download", @"Remove", @"Done"];
        NSArray *actions = @[
            NSStringFromSelector(@selector(selectBroken)), NSStringFromSelector(@selector(selectAllLoaded)),
            NSStringFromSelector(@selector(downloadSelected)), NSStringFromSelector(@selector(removeSelectedBroken)),
            NSStringFromSelector(@selector(finishSelection))
        ];
        for (NSUInteger index = 0; index < titles.count; index++) {
            UIButton *button = [self toolbarButton:titles[index] action:NSSelectorFromString(actions[index])];
            button.tag = 46100 + (NSInteger)index;
            [toolbar addSubview:button];
        }
        [host addSubview:toolbar];
        self.toolbar = toolbar;
    }

    [self layout];
    [self refreshVisibleCells];
}

- (void)layout {
    UIView *host = self.controller.view;
    if (!host) return;
    UIEdgeInsets safe = host.safeAreaInsets;
    CGFloat width = CGRectGetWidth(host.bounds);
    CGFloat height = CGRectGetHeight(host.bounds);

    self.selectButton.frame = CGRectMake(MAX(12.0, width - 92.0), MAX(8.0, safe.top + 8.0), 80.0, 36.0);
    self.toolbar.frame = CGRectMake(10.0, MAX(safe.top + 60.0, height - safe.bottom - 102.0), MAX(0, width - 20.0), 92.0);
    self.countLabel.frame = CGRectMake(8.0, 5.0, MAX(0, CGRectGetWidth(self.toolbar.bounds) - 16.0), 22.0);

    CGFloat gap = 6.0;
    CGFloat buttonsWidth = CGRectGetWidth(self.toolbar.bounds) - 16.0;
    CGFloat buttonWidth = (buttonsWidth - gap * 4.0) / 5.0;
    for (NSUInteger index = 0; index < 5; index++) {
        UIButton *button = [self.toolbar viewWithTag:46100 + (NSInteger)index];
        button.frame = CGRectMake(8.0 + index * (buttonWidth + gap), 34.0, buttonWidth, 48.0);
    }
    [host bringSubviewToFront:self.selectButton];
    [host bringSubviewToFront:self.toolbar];
}

- (void)updateCountLabel {
    NSArray *loaded = P6YLikesLoadedModels(self.controller);
    NSUInteger broken = 0;
    for (id model in loaded) if (P6YLikesModelIsBroken(model)) broken++;
    self.countLabel.text = [NSString stringWithFormat:@"%lu selected • %lu broken detected • %lu loaded",
                            (unsigned long)self.selectedModels.count,
                            (unsigned long)broken,
                            (unsigned long)loaded.count];
}

- (void)beginSelection {
    self.selecting = YES;
    self.selectButton.hidden = YES;
    self.toolbar.hidden = NO;
    [self.selectedModels removeAllObjects];
    [self selectBroken];
}

- (void)finishSelection {
    self.selecting = NO;
    self.selectButton.hidden = NO;
    self.toolbar.hidden = YES;
    [self.selectedModels removeAllObjects];
    [self refreshVisibleCells];
}

- (void)selectBroken {
    [self.selectedModels removeAllObjects];
    for (id model in P6YLikesLoadedModels(self.controller)) {
        if (P6YLikesModelIsBroken(model)) self.selectedModels[P6YLikesModelIdentifier(model)] = model;
    }
    [self updateCountLabel];
    [self refreshVisibleCells];
    if (self.selectedModels.count == 0) [P6YManager showToast:@"No broken liked posts detected in loaded items"];
}

- (void)selectAllLoaded {
    [self.selectedModels removeAllObjects];
    for (id model in P6YLikesLoadedModels(self.controller)) {
        self.selectedModels[P6YLikesModelIdentifier(model)] = model;
    }
    [self updateCountLabel];
    [self refreshVisibleCells];
}

- (void)toggleModelFromOverlay:(P6YLikesOverlayButton *)sender {
    id model = objc_getAssociatedObject(sender, P6YLikesOverlayModelKey);
    if (!model) return;
    NSString *key = P6YLikesModelIdentifier(model);
    if (self.selectedModels[key]) [self.selectedModels removeObjectForKey:key];
    else self.selectedModels[key] = model;
    [self updateCountLabel];
    [self refreshVisibleCells];
}

- (void)downloadSelected {
    NSArray *models = self.selectedModels.allValues;
    if (models.count == 0) {
        [P6YManager showToast:@"Select liked posts to download"];
        return;
    }

    __block NSUInteger accepted = 0;
    NSUInteger index = 0;
    for (id model in models) {
        if (P6YLikesModelIsBroken(model)) continue;
        NSArray<NSURL *> *photos = P6YLikesPhotoURLs(model);
        NSURL *video = photos.count ? nil : P6YLikesBestVideoURL(model);
        if (!photos.count && !video) continue;
        NSTimeInterval delay = MIN(2.0, index * 0.12);
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (photos.count) {
                [[P6YDownloadManager sharedManager] downloadImageURLs:photos title:@"Liked photos saved"];
            } else {
                [[P6YDownloadManager sharedManager] downloadURL:video kind:P6YMediaKindVideo title:@"Liked video saved"];
            }
        });
        accepted++;
        index++;
    }
    [P6YManager showToast:accepted ? [NSString stringWithFormat:@"Starting %lu full-quality download%@", (unsigned long)accepted, accepted == 1 ? @"" : @"s"] : @"No downloadable media in the selection"];
}

- (void)removeSelectedBroken {
    NSMutableArray *brokenModels = [NSMutableArray array];
    NSMutableArray<NSString *> *ids = [NSMutableArray array];
    for (id model in self.selectedModels.allValues) {
        if (!P6YLikesModelIsBroken(model)) continue;
        [brokenModels addObject:model];
        NSString *identifier = nil;
        for (NSString *key in @[@"awemeID", @"itemID", @"aid", @"groupID"]) {
            identifier = P6YLikesString(P6YLikesGet(P6YLikesResolveModel(model), key));
            if (identifier.length) break;
        }
        if (identifier.length) [ids addObject:identifier];
    }
    if (brokenModels.count == 0) {
        [P6YManager showToast:@"Remove only applies to detected broken entries"];
        return;
    }

    id dataManager = P6YLikesGet(self.controller, @"dataManager");
    BOOL invoked = NO;
    for (id target in @[dataManager ?: NSNull.null, self.controller]) {
        if (target == NSNull.null) continue;
        if (ids.count) {
            invoked |= P6YLikesCallObject(target, @"deleteAwemeWithIDs:", ids);
            invoked |= P6YLikesCallObjectBool(target, @"deleteAwemeWithIDs:animated:", ids, YES);
            invoked |= P6YLikesCallObject(target, @"deleteAwemeFilterDataWithIDs:", ids);
            invoked |= P6YLikesCallObject(target, @"didDeleteAwemesWithIDs:", ids);
        }
        invoked |= P6YLikesCallObject(target, @"removeAwemes:", brokenModels);
        invoked |= P6YLikesCallObject(target, @"removeListWithAwemes:", brokenModels);
    }

    for (id model in brokenModels) {
        id resolved = P6YLikesResolveModel(model);
        P6YLikesSet(resolved, @"userDigg", @NO);
        P6YLikesSet(resolved, @"isUserDigg", @NO);
        invoked |= P6YLikesCallObject(dataManager, @"deleteAwemeModel:", resolved);
        invoked |= P6YLikesCallObject(dataManager, @"removeAwemeModelForAwemeModel:", resolved);
        invoked |= P6YLikesCallObject(self.controller, @"didDiggAweme:", resolved);
    }

    [self.selectedModels removeAllObjects];
    [self updateCountLabel];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self.collectionView reloadData];
        [self refreshVisibleCells];
    });
    [P6YManager showToast:invoked ? @"Asked TikTok to remove the selected broken likes" : @"TikTok did not expose a removal action for these entries"];
}

- (void)refreshVisibleCells {
    UICollectionView *collection = self.collectionView ?: P6YLikesFindCollectionView(self.controller.view);
    self.collectionView = collection;
    if (!collection) return;

    for (UICollectionViewCell *cell in collection.visibleCells) {
        NSIndexPath *indexPath = [collection indexPathForCell:cell];
        id model = P6YLikesModelForCell(cell, indexPath, self.controller);
        BOOL broken = model && P6YLikesModelIsBroken(model);

        UILabel *badge = [cell viewWithTag:P6YLikesBrokenBadgeTag];
        if (![P6YManager boolForKey:@"p6y_likes_cleanup"] || !broken || self.selecting) {
            [badge removeFromSuperview];
        } else {
            if (!badge) {
                badge = [[UILabel alloc] init];
                badge.tag = P6YLikesBrokenBadgeTag;
                badge.text = @"BROKEN";
                badge.textAlignment = NSTextAlignmentCenter;
                badge.font = [UIFont systemFontOfSize:9 weight:UIFontWeightHeavy];
                badge.textColor = UIColor.whiteColor;
                badge.backgroundColor = [UIColor colorWithRed:0.90 green:0 blue:0.04 alpha:0.92];
                badge.layer.cornerRadius = 6;
                badge.clipsToBounds = YES;
                badge.userInteractionEnabled = NO;
                [cell addSubview:badge];
            }
            badge.frame = CGRectMake(5.0, 5.0, MIN(58.0, MAX(0, CGRectGetWidth(cell.bounds) - 10.0)), 18.0);
            [cell bringSubviewToFront:badge];
        }

        P6YLikesOverlayButton *overlay = [cell viewWithTag:P6YLikesSelectionOverlayTag];
        if (!self.selecting || !model) {
            [overlay removeFromSuperview];
            continue;
        }
        if (!overlay) {
            overlay = [P6YLikesOverlayButton buttonWithType:UIButtonTypeSystem];
            overlay.tag = P6YLikesSelectionOverlayTag;
            overlay.cleanupSession = self;
            overlay.backgroundColor = [UIColor colorWithWhite:0 alpha:0.22];
            overlay.layer.borderWidth = 2;
            overlay.layer.cornerRadius = 8;
            overlay.clipsToBounds = YES;
            overlay.titleLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightHeavy];
            overlay.titleLabel.numberOfLines = 2;
            overlay.titleLabel.textAlignment = NSTextAlignmentCenter;
            [overlay addTarget:self action:@selector(toggleModelFromOverlay:) forControlEvents:UIControlEventTouchUpInside];
            [cell addSubview:overlay];
        }
        objc_setAssociatedObject(overlay, P6YLikesOverlayModelKey, model, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        NSString *key = P6YLikesModelIdentifier(model);
        BOOL selected = self.selectedModels[key] != nil;
        overlay.frame = cell.bounds;
        overlay.layer.borderColor = (selected ? [UIColor colorWithRed:0.90 green:0 blue:0.04 alpha:1.0] : UIColor.whiteColor).CGColor;
        [overlay setTitle:selected ? (broken ? @"✓\nBROKEN" : @"✓") : (broken ? @"BROKEN" : @"○") forState:UIControlStateNormal];
        [overlay setTitleColor:broken ? [UIColor colorWithRed:1 green:0.22 blue:0.24 alpha:1.0] : UIColor.whiteColor forState:UIControlStateNormal];
        [cell bringSubviewToFront:overlay];
    }
    if (self.selecting) [self updateCountLabel];
}

@end

static P6YLikesCleanupSession *P6YLikesSessionForController(UIViewController *controller, BOOL create) {
    P6YLikesCleanupSession *session = objc_getAssociatedObject(controller, P6YLikesSessionKey);
    if (!session && create) {
        session = [[P6YLikesCleanupSession alloc] initWithController:controller];
        objc_setAssociatedObject(controller, P6YLikesSessionKey, session, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return session;
}

static void P6YLikesInstallVoidHook(Class cls, SEL selector, void (^after)(UIViewController *controller)) {
    Method method = class_getInstanceMethod(cls, selector);
    if (!method) return;
    IMP original = class_getMethodImplementation(cls, selector);
    const char *types = method_getTypeEncoding(method);
    IMP replacement = imp_implementationWithBlock(^(UIViewController *controller) {
        ((void (*)(id, SEL))original)(controller, selector);
        if (after) after(controller);
    });
    class_replaceMethod(cls, selector, replacement, types);
}

static void P6YLikesInstallBoolHook(Class cls, SEL selector, void (^after)(UIViewController *controller)) {
    Method method = class_getInstanceMethod(cls, selector);
    if (!method) return;
    IMP original = class_getMethodImplementation(cls, selector);
    const char *types = method_getTypeEncoding(method);
    IMP replacement = imp_implementationWithBlock(^(UIViewController *controller, BOOL animated) {
        ((void (*)(id, SEL, BOOL))original)(controller, selector, animated);
        if (after) after(controller);
    });
    class_replaceMethod(cls, selector, replacement, types);
}

static void P6YLikesInstallAttempt(NSUInteger attempt) {
    Class cls = NSClassFromString(@"TIKTOKLikeWorkViewController");
    if (cls) {
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            P6YLikesInstallVoidHook(cls, @selector(viewDidLoad), ^(UIViewController *controller) {
                [P6YLikesSessionForController(controller, YES) install];
            });
            P6YLikesInstallVoidHook(cls, @selector(viewDidLayoutSubviews), ^(UIViewController *controller) {
                P6YLikesCleanupSession *session = P6YLikesSessionForController(controller, YES);
                [session install];
                [session layout];
                [session refreshVisibleCells];
            });
            P6YLikesInstallBoolHook(cls, @selector(viewDidAppear:), ^(UIViewController *controller) {
                P6YLikesCleanupSession *session = P6YLikesSessionForController(controller, YES);
                [session install];
                [session refreshVisibleCells];
            });
            P6YLikesInstallBoolHook(cls, @selector(viewWillDisappear:), ^(UIViewController *controller) {
                [P6YLikesSessionForController(controller, NO) finishSelection];
            });
        });
        return;
    }
    if (attempt < 20) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            P6YLikesInstallAttempt(attempt + 1);
        });
    }
}

__attribute__((constructor)) static void P6YLikesCleanupInitialize(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        [P6YManager registerDefaults];
        P6YLikesInstallAttempt(0);
    });
}
