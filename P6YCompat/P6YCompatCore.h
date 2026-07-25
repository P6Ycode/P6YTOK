#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

typedef NS_ENUM(NSInteger, P6YCompatFeatureGroup) {
    P6YCompatFeatureGroupSettings = 0,
    P6YCompatFeatureGroupDownloads,
    P6YCompatFeatureGroupFeedUI,
    P6YCompatFeatureGroupProfile,
    P6YCompatFeatureGroupAdFiltering,
    P6YCompatFeatureGroupBrowserRedirects,
};

NS_ASSUME_NONNULL_BEGIN

#ifdef __cplusplus
extern "C" {
#endif

extern NSString * const P6YCompatDidEnableFeatureGroupsNotification;
extern NSString * const P6YCompatLoginSafeModeChangedNotification;

void P6YCompatBootstrap(void);
void P6YCompatObserveViewController(UIViewController *viewController);
void P6YCompatEnableFeatureGroupsIfReady(void);

BOOL P6YCompatIsEnabled(void);
BOOL P6YCompatIsLoginSafeModeEnabled(void);
BOOL P6YCompatAreDelayedFeatureGroupsEnabled(void);
BOOL P6YCompatShouldRunFeatureGroup(P6YCompatFeatureGroup group);

NSString *P6YCompatTikTokVersion(void);
BOOL P6YCompatLooksLikeInjectedIPA(void);
BOOL P6YCompatClassExists(NSString *className);
BOOL P6YCompatInstanceSelectorExists(NSString *className, SEL selector);
BOOL P6YCompatClassSelectorExists(NSString *className, SEL selector);

NSString *P6YCompatFeatureGroupName(P6YCompatFeatureGroup group);
void P6YCompatLog(NSString *format, ...) NS_FORMAT_FUNCTION(1, 2);

#ifdef __cplusplus
}
#endif

NS_ASSUME_NONNULL_END
