#import <Foundation/Foundation.h>
#import <objc/runtime.h>

static NSString * const P6YIntegrityEnabledKey = @"p6y_integrity_compat";
static NSMutableSet<NSString *> *P6YHookedIntegrityMethods;
static BOOL P6YIntegrityEnabled = NO;
static BOOL P6YIntegritySideloaded = NO;

static BOOL P6YReturnNo0(id self, SEL _cmd) { return NO; }
static BOOL P6YReturnNo1(id self, SEL _cmd, id arg1) { return NO; }
static BOOL P6YReturnNo2(id self, SEL _cmd, id arg1, id arg2) { return NO; }
static BOOL P6YReturnYes0(id self, SEL _cmd) { return YES; }
static id P6YReturnAppStore0(id self, SEL _cmd) { return @"AppStore"; }

static NSString *(*P6YOriginalBundlePathForResource)(NSBundle *, SEL, NSString *, NSString *);
static NSURL *(*P6YOriginalBundleURLForResource)(NSBundle *, SEL, NSString *, NSString *);

static BOOL P6YIsEmbeddedProvisionRequest(NSBundle *bundle, NSString *name, NSString *extension) {
    return P6YIntegrityEnabled && P6YIntegritySideloaded && bundle == NSBundle.mainBundle &&
           [name isEqualToString:@"embedded"] && [extension isEqualToString:@"mobileprovision"];
}

static NSString *P6YBundlePathForResource(NSBundle *bundle, SEL selector, NSString *name, NSString *extension) {
    if (P6YIsEmbeddedProvisionRequest(bundle, name, extension)) return nil;
    return P6YOriginalBundlePathForResource ? P6YOriginalBundlePathForResource(bundle, selector, name, extension) : nil;
}

static NSURL *P6YBundleURLForResource(NSBundle *bundle, SEL selector, NSString *name, NSString *extension) {
    if (P6YIsEmbeddedProvisionRequest(bundle, name, extension)) return nil;
    return P6YOriginalBundleURLForResource ? P6YOriginalBundleURLForResource(bundle, selector, name, extension) : nil;
}

static BOOL P6YMethodReturnsBool(Method method) {
    char type[16] = {0};
    method_getReturnType(method, type, sizeof(type));
    return type[0] == 'B' || type[0] == 'c';
}

static BOOL P6YMethodReturnsObject(Method method) {
    char type[16] = {0};
    method_getReturnType(method, type, sizeof(type));
    return type[0] == '@';
}

static BOOL P6YImageBelongsToTikTok(Class cls) {
    const char *imageName = class_getImageName(cls);
    if (!imageName) return NO;
    NSString *image = [NSString stringWithUTF8String:imageName];
    NSString *bundlePath = NSBundle.mainBundle.bundlePath;
    return bundlePath.length && [image hasPrefix:bundlePath];
}

static IMP P6YReplacementForMethod(Method method, NSString *selectorName) {
    NSString *lower = selectorName.lowercaseString;
    unsigned int argumentCount = method_getNumberOfArguments(method);

    if (P6YMethodReturnsBool(method)) {
        BOOL cleanResult = [lower containsString:@"jail"] ||
                           [lower containsString:@"rooted"] ||
                           [lower isEqualToString:@"isdebugbuild"] ||
                           [lower isEqualToString:@"isappstorereceiptsandbox"];
        BOOL appStoreResult = [lower isEqualToString:@"isfromappstore"] ||
                              [lower isEqualToString:@"isappstore"];

        if (appStoreResult && argumentCount == 2) return (IMP)P6YReturnYes0;
        if (!cleanResult) return NULL;
        if (argumentCount == 2) return (IMP)P6YReturnNo0;
        if (argumentCount == 3) return (IMP)P6YReturnNo1;
        if (argumentCount == 4) return (IMP)P6YReturnNo2;
        return NULL;
    }

    if (P6YMethodReturnsObject(method) && [lower isEqualToString:@"signinfo"] && argumentCount == 2) {
        return (IMP)P6YReturnAppStore0;
    }

    return NULL;
}

static void P6YHookMethodList(Class ownerClass, Class methodContainer, BOOL classMethod) {
    unsigned int count = 0;
    Method *methods = class_copyMethodList(methodContainer, &count);
    for (unsigned int index = 0; index < count; index++) {
        Method method = methods[index];
        SEL selector = method_getName(method);
        NSString *selectorName = NSStringFromSelector(selector);
        IMP replacement = P6YReplacementForMethod(method, selectorName);
        if (!replacement) continue;

        NSString *key = [NSString stringWithFormat:@"%@%@ %@", classMethod ? @"+" : @"-", NSStringFromClass(ownerClass), selectorName];
        @synchronized (P6YHookedIntegrityMethods) {
            if ([P6YHookedIntegrityMethods containsObject:key]) continue;
            method_setImplementation(method, replacement);
            [P6YHookedIntegrityMethods addObject:key];
        }
        NSLog(@"[P6YTOK][Integrity] hooked %@", key);
    }
    free(methods);
}

static void P6YScanTikTokIntegrityMethods(void) {
    if (!P6YIntegrityEnabled) return;

    int count = objc_getClassList(NULL, 0);
    if (count <= 0) return;
    Class *classes = (__unsafe_unretained Class *)calloc((size_t)count, sizeof(Class));
    count = objc_getClassList(classes, count);

    for (int index = 0; index < count; index++) {
        Class cls = classes[index];
        if (!cls || !P6YImageBelongsToTikTok(cls)) continue;
        P6YHookMethodList(cls, cls, NO);
        Class meta = object_getClass(cls);
        if (meta) P6YHookMethodList(cls, meta, YES);
    }
    free(classes);
}

static void P6YInstallBundleProvisionCompatibility(void) {
    Method pathMethod = class_getInstanceMethod(NSBundle.class, @selector(pathForResource:ofType:));
    if (pathMethod) {
        P6YOriginalBundlePathForResource = (void *)method_getImplementation(pathMethod);
        method_setImplementation(pathMethod, (IMP)P6YBundlePathForResource);
    }

    Method urlMethod = class_getInstanceMethod(NSBundle.class, @selector(URLForResource:withExtension:));
    if (urlMethod) {
        P6YOriginalBundleURLForResource = (void *)method_getImplementation(urlMethod);
        method_setImplementation(urlMethod, (IMP)P6YBundleURLForResource);
    }
}

__attribute__((constructor)) static void P6YInitializeIntegrityCompatibility(void) {
    @autoreleasepool {
        NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
        id configured = [defaults objectForKey:P6YIntegrityEnabledKey];
        P6YIntegrityEnabled = configured ? [configured boolValue] : YES;
        if (!P6YIntegrityEnabled) return;

        NSString *profilePath = [NSBundle.mainBundle.bundlePath stringByAppendingPathComponent:@"embedded.mobileprovision"];
        P6YIntegritySideloaded = [NSFileManager.defaultManager fileExistsAtPath:profilePath];
        P6YHookedIntegrityMethods = [NSMutableSet set];

        if (P6YIntegritySideloaded) P6YInstallBundleProvisionCompatibility();
        P6YScanTikTokIntegrityMethods();

        NSArray<NSNumber *> *delays = @[@0.25, @1.0, @3.0];
        for (NSNumber *delay in delays) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay.doubleValue * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                P6YScanTikTokIntegrityMethods();
            });
        }

        NSLog(@"[P6YTOK][Integrity] enabled=%@ sideloaded=%@", P6YIntegrityEnabled ? @"YES" : @"NO", P6YIntegritySideloaded ? @"YES" : @"NO");
    }
}
