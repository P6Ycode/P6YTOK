#import "P6YCompatCore.h"

// Use these helpers inside existing hooks while migrating toward delayed Logos groups.
// The preferred final shape is still Option B: keep feature groups uninitialized until
// P6YCompatDidEnableFeatureGroupsNotification fires. These guards are a bridge for
// existing hooks that cannot be moved cleanly in the first pass.

#define P6Y_COMPAT_CAN_RUN_SETTINGS() P6YCompatShouldRunFeatureGroup(P6YCompatFeatureGroupSettings)
#define P6Y_COMPAT_CAN_RUN_DOWNLOADS() P6YCompatShouldRunFeatureGroup(P6YCompatFeatureGroupDownloads)
#define P6Y_COMPAT_CAN_RUN_FEED_UI() P6YCompatShouldRunFeatureGroup(P6YCompatFeatureGroupFeedUI)
#define P6Y_COMPAT_CAN_RUN_PROFILE() P6YCompatShouldRunFeatureGroup(P6YCompatFeatureGroupProfile)
#define P6Y_COMPAT_CAN_RUN_AD_FILTERING() P6YCompatShouldRunFeatureGroup(P6YCompatFeatureGroupAdFiltering)
#define P6Y_COMPAT_CAN_RUN_BROWSER_REDIRECTS() P6YCompatShouldRunFeatureGroup(P6YCompatFeatureGroupBrowserRedirects)
