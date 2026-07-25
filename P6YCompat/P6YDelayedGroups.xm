#import "P6YCompatCore.h"
#import "P6YFeaturePayloadName.h"
#import <dlfcn.h>

static BOOL p6yCompatPayloadLoadAttempted = NO;
static void *p6yCompatPayloadHandle = NULL;

static NSString *P6YCompatFeaturePayloadPath(void) {
    NSString *bundlePath = NSBundle.mainBundle.bundlePath ?: @"";
    NSArray<NSString *> *candidates = @[
        [[bundlePath stringByAppendingPathComponent:@"Frameworks"] stringByAppendingPathComponent:P6Y_FEATURE_DYLIB_NAME],
        [bundlePath stringByAppendingPathComponent:P6Y_FEATURE_DYLIB_NAME]
    ];

    for (NSString *candidate in candidates) {
        if ([[NSFileManager defaultManager] fileExistsAtPath:candidate]) {
            return candidate;
        }
    }

    return candidates.firstObject;
}

static void P6YCompatLoadFeaturePayload(void) {
    if (p6yCompatPayloadLoadAttempted || !P6YCompatAreDelayedFeatureGroupsEnabled()) {
        return;
    }

    p6yCompatPayloadLoadAttempted = YES;

    NSString *payloadPath = P6YCompatFeaturePayloadPath();
    if (![[NSFileManager defaultManager] fileExistsAtPath:payloadPath]) {
        P6YCompatLog(@"feature payload missing at %@", payloadPath);
        return;
    }

    dlerror();
    p6yCompatPayloadHandle = dlopen(payloadPath.fileSystemRepresentation, RTLD_NOW | RTLD_GLOBAL);
    if (!p6yCompatPayloadHandle) {
        const char *error = dlerror();
        P6YCompatLog(@"feature payload failed to load: %s", error ?: "unknown dlopen error");
        return;
    }

    P6YCompatLog(@"feature payload loaded after login-safe startup: %@", P6Y_FEATURE_DYLIB_NAME);
}

%ctor {
    @autoreleasepool {
        [[NSNotificationCenter defaultCenter] addObserverForName:P6YCompatDidEnableFeatureGroupsNotification
                                                          object:nil
                                                           queue:[NSOperationQueue mainQueue]
                                                      usingBlock:^(__unused NSNotification *notification) {
            P6YCompatLoadFeaturePayload();
        }];
    }
}
