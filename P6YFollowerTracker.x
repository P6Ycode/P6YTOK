#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <stdlib.h>
#import "P6YManager.h"

static const NSInteger P6YFollowerTrackerButtonTag = 46011;
static NSString * const P6YFollowerTrackerStoreKey = @"p6y_follower_tracker_records_v1";
static const void *P6YFollowerTrackerSessionKey = &P6YFollowerTrackerSessionKey;
static const void *P6YFollowerTrackerProfileKey = &P6YFollowerTrackerProfileKey;

static id P6YFollowerGet(id object, NSString *key) {
    return [P6YManager safeValueForKey:key fromObject:object];
}

static NSString *P6YFollowerString(id value) {
    if ([value isKindOfClass:NSString.class]) return value;
    if ([value respondsToSelector:@selector(stringValue)]) return [value stringValue];
    return nil;
}

static BOOL P6YFollowerNumber(id value, long long *result) {
    if ([value isKindOfClass:NSNumber.class]) {
        if (result) *result = [value longLongValue];
        return YES;
    }
    if (![value isKindOfClass:NSString.class] || [(NSString *)value length] == 0) return NO;

    NSString *clean = [[(NSString *)value stringByReplacingOccurrencesOfString:@"," withString:@""]
                       stringByReplacingOccurrencesOfString:@" " withString:@""];
    NSScanner *scanner = [NSScanner scannerWithString:clean];
    long long number = 0;
    if (![scanner scanLongLong:&number]) return NO;
    if (result) *result = number;
    return YES;
}

static NSString *P6YFollowerProfileIdentifier(id user) {
    for (NSString *key in @[@"uid", @"userID", @"userId", @"user_id", @"secUid", @"secUID", @"uniqueID", @"uniqueId", @"shortID"]) {
        NSString *value = P6YFollowerString(P6YFollowerGet(user, key));
        if (value.length) return [NSString stringWithFormat:@"%@:%@", key, value];
    }
    return nil;
}

static NSString *P6YFollowerDisplayName(id user) {
    for (NSString *key in @[@"nickname", @"uniqueID", @"uniqueId", @"shortID", @"uid"]) {
        NSString *value = P6YFollowerString(P6YFollowerGet(user, key));
        if (value.length) return value;
    }
    return @"TikTok profile";
}

static BOOL P6YFollowerCount(id user, long long *result) {
    NSArray<NSString *> *keys = @[@"followerCount", @"followersCount", @"followerCnt", @"fansCount", @"fanCount"];
    for (NSString *key in keys) {
        long long value = 0;
        if (P6YFollowerNumber(P6YFollowerGet(user, key), &value) && value >= 0) {
            if (result) *result = value;
            return YES;
        }
    }

    for (NSString *containerKey in @[@"statistics", @"stats", @"userStats", @"userStatistics"]) {
        id container = P6YFollowerGet(user, containerKey);
        for (NSString *key in keys) {
            long long value = 0;
            if (P6YFollowerNumber(P6YFollowerGet(container, key), &value) && value >= 0) {
                if (result) *result = value;
                return YES;
            }
        }
    }
    return NO;
}

static NSString *P6YFollowerFormattedCount(long long count) {
    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    formatter.numberStyle = NSNumberFormatterDecimalStyle;
    return [formatter stringFromNumber:@(count)] ?: [NSString stringWithFormat:@"%lld", count];
}

static NSString *P6YFollowerDateString(NSTimeInterval timestamp, BOOL compact) {
    if (timestamp <= 0) return @"Unknown";
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    formatter.dateFormat = compact ? @"MM/dd HH:mm" : @"yyyy-MM-dd HH:mm:ss";
    return [formatter stringFromDate:[NSDate dateWithTimeIntervalSince1970:timestamp]];
}

static NSMutableDictionary *P6YFollowerMutableStore(void) {
    NSDictionary *stored = [NSUserDefaults.standardUserDefaults dictionaryForKey:P6YFollowerTrackerStoreKey];
    return stored ? [stored mutableCopy] : [NSMutableDictionary dictionary];
}

static void P6YFollowerPruneStore(NSMutableDictionary *store) {
    if (store.count <= 250) return;
    NSArray<NSString *> *keys = [store keysSortedByValueUsingComparator:^NSComparisonResult(NSDictionary *left, NSDictionary *right) {
        NSTimeInterval a = [left[@"lastVisit"] doubleValue];
        NSTimeInterval b = [right[@"lastVisit"] doubleValue];
        if (a < b) return NSOrderedAscending;
        if (a > b) return NSOrderedDescending;
        return NSOrderedSame;
    }];
    NSUInteger removeCount = store.count - 200;
    for (NSUInteger index = 0; index < MIN(removeCount, keys.count); index++) {
        [store removeObjectForKey:keys[index]];
    }
}

static NSDictionary *P6YFollowerObserve(id adaptor, id user) {
    NSString *profileKey = P6YFollowerProfileIdentifier(user);
    long long currentCount = 0;
    if (!profileKey.length || !P6YFollowerCount(user, &currentCount)) return nil;

    NSDictionary *session = objc_getAssociatedObject(adaptor, P6YFollowerTrackerSessionKey);
    if ([session[@"profileKey"] isEqualToString:profileKey]) return session;

    NSTimeInterval now = NSDate.date.timeIntervalSince1970;
    NSMutableDictionary *store = P6YFollowerMutableStore();
    NSMutableDictionary *record = [store[profileKey] mutableCopy] ?: [NSMutableDictionary dictionary];
    NSNumber *previousCountNumber = record[@"count"];
    long long previousCount = previousCountNumber.longLongValue;
    NSTimeInterval previousVisit = [record[@"lastVisit"] doubleValue];
    BOOL firstVisit = previousCountNumber == nil;
    long long delta = firstVisit ? 0 : currentCount - previousCount;

    NSMutableArray *history = [record[@"history"] mutableCopy] ?: [NSMutableArray array];
    if (!firstVisit && delta != 0) {
        NSDictionary *event = @{
            @"delta": @(delta),
            @"fromCount": @(previousCount),
            @"toCount": @(currentCount),
            @"previousVisit": @(previousVisit),
            @"observedAt": @(now)
        };
        [history insertObject:event atIndex:0];
        if (history.count > 50) [history removeObjectsInRange:NSMakeRange(50, history.count - 50)];
    }

    NSString *displayName = P6YFollowerDisplayName(user);
    record[@"displayName"] = displayName;
    record[@"count"] = @(currentCount);
    record[@"lastVisit"] = @(now);
    record[@"history"] = history;
    store[profileKey] = record;
    P6YFollowerPruneStore(store);
    [NSUserDefaults.standardUserDefaults setObject:store forKey:P6YFollowerTrackerStoreKey];

    NSDictionary *snapshot = @{
        @"profileKey": profileKey,
        @"displayName": displayName,
        @"count": @(currentCount),
        @"delta": @(delta),
        @"firstVisit": @(firstVisit),
        @"previousVisit": @(previousVisit),
        @"observedAt": @(now)
    };
    objc_setAssociatedObject(adaptor, P6YFollowerTrackerSessionKey, snapshot, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return snapshot;
}

@interface P6YFollowerHistoryPresenter : NSObject
+ (instancetype)sharedPresenter;
- (void)showHistory:(UIButton *)sender;
@end

@implementation P6YFollowerHistoryPresenter

+ (instancetype)sharedPresenter {
    static P6YFollowerHistoryPresenter *presenter;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ presenter = [[self alloc] init]; });
    return presenter;
}

- (void)showHistory:(UIButton *)sender {
    NSString *profileKey = objc_getAssociatedObject(sender, P6YFollowerTrackerProfileKey);
    NSDictionary *record = [NSUserDefaults.standardUserDefaults dictionaryForKey:P6YFollowerTrackerStoreKey][profileKey];
    if (!record) return;

    NSMutableArray<NSString *> *lines = [NSMutableArray array];
    [lines addObject:[NSString stringWithFormat:@"Current: %@ followers", P6YFollowerFormattedCount([record[@"count"] longLongValue])]];
    [lines addObject:[NSString stringWithFormat:@"Last observed: %@", P6YFollowerDateString([record[@"lastVisit"] doubleValue], NO)]];

    NSArray *history = record[@"history"];
    if (history.count == 0) {
        [lines addObject:@"\nNo follower-count changes have been observed yet."];
    } else {
        [lines addObject:@"\nObserved changes:"];
        NSUInteger limit = MIN((NSUInteger)10, history.count);
        for (NSUInteger index = 0; index < limit; index++) {
            NSDictionary *event = history[index];
            long long delta = [event[@"delta"] longLongValue];
            NSString *direction = delta > 0 ? @"GAIN" : @"LOSS";
            NSString *amount = P6YFollowerFormattedCount(llabs(delta));
            NSString *from = P6YFollowerDateString([event[@"previousVisit"] doubleValue], NO);
            NSString *to = P6YFollowerDateString([event[@"observedAt"] doubleValue], NO);
            [lines addObject:[NSString stringWithFormat:@"\n%@ %@ followers\n%@ → %@", direction, amount, from, to]];
        }
    }
    [lines addObject:@"\nTimes are observation windows from profile visits, not TikTok's exact individual follow or unfollow timestamps."];

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:record[@"displayName"] ?: @"Follower history"
                                                                   message:[lines componentsJoinedByString:@"\n"]
                                                            preferredStyle:UIAlertControllerStyleAlert];
    alert.view.tintColor = [UIColor colorWithRed:0.90 green:0 blue:0.04 alpha:1.0];
    [alert addAction:[UIAlertAction actionWithTitle:@"Close" style:UIAlertActionStyleCancel handler:nil]];
    [[P6YManager topViewController] presentViewController:alert animated:YES completion:nil];
}

@end

static void P6YFollowerUpdateButton(id adaptor, id user) {
    UIView *view = P6YFollowerGet(adaptor, @"view");
    if (![view isKindOfClass:UIView.class]) return;

    UIButton *button = [view viewWithTag:P6YFollowerTrackerButtonTag];
    if (![P6YManager boolForKey:@"p6y_follower_tracker"]) {
        [button removeFromSuperview];
        return;
    }

    NSDictionary *snapshot = P6YFollowerObserve(adaptor, user);
    if (!snapshot) {
        [button removeFromSuperview];
        return;
    }

    if (!button) {
        button = [UIButton buttonWithType:UIButtonTypeSystem];
        button.tag = P6YFollowerTrackerButtonTag;
        button.backgroundColor = [UIColor colorWithWhite:0.02 alpha:0.88];
        button.layer.cornerRadius = 9;
        button.layer.borderWidth = 1;
        button.layer.borderColor = [UIColor colorWithRed:0.90 green:0 blue:0.04 alpha:1.0].CGColor;
        button.clipsToBounds = YES;
        button.titleLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightSemibold];
        button.titleLabel.numberOfLines = 2;
        button.titleLabel.textAlignment = NSTextAlignmentCenter;
        button.contentEdgeInsets = UIEdgeInsetsMake(4, 8, 4, 8);
        button.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleBottomMargin;
        [button addTarget:[P6YFollowerHistoryPresenter sharedPresenter] action:@selector(showHistory:) forControlEvents:UIControlEventTouchUpInside];
        [view addSubview:button];
    }

    BOOL firstVisit = [snapshot[@"firstVisit"] boolValue];
    long long delta = [snapshot[@"delta"] longLongValue];
    long long count = [snapshot[@"count"] longLongValue];
    NSTimeInterval previousVisit = [snapshot[@"previousVisit"] doubleValue];
    NSTimeInterval observedAt = [snapshot[@"observedAt"] doubleValue];

    NSString *title = nil;
    UIColor *titleColor = UIColor.whiteColor;
    if (firstVisit) {
        title = [NSString stringWithFormat:@"Tracking started • %@ followers\n%@", P6YFollowerFormattedCount(count), P6YFollowerDateString(observedAt, YES)];
    } else if (delta > 0) {
        titleColor = [UIColor colorWithRed:0.25 green:0.92 blue:0.45 alpha:1.0];
        title = [NSString stringWithFormat:@"↑ +%@ since %@\nObserved %@", P6YFollowerFormattedCount(delta), P6YFollowerDateString(previousVisit, YES), P6YFollowerDateString(observedAt, YES)];
    } else if (delta < 0) {
        titleColor = [UIColor colorWithRed:1.0 green:0.16 blue:0.20 alpha:1.0];
        title = [NSString stringWithFormat:@"↓ -%@ since %@\nObserved %@", P6YFollowerFormattedCount(llabs(delta)), P6YFollowerDateString(previousVisit, YES), P6YFollowerDateString(observedAt, YES)];
    } else {
        title = [NSString stringWithFormat:@"No change since %@\n%@ followers", P6YFollowerDateString(previousVisit, YES), P6YFollowerFormattedCount(count)];
    }

    [button setTitle:title forState:UIControlStateNormal];
    [button setTitleColor:titleColor forState:UIControlStateNormal];
    objc_setAssociatedObject(button, P6YFollowerTrackerProfileKey, snapshot[@"profileKey"], OBJC_ASSOCIATION_COPY_NONATOMIC);

    CGFloat width = MIN(290.0, MAX(210.0, view.bounds.size.width - 24.0));
    button.frame = CGRectMake(MAX(8.0, view.bounds.size.width - width - 12.0), 42.0, width, 48.0);
    [view bringSubviewToFront:button];
}

%hook TTKProfileHeaderAdaptor

- (void)updateUIWithModel:(id)model {
    %orig(model);
    P6YFollowerUpdateButton(self, model ?: P6YFollowerGet(self, @"user"));
}

- (void)configWithUser:(id)user {
    %orig(user);
    P6YFollowerUpdateButton(self, user);
}

- (void)updateUser:(id)user {
    %orig(user);
    P6YFollowerUpdateButton(self, user);
}

%end
