#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <stdlib.h>
#import "P6YManager.h"

static const NSInteger P6YFollowerHistoryTag = 46210;
static const void *P6YProfileProcessedUIDKey = &P6YProfileProcessedUIDKey;
static const void *P6YProfileSummaryKey = &P6YProfileSummaryKey;
static const void *P6YProfileHistoryKey = &P6YProfileHistoryKey;

static id P6YAdvGet(id object, NSString *key) {
    return [P6YManager safeValueForKey:key fromObject:object];
}

static NSNumber *P6YAdvNumber(id value) {
    if ([value isKindOfClass:NSNumber.class]) return value;
    if ([value isKindOfClass:NSString.class]) return @([(NSString *)value longLongValue]);
    return nil;
}

#pragma mark - Profile follower change history

@interface P6YProfileHistoryPresenter : NSObject
+ (instancetype)shared;
- (void)showHistory:(UITapGestureRecognizer *)gesture;
@end

@implementation P6YProfileHistoryPresenter
+ (instancetype)shared {
    static id presenter;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ presenter = [self new]; });
    return presenter;
}
- (void)showHistory:(UITapGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateRecognized) return;
    NSArray *history = objc_getAssociatedObject(gesture.view, P6YProfileHistoryKey);
    NSMutableArray *lines = [NSMutableArray array];
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_GB"];
    formatter.dateFormat = @"dd/MM/yy HH:mm";
    for (NSDictionary *event in [history reverseObjectEnumerator]) {
        NSInteger delta = [event[@"delta"] integerValue];
        NSDate *date = [NSDate dateWithTimeIntervalSince1970:[event[@"observedAt"] doubleValue]];
        [lines addObject:[NSString stringWithFormat:@"%+ld observed %@", (long)delta, [formatter stringFromDate:date]]];
        if (lines.count == 10) break;
    }
    NSString *message = lines.count ? [lines componentsJoinedByString:@"\n"] : @"No follower changes have been observed yet.";
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Follower changes" message:message preferredStyle:UIAlertControllerStyleAlert];
    alert.view.tintColor = [UIColor colorWithRed:0.92 green:0 blue:0.04 alpha:1];
    [alert addAction:[UIAlertAction actionWithTitle:@"Done" style:UIAlertActionStyleCancel handler:nil]];
    [[P6YManager topViewController] presentViewController:alert animated:YES completion:nil];
}
@end

static NSString *P6YProfileUID(id user) {
    for (NSString *key in @[@"uid", @"userID", @"userId", @"secUid", @"uniqueID"]) {
        NSString *value = [P6YAdvGet(user, key) description];
        if (value.length && ![value isEqualToString:@"(null)"]) return value;
    }
    return nil;
}

static NSNumber *P6YFollowerCount(id user) {
    for (NSString *key in @[@"followerCount", @"followersCount", @"fansCount"]) {
        NSNumber *value = P6YAdvNumber(P6YAdvGet(user, key));
        if (value) return value;
    }
    return nil;
}

static NSString *P6YFollowerCountText(NSInteger count) {
    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    formatter.numberStyle = NSNumberFormatterDecimalStyle;
    return [formatter stringFromNumber:@(count)] ?: [NSString stringWithFormat:@"%ld", (long)count];
}

static void P6YRenderFollowerHistory(id adaptor, id user) {
    UIView *view = P6YAdvGet(adaptor, @"view") ?: P6YAdvGet(adaptor, @"headerView");
    if (![view isKindOfClass:UIView.class]) return;
    UILabel *label = [view viewWithTag:P6YFollowerHistoryTag];
    if (![P6YManager boolForKey:@"p6y_profile_follower_history"]) {
        [label removeFromSuperview];
        return;
    }
    NSString *uid = P6YProfileUID(user);
    NSNumber *currentNumber = P6YFollowerCount(user);
    if (!uid.length || !currentNumber) return;

    NSString *processedUID = objc_getAssociatedObject(adaptor, P6YProfileProcessedUIDKey);
    NSString *summary = objc_getAssociatedObject(adaptor, P6YProfileSummaryKey);
    NSArray *historyForLabel = objc_getAssociatedObject(adaptor, P6YProfileHistoryKey);
    if (![processedUID isEqualToString:uid]) {
        NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
        NSMutableDictionary *store = [[defaults dictionaryForKey:@"p6y_profile_follower_store"] mutableCopy] ?: [NSMutableDictionary dictionary];
        NSDictionary *previous = store[uid];
        NSInteger current = currentNumber.integerValue;
        NSTimeInterval now = NSDate.date.timeIntervalSince1970;
        NSInteger previousCount = [previous[@"count"] integerValue];
        NSTimeInterval previousVisit = [previous[@"lastVisit"] doubleValue];
        NSMutableArray *history = [previous[@"history"] mutableCopy] ?: [NSMutableArray array];
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        formatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_GB"];
        formatter.dateFormat = @"dd/MM/yy HH:mm";
        if (previous && previousVisit > 0) {
            NSInteger delta = current - previousCount;
            NSString *lastVisit = [formatter stringFromDate:[NSDate dateWithTimeIntervalSince1970:previousVisit]];
            if (delta > 0) summary = [NSString stringWithFormat:@"%@ followers  •  +%@ since %@", P6YFollowerCountText(current), P6YFollowerCountText(delta), lastVisit];
            else if (delta < 0) summary = [NSString stringWithFormat:@"%@ followers  •  -%@ since %@", P6YFollowerCountText(current), P6YFollowerCountText(labs(delta)), lastVisit];
            else summary = [NSString stringWithFormat:@"%@ followers  •  no change since %@", P6YFollowerCountText(current), lastVisit];
            if (delta != 0) [history addObject:@{@"delta": @(delta), @"observedAt": @(now)}];
        } else {
            summary = [NSString stringWithFormat:@"%@ followers  •  baseline saved %@", P6YFollowerCountText(current), [formatter stringFromDate:NSDate.date]];
        }
        if (history.count > 30) [history removeObjectsInRange:NSMakeRange(0, history.count - 30)];
        store[uid] = @{@"count": @(current), @"lastVisit": @(now), @"history": history};
        [defaults setObject:store forKey:@"p6y_profile_follower_store"];
        processedUID = uid;
        historyForLabel = history;
        objc_setAssociatedObject(adaptor, P6YProfileProcessedUIDKey, processedUID, OBJC_ASSOCIATION_COPY_NONATOMIC);
        objc_setAssociatedObject(adaptor, P6YProfileSummaryKey, summary, OBJC_ASSOCIATION_COPY_NONATOMIC);
        objc_setAssociatedObject(adaptor, P6YProfileHistoryKey, historyForLabel, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }

    if (!label) {
        label = [[UILabel alloc] init];
        label.tag = P6YFollowerHistoryTag;
        label.textColor = UIColor.whiteColor;
        label.backgroundColor = [UIColor colorWithWhite:0.02 alpha:0.86];
        label.font = [UIFont systemFontOfSize:10 weight:UIFontWeightSemibold];
        label.textAlignment = NSTextAlignmentCenter;
        label.numberOfLines = 2;
        label.layer.cornerRadius = 8;
        label.layer.borderWidth = 1;
        label.layer.borderColor = [UIColor colorWithRed:0.92 green:0 blue:0.04 alpha:1].CGColor;
        label.clipsToBounds = YES;
        label.userInteractionEnabled = YES;
        [label addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:[P6YProfileHistoryPresenter shared] action:@selector(showHistory:)]];
        [view addSubview:label];
    }
    label.text = summary;
    objc_setAssociatedObject(label, P6YProfileHistoryKey, historyForLabel ?: @[], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    CGFloat width = MIN(MAX(240, view.bounds.size.width - 24), 380);
    label.frame = CGRectMake((view.bounds.size.width - width) / 2.0, 40, width, 38);
    [view bringSubviewToFront:label];
}

static void (*P6YOrigProfileUpdateUI)(id, SEL, id) = NULL;
static void (*P6YOrigProfileConfigUser)(id, SEL, id) = NULL;
static void (*P6YOrigProfileUpdateUser)(id, SEL, id) = NULL;

static void P6YProfileUpdateUI(id self, SEL _cmd, id model) {
    if (P6YOrigProfileUpdateUI) P6YOrigProfileUpdateUI(self, _cmd, model);
    P6YRenderFollowerHistory(self, model ?: P6YAdvGet(self, @"user"));
}
static void P6YProfileConfigUser(id self, SEL _cmd, id user) {
    if (P6YOrigProfileConfigUser) P6YOrigProfileConfigUser(self, _cmd, user);
    P6YRenderFollowerHistory(self, user);
}
static void P6YProfileUpdateUser(id self, SEL _cmd, id user) {
    if (P6YOrigProfileUpdateUser) P6YOrigProfileUpdateUser(self, _cmd, user);
    P6YRenderFollowerHistory(self, user);
}

static void P6YInstallProfileHistoryHooks(void) {
    Class cls = objc_getClass("TTKProfileHeaderAdaptor");
    if (!cls) return;
    struct Hook { const char *name; IMP replacement; void **original; } hooks[] = {
        {"updateUIWithModel:", (IMP)P6YProfileUpdateUI, (void **)&P6YOrigProfileUpdateUI},
        {"configWithUser:", (IMP)P6YProfileConfigUser, (void **)&P6YOrigProfileConfigUser},
        {"updateUser:", (IMP)P6YProfileUpdateUser, (void **)&P6YOrigProfileUpdateUser},
    };
    for (NSUInteger i = 0; i < sizeof(hooks) / sizeof(hooks[0]); i++) {
        Method method = class_getInstanceMethod(cls, sel_registerName(hooks[i].name));
        if (!method) continue;
        IMP current = method_getImplementation(method);
        if (current == hooks[i].replacement) continue;
        *hooks[i].original = (void *)current;
        method_setImplementation(method, hooks[i].replacement);
    }
}

%ctor {
    dispatch_async(dispatch_get_main_queue(), ^{ P6YInstallProfileHistoryHooks(); });
}
