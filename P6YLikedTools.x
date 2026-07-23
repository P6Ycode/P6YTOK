#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import "P6YManager.h"
#import "P6YDownloadManager.h"
#import "P6YMediaQuality.h"

static const NSInteger P6YLikedToolbarTag = 46220;
static const NSInteger P6YLikedBrokenTag = 46221;
static const NSInteger P6YLikedSelectionTag = 46222;
static const void *P6YLikedGestureInstalledKey = &P6YLikedGestureInstalledKey;
static const void *P6YLikedCoordinatorKey = &P6YLikedCoordinatorKey;

static id P6YLikedGet(id object, NSString *key) { return [P6YManager safeValueForKey:key fromObject:object]; }
static BOOL P6YLikedBool(id object, NSString *selectorName) {
    SEL selector = NSSelectorFromString(selectorName);
    return object && [object respondsToSelector:selector] ? ((BOOL (*)(id, SEL))objc_msgSend)(object, selector) : NO;
}
static NSNumber *P6YLikedNumber(id value) {
    if ([value isKindOfClass:NSNumber.class]) return value;
    if ([value isKindOfClass:NSString.class]) return @([(NSString *)value longLongValue]);
    return nil;
}

static NSString *P6YAwemeID(id model) {
    for (NSString *key in @[@"itemID", @"awemeId", @"awemeID", @"groupId", @"groupID"]) {
        NSString *value = [P6YLikedGet(model, key) description];
        if (value.length && ![value isEqualToString:@"(null)"]) return value;
    }
    return nil;
}

static BOOL P6YAwemeIsUnavailable(id model) {
    if (!model) return YES;
    for (NSString *selector in @[@"isDeleted", @"isDelete", @"isUnavailable", @"isAwemeUnavailable", @"isProhibited"]) {
        if (P6YLikedBool(model, selector)) return YES;
    }
    id status = P6YLikedGet(model, @"status") ?: P6YLikedGet(model, @"statusItem");
    for (NSString *selector in @[@"isDeleted", @"isDelete", @"isUnavailable", @"isProhibited"]) {
        if (P6YLikedBool(status, selector)) return YES;
    }
    NSNumber *itemStatus = P6YLikedNumber(P6YLikedGet(model, @"itemStatus"));
    if (itemStatus && itemStatus.integerValue < 0) return YES;
    return P6YHQVideoURL(model) == nil && P6YHQPhotoURLs(model).count == 0;
}

static NSArray *P6YLikesModels(id manager) {
    for (NSString *key in @[@"filteredDataSource", @"dataSource", @"modelsArray", @"awemeList", @"awemes", @"items", @"dataArray", @"data"]) {
        id value = P6YLikedGet(manager, key);
        if ([value isKindOfClass:NSArray.class]) return value;
    }
    return @[];
}

static NSSet<NSString *> *P6YInvalidIDs(id manager) {
    id values = P6YLikedGet(manager, @"invalidItemIDArray");
    if (![values isKindOfClass:NSArray.class]) return [NSSet set];
    NSMutableSet *result = [NSMutableSet set];
    for (id value in (NSArray *)values) {
        NSString *identifier = [value description];
        if (identifier.length && ![identifier isEqualToString:@"(null)"]) [result addObject:identifier];
    }
    return result;
}

@interface P6YLikedToolsCoordinator : NSObject
@property (nonatomic, weak) UIViewController *controller;
@property (nonatomic, weak) UICollectionView *collectionView;
@property (nonatomic, strong) NSMutableDictionary<NSString *, id> *models;
@property (nonatomic, strong) NSMutableSet<NSString *> *selectedIDs;
@property (nonatomic, strong) NSMutableSet<NSString *> *brokenIDs;
@property (nonatomic, strong) UIView *toolbar;
@property (nonatomic, strong) UIButton *selectBrokenButton;
@property (nonatomic, strong) UIButton *selectAllButton;
@property (nonatomic, strong) UIButton *downloadButton;
@property (nonatomic, strong) UIButton *removeButton;
- (instancetype)initWithController:(UIViewController *)controller;
- (void)refresh;
- (void)toggleModel:(id)model;
- (BOOL)isSelected:(id)model;
@end

@implementation P6YLikedToolsCoordinator
- (instancetype)initWithController:(UIViewController *)controller {
    self = [super init];
    if (!self) return nil;
    _controller = controller;
    _models = [NSMutableDictionary dictionary];
    _selectedIDs = [NSMutableSet set];
    _brokenIDs = [NSMutableSet set];
    return self;
}

- (UIButton *)button:(NSString *)title action:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    [button setTitle:title forState:UIControlStateNormal];
    [button setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    button.titleLabel.font = [UIFont systemFontOfSize:10 weight:UIFontWeightBold];
    button.titleLabel.adjustsFontSizeToFitWidth = YES;
    button.backgroundColor = [UIColor colorWithWhite:0.08 alpha:0.96];
    button.layer.cornerRadius = 8;
    button.layer.borderWidth = 1;
    button.layer.borderColor = [UIColor colorWithRed:0.92 green:0 blue:0.04 alpha:1].CGColor;
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return button;
}

- (void)installToolbar {
    if (self.toolbar.superview || !self.controller.view) return;
    UIView *bar = [[UIView alloc] initWithFrame:CGRectZero];
    bar.tag = P6YLikedToolbarTag;
    bar.backgroundColor = [UIColor colorWithWhite:0.01 alpha:0.94];
    bar.layer.borderWidth = 1;
    bar.layer.borderColor = [UIColor colorWithRed:0.5 green:0 blue:0 alpha:1].CGColor;
    bar.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleWidth;

    self.selectBrokenButton = [self button:@"Broken" action:@selector(selectBroken)];
    self.selectAllButton = [self button:@"Select all" action:@selector(selectAll)];
    self.downloadButton = [self button:@"Download" action:@selector(downloadSelected)];
    self.removeButton = [self button:@"Delete broken" action:@selector(removeSelected)];
    for (UIButton *button in @[self.selectBrokenButton, self.selectAllButton, self.downloadButton, self.removeButton]) [bar addSubview:button];
    [self.controller.view addSubview:bar];
    self.toolbar = bar;
    [self layoutToolbar];
}

- (void)layoutToolbar {
    if (!self.toolbar) return;
    CGFloat safe = self.controller.view.safeAreaInsets.bottom;
    CGFloat height = 58 + safe;
    self.toolbar.frame = CGRectMake(0, self.controller.view.bounds.size.height - height, self.controller.view.bounds.size.width, height);
    CGFloat gap = 7;
    CGFloat width = (self.toolbar.bounds.size.width - gap * 5) / 4.0;
    NSArray *buttons = @[self.selectBrokenButton, self.selectAllButton, self.downloadButton, self.removeButton];
    [buttons enumerateObjectsUsingBlock:^(UIButton *button, NSUInteger index, __unused BOOL *stop) {
        button.frame = CGRectMake(gap + (width + gap) * index, 9, width, 38);
    }];
}

- (void)refresh {
    if (![P6YManager boolForKey:@"p6y_liked_post_tools"]) {
        self.toolbar.hidden = YES;
        return;
    }
    [self installToolbar];
    self.toolbar.hidden = NO;
    [self layoutToolbar];

    id manager = P6YLikedGet(self.controller, @"dataManager");
    [self.brokenIDs unionSet:P6YInvalidIDs(manager)];
    for (id model in P6YLikesModels(manager)) {
        NSString *identifier = P6YAwemeID(model);
        if (!identifier.length) continue;
        self.models[identifier] = model;
        if (P6YAwemeIsUnavailable(model)) [self.brokenIDs addObject:identifier];
    }
    NSInteger nativeInvalidCount = [P6YLikedNumber(P6YLikedGet(manager, @"invalidItemCount")) integerValue];
    NSInteger displayedBroken = MAX(nativeInvalidCount, (NSInteger)self.brokenIDs.count);

    [self.selectBrokenButton setTitle:[NSString stringWithFormat:@"Broken %ld", (long)displayedBroken] forState:UIControlStateNormal];
    BOOL allSelected = self.models.count > 0 && self.selectedIDs.count >= self.models.count;
    [self.selectAllButton setTitle:allSelected ? @"Clear" : @"Select all" forState:UIControlStateNormal];
    [self.downloadButton setTitle:[NSString stringWithFormat:@"Download %lu", (unsigned long)self.selectedIDs.count] forState:UIControlStateNormal];

    for (UICollectionViewCell *cell in self.collectionView.visibleCells) {
        id model = P6YLikedGet(cell, @"model");
        BOOL selected = [self isSelected:model];
        if ([cell respondsToSelector:NSSelectorFromString(@"displaySelection:")]) {
            ((void (*)(id, SEL, BOOL))objc_msgSend)(cell, NSSelectorFromString(@"displaySelection:"), self.selectedIDs.count > 0);
        }
        if ([cell respondsToSelector:NSSelectorFromString(@"setIsCellSelected:")]) {
            ((void (*)(id, SEL, BOOL))objc_msgSend)(cell, NSSelectorFromString(@"setIsCellSelected:"), selected);
        }
        UIButton *check = [cell viewWithTag:P6YLikedSelectionTag];
        [check setImage:[UIImage systemImageNamed:selected ? @"checkmark.circle.fill" : @"circle"] forState:UIControlStateNormal];
        check.hidden = self.selectedIDs.count == 0;
    }
}

- (void)toggleModel:(id)model {
    NSString *identifier = P6YAwemeID(model);
    if (!identifier.length) return;
    self.models[identifier] = model;
    if ([self.selectedIDs containsObject:identifier]) [self.selectedIDs removeObject:identifier];
    else [self.selectedIDs addObject:identifier];
    [self refresh];
}

- (BOOL)isSelected:(id)model {
    NSString *identifier = P6YAwemeID(model);
    return identifier.length && [self.selectedIDs containsObject:identifier];
}

- (void)selectBroken {
    if (self.brokenIDs.count == 0) {
        [P6YManager showToast:@"No broken liked posts detected"];
        return;
    }
    [self.selectedIDs unionSet:self.brokenIDs];
    [self refresh];
}

- (void)selectAll {
    if (self.models.count > 0 && self.selectedIDs.count >= self.models.count) [self.selectedIDs removeAllObjects];
    else [self.selectedIDs addObjectsFromArray:self.models.allKeys];
    [self refresh];
}

- (void)downloadSelected {
    if (self.selectedIDs.count == 0) {
        [P6YManager showToast:@"Select liked posts first"];
        return;
    }

    NSMutableArray<NSURL *> *allPhotos = [NSMutableArray array];
    NSInteger videos = 0;
    NSInteger unavailable = 0;
    for (NSString *identifier in self.selectedIDs) {
        id model = self.models[identifier];
        if (!model || [self.brokenIDs containsObject:identifier] || P6YAwemeIsUnavailable(model)) {
            unavailable += 1;
            continue;
        }
        NSArray<NSURL *> *photos = P6YHQPhotoURLs(model);
        NSURL *video = P6YHQVideoURL(model);
        if (photos.count) {
            [allPhotos addObjectsFromArray:photos];
        } else if (video) {
            [[P6YDownloadManager sharedManager] downloadURL:video kind:P6YMediaKindVideo title:@"Liked video saved at full quality"];
            videos += 1;
        } else {
            unavailable += 1;
        }
    }
    if (allPhotos.count) [[P6YDownloadManager sharedManager] downloadImageURLs:allPhotos title:@"Liked photos saved at full quality"];
    NSInteger tasksStarted = videos + (allPhotos.count > 0 ? 1 : 0);
    NSString *suffix = unavailable ? [NSString stringWithFormat:@" • %ld unavailable skipped", (long)unavailable] : @"";
    [P6YManager showToast:[NSString stringWithFormat:@"Started %ld full-quality batch task%@", (long)tasksStarted, suffix]];
}

- (void)removeSelected {
    id manager = P6YLikedGet(self.controller, @"dataManager");
    NSMutableSet *selectedBroken = [self.selectedIDs mutableCopy];
    [selectedBroken intersectSet:self.brokenIDs];
    if (selectedBroken.count == 0) {
        [P6YManager showToast:@"Select detected broken posts first"];
        return;
    }

    NSString *message = [NSString stringWithFormat:@"TikTok will clear all %lu detected broken or removed liked-post entries. Valid liked posts will not be unliked.", (unsigned long)self.brokenIDs.count];
    __weak typeof(self) weakSelf = self;
    [P6YManager presentConfirmationWithTitle:@"Delete broken liked posts" message:message from:self.controller confirmed:^{
        typeof(self) strongSelf = weakSelf;
        if (!strongSelf) return;
        SEL clearSelector = NSSelectorFromString(@"requestClearInvalidItems:");
        if ([manager respondsToSelector:clearSelector]) {
            void (^completion)(void) = ^{
                dispatch_async(dispatch_get_main_queue(), ^{
                    [strongSelf.selectedIDs minusSet:strongSelf.brokenIDs];
                    [strongSelf.brokenIDs removeAllObjects];
                    if ([strongSelf.controller respondsToSelector:NSSelectorFromString(@"reloadDataAndPageState")]) {
                        ((void (*)(id, SEL))objc_msgSend)(strongSelf.controller, NSSelectorFromString(@"reloadDataAndPageState"));
                    } else if ([strongSelf.controller respondsToSelector:NSSelectorFromString(@"refreshData")]) {
                        ((void (*)(id, SEL))objc_msgSend)(strongSelf.controller, NSSelectorFromString(@"refreshData"));
                    }
                    [strongSelf refresh];
                    [P6YManager showToast:@"Broken liked posts cleared"];
                });
            };
            ((void (*)(id, SEL, id))objc_msgSend)(manager, clearSelector, completion);
            return;
        }

        SEL removeSelector = NSSelectorFromString(@"removeWithItemID:");
        if ([manager respondsToSelector:removeSelector]) {
            for (NSString *identifier in selectedBroken) {
                ((void (*)(id, SEL, id))objc_msgSend)(manager, removeSelector, identifier);
            }
            [strongSelf.selectedIDs minusSet:selectedBroken];
            [strongSelf.brokenIDs minusSet:selectedBroken];
            [strongSelf.collectionView reloadData];
            [strongSelf refresh];
            [P6YManager showToast:@"Broken entries removed from the loaded list"];
        } else {
            [P6YManager showToast:@"TikTok's broken-post cleanup is unavailable"];
        }
    }];
}
@end

static UICollectionView *P6YFindCollectionView(UIView *root) {
    if ([root isKindOfClass:UICollectionView.class]) return (UICollectionView *)root;
    for (UIView *subview in root.subviews) {
        UICollectionView *found = P6YFindCollectionView(subview);
        if (found) return found;
    }
    return nil;
}

static P6YLikedToolsCoordinator *P6YCoordinatorForCell(UIView *cell) {
    UIResponder *responder = cell;
    while (responder) {
        if ([NSStringFromClass(responder.class) isEqualToString:@"TIKTOKLikeWorkViewController"]) {
            return objc_getAssociatedObject(responder, P6YLikedCoordinatorKey);
        }
        responder = responder.nextResponder;
    }
    return nil;
}

static void P6YConfigureLikedCell(UIView *cell) {
    if (![P6YManager boolForKey:@"p6y_liked_post_tools"]) return;
    P6YLikedToolsCoordinator *coordinator = P6YCoordinatorForCell(cell);
    if (!coordinator) return;
    id model = P6YLikedGet(cell, @"model");
    NSString *identifier = P6YAwemeID(model);
    if (identifier.length) {
        coordinator.models[identifier] = model;
        if (P6YAwemeIsUnavailable(model)) [coordinator.brokenIDs addObject:identifier];
    }

    UILabel *broken = [cell viewWithTag:P6YLikedBrokenTag];
    BOOL unavailable = identifier.length && [coordinator.brokenIDs containsObject:identifier];
    if (unavailable && !broken) {
        broken = [[UILabel alloc] init];
        broken.tag = P6YLikedBrokenTag;
        broken.text = @" REMOVED ";
        broken.textColor = UIColor.whiteColor;
        broken.backgroundColor = [UIColor colorWithRed:0.75 green:0 blue:0 alpha:0.9];
        broken.font = [UIFont systemFontOfSize:9 weight:UIFontWeightHeavy];
        broken.textAlignment = NSTextAlignmentCenter;
        broken.layer.cornerRadius = 4;
        broken.clipsToBounds = YES;
        [cell addSubview:broken];
    }
    broken.hidden = !unavailable;
    broken.frame = CGRectMake(4, 4, 72, 18);

    UIButton *check = [cell viewWithTag:P6YLikedSelectionTag];
    if (!check) {
        check = [UIButton buttonWithType:UIButtonTypeSystem];
        check.tag = P6YLikedSelectionTag;
        check.tintColor = [UIColor colorWithRed:1 green:0.05 blue:0.08 alpha:1];
        check.backgroundColor = [UIColor colorWithWhite:0 alpha:0.6];
        check.layer.cornerRadius = 13;
        check.userInteractionEnabled = NO;
        [cell addSubview:check];
    }
    [check setImage:[UIImage systemImageNamed:[coordinator isSelected:model] ? @"checkmark.circle.fill" : @"circle"] forState:UIControlStateNormal];
    check.frame = CGRectMake(MAX(4, cell.bounds.size.width - 31), 4, 27, 27);
    check.hidden = coordinator.selectedIDs.count == 0;
    [cell bringSubviewToFront:broken];
    [cell bringSubviewToFront:check];

    if (![objc_getAssociatedObject(cell, P6YLikedGestureInstalledKey) boolValue]) {
        UILongPressGestureRecognizer *gesture = [[UILongPressGestureRecognizer alloc] initWithTarget:cell action:@selector(p6y_likedSelectLongPress:)];
        gesture.minimumPressDuration = 0.35;
        gesture.cancelsTouchesInView = NO;
        gesture.delaysTouchesBegan = NO;
        [cell addGestureRecognizer:gesture];
        objc_setAssociatedObject(cell, P6YLikedGestureInstalledKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

%hook TIKTOKLikeWorkViewController
- (void)viewDidLoad {
    %orig;
    P6YLikedToolsCoordinator *coordinator = [[P6YLikedToolsCoordinator alloc] initWithController:self];
    coordinator.collectionView = P6YLikedGet(self, @"collectionView") ?: P6YFindCollectionView(self.view);
    objc_setAssociatedObject(self, P6YLikedCoordinatorKey, coordinator, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.6 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ [coordinator refresh]; });
}
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    P6YLikedToolsCoordinator *coordinator = objc_getAssociatedObject(self, P6YLikedCoordinatorKey);
    coordinator.collectionView = coordinator.collectionView ?: P6YLikedGet(self, @"collectionView") ?: P6YFindCollectionView(self.view);
    [coordinator refresh];
}
- (void)viewDidLayoutSubviews {
    %orig;
    [((P6YLikedToolsCoordinator *)objc_getAssociatedObject(self, P6YLikedCoordinatorKey)) layoutToolbar];
}
%end

%hook AWEUserWorkCollectionViewCell
- (void)didMoveToWindow {
    %orig;
    if (self.window) P6YConfigureLikedCell(self);
}
%new
- (void)p6y_likedSelectLongPress:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateBegan) return;
    P6YLikedToolsCoordinator *coordinator = P6YCoordinatorForCell(self);
    if (!coordinator) return;
    [coordinator toggleModel:P6YLikedGet(self, @"model")];
    P6YConfigureLikedCell(self);
}
%end
