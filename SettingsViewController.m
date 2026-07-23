#import "SettingsViewController.h"

static UIColor *P6YTOKRedColor(void) {
    return [UIColor colorWithRed:0.92 green:0.05 blue:0.12 alpha:1.0];
}

@implementation SettingsViewController

- (instancetype)init {
    self = [super init];
    if (self) {
        self.title = @"P6YTOK";

        HBAppearanceSettings *appearance = [HBAppearanceSettings new];
        appearance.tableViewBackgroundColor = UIColor.blackColor;
        appearance.tableViewCellBackgroundColor = [UIColor colorWithWhite:0.08 alpha:1.0];
        self.hb_appearanceSettings = appearance;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.view.backgroundColor = UIColor.blackColor;
    self.tableView.backgroundColor = UIColor.blackColor;
    self.navigationController.navigationBar.barStyle = UIBarStyleBlack;
    self.navigationController.navigationBar.tintColor = P6YTOKRedColor();
    self.navigationController.navigationBar.titleTextAttributes = @{
        NSForegroundColorAttributeName: UIColor.whiteColor
    };
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                                                           target:self
                                                                                           action:@selector(closeSettings)];
}

- (UITableViewStyle)tableViewStyle {
    return UITableViewStyleInsetGrouped;
}

- (void)closeSettings {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (PSSpecifier *)sectionWithTitle:(NSString *)title footer:(NSString *)footer {
    PSSpecifier *section = [PSSpecifier preferenceSpecifierNamed:title
                                                          target:self
                                                             set:nil
                                                             get:nil
                                                          detail:nil
                                                            cell:PSGroupCell
                                                            edit:nil];
    if (footer.length) {
        [section setProperty:footer forKey:@"footerText"];
    }
    return section;
}

- (PSSpecifier *)switchWithTitle:(NSString *)title
                            key:(NSString *)key
                   defaultValue:(BOOL)defaultValue {
    PSSpecifier *specifier = [PSSpecifier preferenceSpecifierNamed:title
                                                            target:self
                                                               set:@selector(setPreferenceValue:specifier:)
                                                               get:@selector(readPreferenceValue:)
                                                            detail:nil
                                                              cell:PSSwitchCell
                                                              edit:nil];
    [specifier setProperty:key forKey:@"key"];
    [specifier setProperty:@(defaultValue) forKey:@"default"];
    [specifier setProperty:NSBundle.mainBundle.bundleIdentifier forKey:@"defaults"];
    [specifier setProperty:P6YTOKRedColor() forKey:@"tintColor"];
    return specifier;
}

- (NSArray *)specifiers {
    if (_specifiers) return _specifiers;

    NSMutableArray *items = [NSMutableArray array];

    [items addObject:[self sectionWithTitle:@"Downloads"
                                     footer:@"Download handling will be rebuilt for TikTok 46.1.0 in the next phase."]];
    [items addObject:[self switchWithTitle:@"Download Videos" key:@"dw_videos" defaultValue:YES]];
    [items addObject:[self switchWithTitle:@"Download Music" key:@"dw_musics" defaultValue:YES]];
    [items addObject:[self switchWithTitle:@"Copy Video Description" key:@"copy_decription" defaultValue:YES]];
    [items addObject:[self switchWithTitle:@"Copy Video Link" key:@"copy_video_link" defaultValue:YES]];
    [items addObject:[self switchWithTitle:@"Copy Music Link" key:@"copy_music_link" defaultValue:YES]];

    [items addObject:[self sectionWithTitle:@"Feed" footer:nil]];
    [items addObject:[self switchWithTitle:@"Disable Ads" key:@"hide_ads" defaultValue:YES]];
    [items addObject:[self switchWithTitle:@"Pure Mode" key:@"remove_elements_button" defaultValue:YES]];
    [items addObject:[self switchWithTitle:@"Show Progress Bar" key:@"show_porgress_bar" defaultValue:YES]];

    [items addObject:[self sectionWithTitle:@"Profile" footer:nil]];
    [items addObject:[self switchWithTitle:@"Save Profile Picture" key:@"save_profile" defaultValue:YES]];
    [items addObject:[self switchWithTitle:@"Copy Profile Information" key:@"copy_profile_information" defaultValue:YES]];
    [items addObject:[self switchWithTitle:@"Extend Bio Limit" key:@"extended_bio" defaultValue:YES]];
    [items addObject:[self switchWithTitle:@"Extend Comment Limit" key:@"extendedComment" defaultValue:YES]];

    [items addObject:[self sectionWithTitle:@"Confirmations" footer:nil]];
    [items addObject:[self switchWithTitle:@"Confirm Like" key:@"like_confirm" defaultValue:NO]];
    [items addObject:[self switchWithTitle:@"Confirm Comment Like" key:@"like_comment_confirm" defaultValue:NO]];
    [items addObject:[self switchWithTitle:@"Confirm Comment Dislike" key:@"dislike_comment_confirm" defaultValue:NO]];
    [items addObject:[self switchWithTitle:@"Confirm Follow" key:@"follow_confirm" defaultValue:NO]];

    [items addObject:[self sectionWithTitle:@"Security & Links"
                                     footer:@"P6YTOK contains no fake-stat, region-spoofing, destructive interaction-reset, donation, or jailbreak-bypass options."]];
    [items addObject:[self switchWithTitle:@"Open Links in Browser" key:@"openInBrowser" defaultValue:NO]];
    [items addObject:[self switchWithTitle:@"Passcode Lock" key:@"padlock" defaultValue:NO]];

    _specifiers = [items copy];
    return _specifiers;
}

- (id)readPreferenceValue:(PSSpecifier *)specifier {
    NSString *key = [specifier propertyForKey:@"key"];
    id value = [NSUserDefaults.standardUserDefaults objectForKey:key];
    return value ?: [specifier propertyForKey:@"default"];
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
    NSString *key = [specifier propertyForKey:@"key"];
    if (!key.length) return;

    [NSUserDefaults.standardUserDefaults setObject:value forKey:key];
    [NSUserDefaults.standardUserDefaults synchronize];
}

@end
