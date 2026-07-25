#import "P6YCompatCore.h"

static BOOL p6yCompatGroupsInitialized = NO;

static void P6YCompatInitDelayedGroups(void) {
    if (p6yCompatGroupsInitialized || !P6YCompatAreDelayedFeatureGroupsEnabled()) {
        return;
    }

    p6yCompatGroupsInitialized = YES;
    P6YCompatLog(@"delayed group coordinator fired");

    // Move existing feature groups here as they are migrated.
    //
    // Example:
    // if (P6YCompatShouldRunFeatureGroup(P6YCompatFeatureGroupDownloads)) {
    //     %init(P6YDownloads);
    // }
    //
    // Keep login/auth/security-sensitive hooks out of this file.
}

%ctor {
    @autoreleasepool {
        [[NSNotificationCenter defaultCenter] addObserverForName:P6YCompatDidEnableFeatureGroupsNotification
                                                          object:nil
                                                           queue:[NSOperationQueue mainQueue]
                                                      usingBlock:^(__unused NSNotification *notification) {
            P6YCompatInitDelayedGroups();
        }];
    }
}
