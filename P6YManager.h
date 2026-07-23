#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface P6YManager : NSObject
+ (void)registerDefaults;
+ (BOOL)boolForKey:(NSString *)key;
+ (NSInteger)integerForKey:(NSString *)key;
+ (UIViewController * _Nullable)topViewController;
+ (id _Nullable)safeValueForKey:(NSString *)key fromObject:(id _Nullable)object;
+ (NSString * _Nullable)sanitizedTikTokURLString:(NSString * _Nullable)string;
+ (void)showToast:(NSString *)message;
+ (void)presentConfirmationWithTitle:(NSString *)title
                             message:(NSString *)message
                                from:(UIViewController * _Nullable)controller
                           confirmed:(dispatch_block_t)confirmed;
+ (void)cleanTemporaryDownloads;
@end

NS_ASSUME_NONNULL_END
