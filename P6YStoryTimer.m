#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <math.h>
#import "P6YManager.h"

static const NSInteger P6YStoryTimerLabelTag = 46030;
static const void *P6YStoryTimerTokenKey = &P6YStoryTimerTokenKey;
static const void *P6YStoryTimerModelKey = &P6YStoryTimerModelKey;
static const void *P6YStoryCreateTimeKey = &P6YStoryCreateTimeKey;
static const void *P6YStoryExpireTimeKey = &P6YStoryExpireTimeKey;

@interface P6YStoryTimerToken : NSObject
@property (nonatomic, weak) UIView *cell;
@property (nonatomic, strong) NSTimer *timer;
@end

@implementation P6YStoryTimerToken
- (void)dealloc {
    [self.timer invalidate];
}
@end

static id P6YStoryGet(id object, NSString *key) {
    return [P6YManager safeValueForKey:key fromObject:object];
}

static NSTimeInterval P6YStoryTimestamp(id value) {
    if ([value isKindOfClass:NSDate.class]) return [(NSDate *)value timeIntervalSince1970];

    double timestamp = 0;
    if ([value isKindOfClass:NSNumber.class]) {
        timestamp = [(NSNumber *)value doubleValue];
    } else if ([value isKindOfClass:NSString.class]) {
        NSString *string = [(NSString *)value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        NSScanner *scanner = [NSScanner scannerWithString:string];
        double numeric = 0;
        if ([scanner scanDouble:&numeric] && scanner.isAtEnd) {
            timestamp = numeric;
        } else if (string.length) {
            NSISO8601DateFormatter *iso = [[NSISO8601DateFormatter alloc] init];
            NSDate *date = [iso dateFromString:string];
            if (!date) {
                NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
                formatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
                for (NSString *format in @[@"yyyy-MM-dd HH:mm:ss", @"yyyy-MM-dd'T'HH:mm:ss", @"yyyy-MM-dd'T'HH:mm:ss.SSSZ"]) {
                    formatter.dateFormat = format;
                    date = [formatter dateFromString:string];
                    if (date) break;
                }
            }
            timestamp = date.timeIntervalSince1970;
        }
    }

    if (!isfinite(timestamp) || timestamp <= 0) return 0;
    while (timestamp > 100000000000.0) timestamp /= 1000.0;
    return timestamp;
}

static NSArray *P6YStoryTimeSources(id model) {
    if (!model) return @[];
    NSMutableArray *sources = [NSMutableArray arrayWithObject:model];
    for (NSString *key in @[@"story", @"storyInfo", @"storyModel", @"storyData", @"aweme", @"item", @"content"]) {
        id value = P6YStoryGet(model, key);
        if (value && ![sources containsObject:value]) [sources addObject:value];
    }
    return sources;
}

static NSTimeInterval P6YStoryTimeForKeys(NSArray *sources, NSArray<NSString *> *keys) {
    for (id source in sources) {
        for (NSString *key in keys) {
            NSTimeInterval timestamp = P6YStoryTimestamp(P6YStoryGet(source, key));
            if (timestamp > 0) return timestamp;
        }
    }
    return 0;
}

static id P6YStoryResolveModel(id cell) {
    for (NSString *key in @[@"model", @"aweme", @"storyModel", @"currentStory", @"currentPlayingStory", @"currentAweme", @"itemModel"]) {
        id model = P6YStoryGet(cell, key);
        if (model) return model;
    }

    id controller = P6YStoryGet(cell, @"viewController");
    for (NSString *key in @[@"model", @"aweme", @"storyModel", @"currentStory", @"currentPlayingStory", @"currentAweme"]) {
        id model = P6YStoryGet(controller, key);
        if (model) return model;
    }
    return nil;
}

static UILabel *P6YStoryLabel(UIView *cell, BOOL create) {
    UILabel *label = [cell viewWithTag:P6YStoryTimerLabelTag];
    if (label || !create) return label;

    label = [[UILabel alloc] init];
    label.tag = P6YStoryTimerLabelTag;
    label.backgroundColor = [UIColor colorWithWhite:0.02 alpha:0.84];
    label.textColor = UIColor.whiteColor;
    label.font = [UIFont monospacedDigitSystemFontOfSize:11 weight:UIFontWeightSemibold];
    label.textAlignment = NSTextAlignmentCenter;
    label.numberOfLines = 2;
    label.layer.cornerRadius = 9;
    label.layer.borderWidth = 1;
    label.layer.borderColor = [UIColor colorWithRed:0.90 green:0 blue:0.04 alpha:1.0].CGColor;
    label.clipsToBounds = YES;
    label.userInteractionEnabled = NO;
    label.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleBottomMargin;
    [cell addSubview:label];
    return label;
}

static NSString *P6YStoryPostedString(NSTimeInterval timestamp) {
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    formatter.dateFormat = @"MM/dd HH:mm:ss";
    return [formatter stringFromDate:[NSDate dateWithTimeIntervalSince1970:timestamp]];
}

static NSString *P6YStoryRemainingString(NSTimeInterval seconds) {
    long long total = MAX(0LL, (long long)ceil(seconds));
    long long hours = total / 3600;
    long long minutes = (total % 3600) / 60;
    long long remainder = total % 60;
    return [NSString stringWithFormat:@"%02lld:%02lld:%02lld", hours, minutes, remainder];
}

static void P6YStoryLayoutLabel(UIView *cell) {
    UILabel *label = P6YStoryLabel(cell, NO);
    if (!label || label.hidden) return;

    CGFloat width = MIN(196.0, MAX(150.0, cell.bounds.size.width - 24.0));
    CGFloat x = MAX(12.0, cell.bounds.size.width - width - 12.0);
    CGFloat y = cell.safeAreaInsets.top + 34.0;
    label.frame = CGRectMake(x, y, width, 42.0);
    [cell bringSubviewToFront:label];
}

static void P6YStoryStopTimer(UIView *cell, BOOL removeLabel) {
    objc_setAssociatedObject(cell, P6YStoryTimerTokenKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if (removeLabel) {
        [[cell viewWithTag:P6YStoryTimerLabelTag] removeFromSuperview];
        objc_setAssociatedObject(cell, P6YStoryTimerModelKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(cell, P6YStoryCreateTimeKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(cell, P6YStoryExpireTimeKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

static void P6YStoryRefresh(UIView *cell) {
    UILabel *label = P6YStoryLabel(cell, NO);
    NSTimeInterval createTime = [objc_getAssociatedObject(cell, P6YStoryCreateTimeKey) doubleValue];
    NSTimeInterval expireTime = [objc_getAssociatedObject(cell, P6YStoryExpireTimeKey) doubleValue];
    if (!label || createTime <= 0 || expireTime <= 0) return;

    NSTimeInterval remaining = expireTime - NSDate.date.timeIntervalSince1970;
    label.text = [NSString stringWithFormat:@"Posted %@\nRemaining %@",
                  P6YStoryPostedString(createTime), P6YStoryRemainingString(remaining)];
    label.hidden = NO;
    P6YStoryLayoutLabel(cell);

    if (remaining <= 0) objc_setAssociatedObject(cell, P6YStoryTimerTokenKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static void P6YStoryStartTimer(UIView *cell) {
    if (!cell.window || objc_getAssociatedObject(cell, P6YStoryTimerTokenKey)) return;
    if ([objc_getAssociatedObject(cell, P6YStoryExpireTimeKey) doubleValue] <= NSDate.date.timeIntervalSince1970) return;

    P6YStoryTimerToken *token = [[P6YStoryTimerToken alloc] init];
    token.cell = cell;
    __weak P6YStoryTimerToken *weakToken = token;
    token.timer = [NSTimer timerWithTimeInterval:1.0 repeats:YES block:^(__unused NSTimer *timer) {
        UIView *visibleCell = weakToken.cell;
        if (!visibleCell || !visibleCell.window) return;
        P6YStoryRefresh(visibleCell);
    }];
    [[NSRunLoop mainRunLoop] addTimer:token.timer forMode:NSRunLoopCommonModes];
    objc_setAssociatedObject(cell, P6YStoryTimerTokenKey, token, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static void P6YStoryAttach(UIView *cell, id model) {
    if (![P6YManager boolForKey:@"p6y_story_timer"]) {
        P6YStoryStopTimer(cell, YES);
        return;
    }

    model = model ?: P6YStoryResolveModel(cell);
    if (!model) return;

    id previousModel = objc_getAssociatedObject(cell, P6YStoryTimerModelKey);
    if (previousModel != model) P6YStoryStopTimer(cell, NO);

    NSArray *sources = P6YStoryTimeSources(model);
    NSTimeInterval createTime = P6YStoryTimeForKeys(sources, @[@"createTime", @"createTimestamp", @"publishTime", @"postTime", @"storyCreateTime", @"createdAt"]);
    NSTimeInterval expireTime = P6YStoryTimeForKeys(sources, @[@"expireTime", @"expirationTime", @"storyExpireTime", @"storyExpirationTime", @"expireAt", @"expiredAt", @"expirationTimestamp", @"storyExpireAt"]);

    if (createTime <= 0) {
        P6YStoryStopTimer(cell, YES);
        return;
    }
    if (expireTime > 0 && expireTime < 604800.0) expireTime = createTime + expireTime;
    if (expireTime <= createTime) expireTime = createTime + 24.0 * 60.0 * 60.0;

    objc_setAssociatedObject(cell, P6YStoryTimerModelKey, model, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(cell, P6YStoryCreateTimeKey, @(createTime), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(cell, P6YStoryExpireTimeKey, @(expireTime), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    P6YStoryLabel(cell, YES);
    P6YStoryRefresh(cell);
    P6YStoryStartTimer(cell);
}

static void P6YStoryInstallModelHook(Class cls, SEL selector) {
    Method method = class_getInstanceMethod(cls, selector);
    if (!method) return;
    IMP original = class_getMethodImplementation(cls, selector);
    const char *types = method_getTypeEncoding(method);
    IMP replacement = imp_implementationWithBlock(^(id object, id model) {
        ((void (*)(id, SEL, id))original)(object, selector, model);
        if ([object isKindOfClass:UIView.class]) P6YStoryAttach(object, model);
    });
    class_replaceMethod(cls, selector, replacement, types);
}

static void P6YStoryInstallVoidHook(Class cls, SEL selector, void (^after)(UIView *cell)) {
    Method method = class_getInstanceMethod(cls, selector);
    if (!method) return;
    IMP original = class_getMethodImplementation(cls, selector);
    const char *types = method_getTypeEncoding(method);
    IMP replacement = imp_implementationWithBlock(^(id object) {
        ((void (*)(id, SEL))original)(object, selector);
        if ([object isKindOfClass:UIView.class] && after) after(object);
    });
    class_replaceMethod(cls, selector, replacement, types);
}

static NSMutableSet<NSString *> *P6YStoryInstalledClasses(void) {
    static NSMutableSet<NSString *> *classes;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ classes = [NSMutableSet set]; });
    return classes;
}

static void P6YStoryInstallClass(Class cls) {
    if (!cls) return;
    NSString *name = NSStringFromClass(cls);
    if ([P6YStoryInstalledClasses() containsObject:name]) return;
    [P6YStoryInstalledClasses() addObject:name];

    P6YStoryInstallModelHook(cls, NSSelectorFromString(@"configWithModel:"));
    P6YStoryInstallModelHook(cls, NSSelectorFromString(@"configureWithModel:"));
    P6YStoryInstallVoidHook(cls, @selector(layoutSubviews), ^(UIView *cell) {
        P6YStoryAttach(cell, nil);
        P6YStoryLayoutLabel(cell);
    });
    P6YStoryInstallVoidHook(cls, @selector(didMoveToWindow), ^(UIView *cell) {
        if (cell.window) P6YStoryAttach(cell, nil);
        else P6YStoryStopTimer(cell, NO);
    });
    P6YStoryInstallVoidHook(cls, NSSelectorFromString(@"prepareForReuse"), ^(UIView *cell) {
        P6YStoryStopTimer(cell, YES);
    });
}

static void P6YStoryInstallAttempt(NSUInteger attempt) {
    NSArray<NSString *> *targets = @[
        @"TTKStoryDetailTableViewCell",
        @"TTKStory2FeedCollectionViewCell",
        @"TTKStoryFeedTableViewCell"
    ];
    for (NSString *name in targets) P6YStoryInstallClass(NSClassFromString(name));

    if (attempt < 20 && P6YStoryInstalledClasses().count < targets.count) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            P6YStoryInstallAttempt(attempt + 1);
        });
    }
}

__attribute__((constructor)) static void P6YStoryTimerInitialize(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        [P6YManager registerDefaults];
        P6YStoryInstallAttempt(0);
    });
}
