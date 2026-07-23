#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>
#import <string.h>
#import "P6YManager.h"

static const void *P6YLivePinchKey = &P6YLivePinchKey;
static const void *P6YLiveResetTapKey = &P6YLiveResetTapKey;
static const void *P6YLiveZoomTargetKey = &P6YLiveZoomTargetKey;
static const void *P6YLiveOriginalTransformKey = &P6YLiveOriginalTransformKey;
static const void *P6YLiveStartScaleKey = &P6YLiveStartScaleKey;
static const void *P6YLiveCurrentScaleKey = &P6YLiveCurrentScaleKey;

static id P6YLiveGet(id object, NSString *key) {
    return [P6YManager safeValueForKey:key fromObject:object];
}

static BOOL P6YLooksLikeLiveRoomController(UIViewController *controller) {
    if (!controller) return NO;
    NSString *name = NSStringFromClass(controller.class).lowercaseString;
    if (![name containsString:@"live"]) return NO;

    BOOL roomLike = [name containsString:@"room"] ||
                    [name containsString:@"audience"] ||
                    [name containsString:@"broadcast"] ||
                    [name containsString:@"watch"] ||
                    [name containsString:@"container"];
    BOOL definitelyNotRoom = [name containsString:@"setting"] ||
                             [name containsString:@"create"] ||
                             [name containsString:@"preview"] ||
                             [name containsString:@"photo"];
    return roomLike && !definitelyNotRoom;
}

static BOOL P6YReadClearState(id object, BOOL *found) {
    if (!object) return NO;
    NSArray<NSString *> *keys = @[
        @"isClearScreen", @"clearScreen", @"isClearMode", @"clearMode",
        @"isScreenCleared", @"isUIHidden", @"uiHidden", @"controlsHidden",
        @"isInteractionHidden"
    ];
    for (NSString *key in keys) {
        id value = P6YLiveGet(object, key);
        if ([value isKindOfClass:NSNumber.class]) {
            if (found) *found = YES;
            return [value boolValue];
        }
    }
    return NO;
}

static BOOL P6YLiveInterfaceIsCleared(UIViewController *controller, BOOL *known) {
    if (known) *known = NO;
    NSMutableArray *objects = [NSMutableArray arrayWithObject:controller];
    for (NSString *key in @[@"interactionController", @"roomViewController", @"containerViewController", @"viewModel", @"roomViewModel"]) {
        id value = P6YLiveGet(controller, key);
        if (value) [objects addObject:value];
    }
    [objects addObjectsFromArray:controller.childViewControllers ?: @[]];

    for (id object in objects) {
        BOOL found = NO;
        BOOL cleared = P6YReadClearState(object, &found);
        if (found) {
            if (known) *known = YES;
            return cleared;
        }
    }
    return YES;
}

static BOOL P6YExcludedVideoCandidate(UIView *view) {
    if (!view || view.hidden || view.alpha < 0.02 || CGRectIsEmpty(view.bounds)) return YES;
    NSString *name = NSStringFromClass(view.class).lowercaseString;
    return [view isKindOfClass:UIControl.class] ||
           [view isKindOfClass:UILabel.class] ||
           [name containsString:@"button"] ||
           [name containsString:@"label"] ||
           [name containsString:@"comment"] ||
           [name containsString:@"chat"] ||
           [name containsString:@"gift"] ||
           [name containsString:@"toolbar"] ||
           [name containsString:@"control"];
}

static NSInteger P6YVideoCandidateScore(UIView *view, UIView *host) {
    if (P6YExcludedVideoCandidate(view) || view == host) return NSIntegerMin;

    CGRect frame = [view convertRect:view.bounds toView:host];
    CGFloat area = MAX(0, CGRectGetWidth(frame)) * MAX(0, CGRectGetHeight(frame));
    CGFloat hostArea = MAX(1, CGRectGetWidth(host.bounds) * CGRectGetHeight(host.bounds));
    if (area < hostArea * 0.20) return NSIntegerMin;

    NSString *viewName = NSStringFromClass(view.class).lowercaseString;
    NSString *layerName = NSStringFromClass(view.layer.class).lowercaseString;
    NSInteger score = (NSInteger)MIN(area / 100.0, 1000000.0);

    if ([layerName containsString:@"player"] ||
        [layerName containsString:@"metal"] ||
        [layerName containsString:@"eagl"] ||
        [layerName containsString:@"samplebuffer"]) score += 3000000;

    if ([viewName containsString:@"player"] ||
        [viewName containsString:@"video"] ||
        [viewName containsString:@"render"] ||
        [viewName containsString:@"surface"]) score += 2000000;

    if ([viewName containsString:@"live"]) score += 500000;
    return score;
}

static void P6YFindBestVideoView(UIView *view, UIView *host, UIView **best, NSInteger *bestScore) {
    if (!view) return;
    NSInteger score = P6YVideoCandidateScore(view, host);
    if (score > *bestScore) {
        *bestScore = score;
        *best = view;
    }
    for (UIView *child in view.subviews) {
        P6YFindBestVideoView(child, host, best, bestScore);
    }
}

static UIView *P6YLiveVideoView(UIViewController *controller) {
    UIView *host = controller.view;
    if (!host) return nil;

    UIView *best = nil;
    NSInteger bestScore = NSIntegerMin;
    P6YFindBestVideoView(host, host, &best, &bestScore);
    return best;
}

static NSValue *P6YTransformValue(CGAffineTransform transform) {
    return [NSValue valueWithBytes:&transform objCType:@encode(CGAffineTransform)];
}

static CGAffineTransform P6YTransformFromValue(NSValue *value) {
    CGAffineTransform transform = CGAffineTransformIdentity;
    if (value && strcmp(value.objCType, @encode(CGAffineTransform)) == 0) {
        [value getValue:&transform];
    }
    return transform;
}

static void P6YResetLiveZoom(UIViewController *controller, BOOL animated) {
    UIView *target = objc_getAssociatedObject(controller, P6YLiveZoomTargetKey);
    NSValue *originalValue = objc_getAssociatedObject(controller, P6YLiveOriginalTransformKey);
    CGAffineTransform original = P6YTransformFromValue(originalValue);

    void (^changes)(void) = ^{
        if (target) target.transform = original;
    };
    if (animated) {
        [UIView animateWithDuration:0.18 animations:changes];
    } else {
        changes();
    }

    objc_setAssociatedObject(controller, P6YLiveCurrentScaleKey, @(1.0), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(controller, P6YLiveStartScaleKey, @(1.0), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(controller, P6YLiveZoomTargetKey, nil, OBJC_ASSOCIATION_ASSIGN);
    objc_setAssociatedObject(controller, P6YLiveOriginalTransformKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static void P6YInstallLiveZoomGestures(UIViewController *controller) {
    if (![P6YManager boolForKey:@"p6y_live_zoom"] || !P6YLooksLikeLiveRoomController(controller)) return;
    UIView *host = controller.view;
    if (!host) return;

    UIPinchGestureRecognizer *pinch = objc_getAssociatedObject(controller, P6YLivePinchKey);
    if (!pinch) {
        pinch = [[UIPinchGestureRecognizer alloc] initWithTarget:controller action:NSSelectorFromString(@"p6y_handleLivePinch:")];
        pinch.cancelsTouchesInView = NO;
        pinch.delegate = (id<UIGestureRecognizerDelegate>)controller;
        [host addGestureRecognizer:pinch];
        objc_setAssociatedObject(controller, P6YLivePinchKey, pinch, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }

    UITapGestureRecognizer *reset = objc_getAssociatedObject(controller, P6YLiveResetTapKey);
    if (!reset) {
        reset = [[UITapGestureRecognizer alloc] initWithTarget:controller action:NSSelectorFromString(@"p6y_resetLiveZoom:")];
        reset.numberOfTapsRequired = 2;
        reset.numberOfTouchesRequired = 2;
        reset.cancelsTouchesInView = NO;
        reset.delegate = (id<UIGestureRecognizerDelegate>)controller;
        [host addGestureRecognizer:reset];
        objc_setAssociatedObject(controller, P6YLiveResetTapKey, reset, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

%hook UIViewController

- (void)viewDidAppear:(BOOL)animated {
    %orig;
    if (P6YLooksLikeLiveRoomController(self)) {
        dispatch_async(dispatch_get_main_queue(), ^{
            P6YInstallLiveZoomGestures(self);
        });
    }
}

- (void)viewDidDisappear:(BOOL)animated {
    if (P6YLooksLikeLiveRoomController(self)) P6YResetLiveZoom(self, NO);
    %orig;
}

%new
- (void)p6y_handleLivePinch:(UIPinchGestureRecognizer *)gesture {
    if (![P6YManager boolForKey:@"p6y_live_zoom"] || !P6YLooksLikeLiveRoomController(self)) return;

    if (gesture.state == UIGestureRecognizerStateBegan) {
        UIView *target = P6YLiveVideoView(self);
        if (!target) return;

        NSNumber *current = objc_getAssociatedObject(self, P6YLiveCurrentScaleKey) ?: @(1.0);
        objc_setAssociatedObject(self, P6YLiveStartScaleKey, current, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(self, P6YLiveZoomTargetKey, target, OBJC_ASSOCIATION_ASSIGN);
        if (!objc_getAssociatedObject(self, P6YLiveOriginalTransformKey)) {
            objc_setAssociatedObject(self, P6YLiveOriginalTransformKey, P6YTransformValue(target.transform), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        target.superview.clipsToBounds = YES;
    }

    UIView *target = objc_getAssociatedObject(self, P6YLiveZoomTargetKey);
    if (!target) return;

    CGFloat startScale = [objc_getAssociatedObject(self, P6YLiveStartScaleKey) doubleValue];
    CGFloat scale = MIN(4.0, MAX(1.0, startScale * gesture.scale));
    CGAffineTransform original = P6YTransformFromValue(objc_getAssociatedObject(self, P6YLiveOriginalTransformKey));
    target.transform = CGAffineTransformScale(original, scale, scale);
    objc_setAssociatedObject(self, P6YLiveCurrentScaleKey, @(scale), OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    if ((gesture.state == UIGestureRecognizerStateEnded || gesture.state == UIGestureRecognizerStateCancelled) && scale <= 1.01) {
        P6YResetLiveZoom(self, YES);
    }
}

%new
- (void)p6y_resetLiveZoom:(UITapGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateRecognized) P6YResetLiveZoom(self, YES);
}

%new
- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gesture {
    UIPinchGestureRecognizer *pinch = objc_getAssociatedObject(self, P6YLivePinchKey);
    UITapGestureRecognizer *reset = objc_getAssociatedObject(self, P6YLiveResetTapKey);
    if (gesture != pinch && gesture != reset) return YES;
    if (![P6YManager boolForKey:@"p6y_live_zoom"] || !P6YLooksLikeLiveRoomController(self)) return NO;

    if (gesture == reset) {
        return [objc_getAssociatedObject(self, P6YLiveCurrentScaleKey) doubleValue] > 1.01;
    }

    BOOL stateKnown = NO;
    BOOL cleared = P6YLiveInterfaceIsCleared(self, &stateKnown);
    return !stateKnown || cleared;
}

%new
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gesture shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGesture {
    UIPinchGestureRecognizer *pinch = objc_getAssociatedObject(self, P6YLivePinchKey);
    UITapGestureRecognizer *reset = objc_getAssociatedObject(self, P6YLiveResetTapKey);
    return gesture == pinch || gesture == reset || otherGesture == pinch || otherGesture == reset;
}

%end
