#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <CepheiPrefs/CepheiPrefs.h>
#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>

@interface SettingsViewController : HBListController
- (instancetype)init;
- (id)readPreferenceValue:(PSSpecifier *)specifier;
- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier;
@end
