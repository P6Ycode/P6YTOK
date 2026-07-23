#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <math.h>
#import "P6YManager.h"

static const NSInteger P6YStoryTimeTag = 46201;
static const void *P6YStoryTimerKey = &P6YStoryTimerKey;
static const void *P6YLiveScaleKey = &P6YLiveScaleKey;
static const void *P6YLiveZoomTargetKey = &P6YLiveZoomTargetKey;

static id P6YLiveStoryGet(id object, NSString *key) {
    return [P6YManager safeValueForKey:key fromObject:object];
}

static NSNumber *P6YLiveStoryNumber(id value) {
    if ([value isKindOfClass:NSNumber.class]) return value;
    if ([value isKindOfClass:NSString.class]) return @([(NSString *)value longLongValue]);
    if ([value isKindOfClass:NSDate.class]) return @([(NSDate *)value timeIntervalSince1970]);
    return nil;
}

#pragma mark - LIVE pinch zoom

static UIView *P6YFindLargestLiveVideoView(UIView *root) {
    if (!root) return nil;
    UIView *best = nil;
    CGFloat bestScore = 0;
    NSMutableArray<UIView *> *queue = [NSMutableArray arrayWithObject:root];
    while (queue.count) {
        UIView *view = queue.firstObject;
        [queue removeObjectAtIndex:0];
        NSString *name = NSStringFromClass(view.class).lowercaseString;
        CGFloat area = CGRectGetWidth(view.bounds) * CGRectGetHeight(view.bounds);
        BOOL likelyVideo = [name containsString:@"player"] || [name containsString:@"video"] || [name containsString:@"render"] || [name containsString:@"metal"] || [name containsString:@"stream"] || [name containsString:@"texture"];
        CGFloat score = area * (likelyVideo ? 4.0 : 1.0);
        if (!view.hidden && view.alpha > 0.01 && score > bestScore) {
            best = view;
            bestScore = score;
        }
        [queue addObjectsFromArray:view.subviews];
    }
    return best ?: root;
}

%hook IESLiveMTAudienceViewController
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    if (![P6YManager boolForKey:@"p6y_live_zoom"]) return;
    for (UIGestureRecognizer *gesture in self.view.gestureRecognizers) {
        if ([gesture.name isEqualToString:@"P6YTOKLivePinch"]) return;
    }

    UIPinchGestureRecognizer *pinch = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(p6y_livePinch:)];
    pinch.name = @"P6YTOKLivePinch";
    pinch.cancelsTouchesInView = NO;
    pinch.delaysTouchesBegan = NO;
    [self.view addGestureRecognizer:pinch];

    UITapGestureRecognizer *reset = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(p6y_liveZoomReset:)];
    reset.name = @"P6YTOKLiveZoomReset";
    reset.numberOfTapsRequired = 2;
    reset.numberOfTouchesRequired = 2;
    reset.cancelsTouchesInView = NO;
    [self.view addGestureRecognizer:reset];
}

- (void)viewDidDisappear:(BOOL)animated {
    UIView *target = objc_getAssociatedObject(self, P6YLiveZoomTargetKey);
    target.transform = CGAffineTransformIdentity;
    objc_setAssociatedObject(self, P6YLiveScaleKey, @1.0, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(self, P6YLiveZoomTargetKey, nil, OBJC_ASSOCIATION_ASSIGN);
    %orig;
}

%new
- (void)p6y_livePinch:(UIPinchGestureRecognizer *)gesture {
    if (![P6YManager boolForKey:@"p6y_live_zoom"]) return;
    UIView *target = objc_getAssociatedObject(self, P6YLiveZoomTargetKey);
    if (!target || !target.window) {
        target = P6YFindLargestLiveVideoView(self.view);
        objc_setAssociatedObject(self, P6YLiveZoomTargetKey, target, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    CGFloat stored = [objc_getAssociatedObject(self, P6YLiveScaleKey) doubleValue];
    if (stored < 1.0) stored = 1.0;

    if (gesture.state == UIGestureRecognizerStateBegan || gesture.state == UIGestureRecognizerStateChanged) {
        CGFloat scale = MIN(4.0, MAX(1.0, stored * gesture.scale));
        target.transform = CGAffineTransformMakeScale(scale, scale);
    } else if (gesture.state == UIGestureRecognizerStateEnded || gesture.state == UIGestureRecognizerStateCancelled || gesture.state == UIGestureRecognizerStateFailed) {
        CGFloat scale = hypot(target.transform.a, target.transform.c);
        scale = MIN(4.0, MAX(1.0, scale));
        objc_setAssociatedObject(self, P6YLiveScaleKey, @(scale), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        gesture.scale = 1.0;
    }
}

%new
- (void)p6y_liveZoomReset:(UITapGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateRecognized) return;
    UIView *target = objc_getAssociatedObject(self, P6YLiveZoomTargetKey) ?: P6YFindLargestLiveVideoView(self.view);
    [UIView animateWithDuration:0.2 animations:^{ target.transform = CGAffineTransformIdentity; }];
    objc_setAssociatedObject(self, P6YLiveScaleKey, @1.0, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
%end

#pragma mark - Story posted, expiration, and remaining time

static id P6YStoryModel(id cell) {
    id controller = P6YLiveStoryGet(cell, @"viewController");
    for (NSString *key in @[@"currentPlayingStory", @"currentAweme", @"currentPlayingAweme", @"model"]) {
        id model = P6YLiveStoryGet(controller, key);
        if (model) return model;
    }
    return P6YLiveStoryGet(cell, @"model");
}

static NSTimeInterval P6YTimestamp(id value) {
    NSTimeInterval timestamp = [P6YLiveStoryNumber(value) doubleValue];
    if (timestamp > 1000000000000.0) timestamp /= 1000.0;
    return timestamp;
}

static NSTimeInterval P6YStoryCreateTime(id model) {
    for (NSString *key in @[@"createTime", @"create_time", @"publishTime", @"storyCreateTime"]) {
        NSTimeInterval value = P6YTimestamp(P6YLiveStoryGet(model, key));
        if (value > 0) return value;
    }
    return 0;
}

static NSTimeInterval P6YStoryExpireTime(id model, NSTimeInterval createTime) {
    id metadata = P6YLiveStoryGet(model, @"storyMetaData");
    NSTimeInterval verified = P6YTimestamp(P6YLiveStoryGet(metadata, @"expiredAt"));
    if (verified > 0) return verified;

    for (id object in @[model ?: NSNull.null, P6YLiveStoryGet(model, @"storyInfo") ?: NSNull.null]) {
        if (object == NSNull.null) continue;
        for (NSString *key in @[@"expiredAt", @"expireAt", @"expireTime", @"storyExpireTime", @"expirationTime"]) {
            NSTimeInterval value = P6YTimestamp(P6YLiveStoryGet(object, key));
            if (value > 0) return value;
        }
    }
    return createTime > 0 ? createTime + 24.0 * 60.0 * 60.0 : 0;
}

static NSDateFormatter *P6YStoryClockFormatter(void) {
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_GB"];
    formatter.dateFormat = @"HH:mm";
    return formatter;
}

static void P6YUpdateStoryClock(UIView *cell) {
    UILabel *label = [cell viewWithTag:P6YStoryTimeTag];
    if (![P6YManager boolForKey:@"p6y_story_time"]) {
        [label removeFromSuperview];
        return;
    }

    id model = P6YStoryModel(cell);
    NSTimeInterval created = P6YStoryCreateTime(model);
    NSTimeInterval expires = P6YStoryExpireTime(model, created);
    if (created <= 0 || expires <= 0) {
        [label removeFromSuperview];
        return;
    }

    if (!label) {
        label = [[UILabel alloc] init];
        label.tag = P6YStoryTimeTag;
        label.textColor = UIColor.whiteColor;
        label.backgroundColor = [UIColor colorWithWhite:0.02 alpha:0.84];
        label.layer.cornerRadius = 9;
        label.layer.borderWidth = 1;
        label.layer.borderColor = [UIColor colorWithRed:0.92 green:0 blue:0.04 alpha:1].CGColor;
        label.clipsToBounds = YES;
        label.font = [UIFont monospacedDigitSystemFontOfSize:11 weight:UIFontWeightSemibold];
        label.textAlignment = NSTextAlignmentCenter;
        label.numberOfLines = 1;
        [cell addSubview:label];
    }

    NSDateFormatter *formatter = P6YStoryClockFormatter();
    NSString *posted = [formatter stringFromDate:[NSDate dateWithTimeIntervalSince1970:created]];
    NSString *expiresAt = [formatter stringFromDate:[NSDate dateWithTimeIntervalSince1970:expires]];
    NSInteger seconds = MAX(0, (NSInteger)llround(expires - NSDate.date.timeIntervalSince1970));
    NSInteger hours = seconds / 3600;
    NSInteger minutes = (seconds % 3600) / 60;
    NSInteger remainingSeconds = seconds % 60;
    label.text = seconds > 0
        ? [NSString stringWithFormat:@"  Posted %@  •  Expires %@  •  %02ld:%02ld:%02ld left  ", posted, expiresAt, (long)hours, (long)minutes, (long)remainingSeconds]
        : [NSString stringWithFormat:@"  Posted %@  •  Expired %@  ", posted, expiresAt];

    CGSize size = [label sizeThatFits:CGSizeMake(cell.bounds.size.width - 16, 30)];
    CGFloat width = MIN(cell.bounds.size.width - 16, MAX(260, size.width + 8));
    label.frame = CGRectMake((cell.bounds.size.width - width) / 2.0, cell.safeAreaInsets.top + 12, width, 30);
    [cell bringSubviewToFront:label];
}

%hook TTKStoryDetailTableViewCell
- (void)didMoveToWindow {
    %orig;
    NSTimer *oldTimer = objc_getAssociatedObject(self, P6YStoryTimerKey);
    [oldTimer invalidate];
    objc_setAssociatedObject(self, P6YStoryTimerKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if (!self.window || ![P6YManager boolForKey:@"p6y_story_time"]) return;

    P6YUpdateStoryClock(self);
    __weak UIView *weakCell = self;
    NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:1.0 repeats:YES block:^(__unused NSTimer *runningTimer) {
        UIView *cell = weakCell;
        if (!cell.window) { [runningTimer invalidate]; return; }
        P6YUpdateStoryClock(cell);
    }];
    objc_setAssociatedObject(self, P6YStoryTimerKey, timer, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)prepareForReuse {
    NSTimer *timer = objc_getAssociatedObject(self, P6YStoryTimerKey);
    [timer invalidate];
    objc_setAssociatedObject(self, P6YStoryTimerKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [[self viewWithTag:P6YStoryTimeTag] removeFromSuperview];
    %orig;
}
%end
