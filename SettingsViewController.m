#import "SettingsViewController.h"
#import "P6YManager.h"

static UIColor *P6YRed(void) {
    return [UIColor colorWithRed:0.90 green:0.00 blue:0.04 alpha:1.0];
}

@interface SettingsViewController ()
@property (nonatomic, copy) NSArray<NSDictionary *> *sections;
@end

@implementation SettingsViewController

- (instancetype)init {
    return [super initWithStyle:UITableViewStyleInsetGrouped];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [P6YManager registerDefaults];
    self.title = @"P6YTOK";
    self.view.backgroundColor = UIColor.blackColor;
    self.tableView.backgroundColor = UIColor.blackColor;
    self.tableView.separatorColor = [UIColor colorWithRed:0.35 green:0 blue:0 alpha:1];
    self.tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;

    UINavigationBarAppearance *appearance = [[UINavigationBarAppearance alloc] init];
    [appearance configureWithOpaqueBackground];
    appearance.backgroundColor = UIColor.blackColor;
    appearance.titleTextAttributes = @{NSForegroundColorAttributeName: P6YRed(), NSFontAttributeName: [UIFont systemFontOfSize:19 weight:UIFontWeightHeavy]};
    self.navigationController.navigationBar.standardAppearance = appearance;
    self.navigationController.navigationBar.scrollEdgeAppearance = appearance;
    self.navigationController.navigationBar.tintColor = P6YRed();
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Done" style:UIBarButtonItemStyleDone target:self action:@selector(closeSettings)];

    self.sections = @[
        @{ @"title": @"DOWNLOADS", @"rows": @[
            [self switchRow:@"Enable downloads" detail:@"Shows the P6YTOK media button" key:@"p6y_downloads_enabled"],
            [self switchRow:@"Download videos" detail:@"Selects TikTok's highest available direct video variant" key:@"p6y_download_video"],
            [self switchRow:@"Download photo posts" detail:@"Saves every original photo file at full available quality, including batches" key:@"p6y_download_photos"],
            [self switchRow:@"Download music" detail:@"Exports the original audio response through the share sheet" key:@"p6y_download_music"],
            [self switchRow:@"Copy description" detail:@"Adds Copy Description to the P6YTOK menu" key:@"p6y_copy_description"],
            [self switchRow:@"Copy video link" detail:@"Copies the selected highest-quality direct video link" key:@"p6y_copy_video_link"],
            [self switchRow:@"Copy music link" detail:@"Copies the direct audio link" key:@"p6y_copy_music_link"],
            [self switchRow:@"Download progress" detail:@"Shows a compact black-and-red progress bar" key:@"p6y_download_progress"],
            [self segmentRow:@"After downloading" detail:@"Music always opens the share sheet" key:@"p6y_download_destination" options:@[@"Photos", @"Share"]]
        ]},
        @{ @"title": @"FEED", @"rows": @[
            [self switchRow:@"Disable ads" detail:@"Filters ad and pseudo-ad feed models" key:@"p6y_hide_ads"],
            [self switchRow:@"Pure Mode button" detail:@"Adds a button that hides or restores feed controls" key:@"p6y_pure_mode"],
            [self switchRow:@"Transparent comments" detail:@"Uses a translucent comment panel" key:@"p6y_transparent_comments"],
            [self switchRow:@"Clean shared links" detail:@"Removes TikTok tracking parameters from copied links" key:@"p6y_clean_links"],
            [self switchRow:@"Disable content warnings" detail:@"Suppresses supported feed warning masks" key:@"p6y_disable_warnings"],
            [self switchRow:@"Skip recommendations" detail:@"Filters user-recommendation cards" key:@"p6y_skip_recommendations"],
            [self segmentRow:@"When a video ends" detail:@"Choose replay, stop, or move to the next post" key:@"p6y_playback_action" options:@[@"Replay", @"Stop", @"Next"]],
            [self segmentRow:@"Startup page" detail:@"Select the first home feed tab" key:@"p6y_startup_page" options:@[@"For You", @"Following"]]
        ]},
        @{ @"title": @"PROFILE", @"rows": @[
            [self switchRow:@"Save profile photo" detail:@"Long-press the profile-photo preview to fetch the highest-quality available avatar" key:@"p6y_save_profile_photo"],
            [self switchRow:@"Follow status" detail:@"Shows relationship status in a small P6YTOK profile badge" key:@"p6y_profile_follow_status"],
            [self switchRow:@"Video count" detail:@"Shows the visible post count in the profile badge" key:@"p6y_profile_video_count"],
            [self switchRow:@"Upload date" detail:@"Shows the date on profile thumbnails" key:@"p6y_profile_upload_date"],
            [self switchRow:@"Like count" detail:@"Shows likes on profile thumbnails" key:@"p6y_profile_like_count"],
            [self switchRow:@"Hide sensitive-content masks" detail:@"Removes supported profile thumbnail masks" key:@"p6y_profile_unsensitive"],
            [self switchRow:@"Extend bio limit" detail:@"Raises the local editor limit to 222 characters" key:@"p6y_extend_bio"],
            [self switchRow:@"Extend comment limit" detail:@"Raises the local editor limit to 240 characters" key:@"p6y_extend_comment"]
        ]},
        @{ @"title": @"CONFIRMATIONS", @"rows": @[
            [self switchRow:@"Confirm likes" detail:@"Ask before liking a post" key:@"p6y_confirm_like"],
            [self switchRow:@"Confirm comment likes" detail:@"Ask before liking a comment" key:@"p6y_confirm_comment_like"],
            [self switchRow:@"Confirm comment dislikes" detail:@"Ask before disliking a comment" key:@"p6y_confirm_comment_dislike"],
            [self switchRow:@"Confirm follows" detail:@"Ask before changing a follow relationship" key:@"p6y_confirm_follow"]
        ]},
        @{ @"title": @"ABOUT", @"rows": @[
            @{ @"type": @"info", @"title": @"P6YTOK 0.1.2", @"detail": @"Full-quality downloads with the app lock removed for TikTok 46.1.0" },
            @{ @"type": @"info", @"title": @"Quality behavior", @"detail": @"Uses the largest/original media variant TikTok exposes and writes original files to Photos without re-encoding" }
        ]}
    ];
}

- (NSDictionary *)switchRow:(NSString *)title detail:(NSString *)detail key:(NSString *)key {
    return @{ @"type": @"switch", @"title": title, @"detail": detail, @"key": key };
}

- (NSDictionary *)segmentRow:(NSString *)title detail:(NSString *)detail key:(NSString *)key options:(NSArray *)options {
    return @{ @"type": @"segment", @"title": title, @"detail": detail, @"key": key, @"options": options };
}

- (void)closeSettings {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return self.sections.count; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return [self.sections[section][@"rows"] count]; }
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section { return self.sections[section][@"title"]; }
- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    return section == self.sections.count - 1 ? @"P6YTOK settings apply immediately." : nil;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    UILabel *label = [[UILabel alloc] init];
    label.text = [NSString stringWithFormat:@"   %@", self.sections[section][@"title"]];
    label.textColor = P6YRed();
    label.font = [UIFont systemFontOfSize:13 weight:UIFontWeightHeavy];
    return label;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *row = self.sections[indexPath.section][@"rows"][indexPath.row];
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
    cell.backgroundColor = [UIColor colorWithWhite:0.055 alpha:1];
    cell.textLabel.text = row[@"title"];
    cell.textLabel.textColor = UIColor.whiteColor;
    cell.textLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    cell.detailTextLabel.text = row[@"detail"];
    cell.detailTextLabel.textColor = [UIColor colorWithWhite:0.62 alpha:1];
    cell.detailTextLabel.numberOfLines = 4;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;

    NSString *type = row[@"type"];
    NSString *key = row[@"key"];
    if ([type isEqualToString:@"switch"]) {
        UISwitch *control = [[UISwitch alloc] init];
        control.onTintColor = P6YRed();
        control.accessibilityIdentifier = key;
        control.on = [P6YManager boolForKey:key];
        [control addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = control;
    } else if ([type isEqualToString:@"segment"]) {
        UISegmentedControl *control = [[UISegmentedControl alloc] initWithItems:row[@"options"]];
        control.selectedSegmentIndex = [P6YManager integerForKey:key];
        control.accessibilityIdentifier = key;
        control.selectedSegmentTintColor = P6YRed();
        [control setTitleTextAttributes:@{NSForegroundColorAttributeName: UIColor.whiteColor} forState:UIControlStateSelected];
        [control setTitleTextAttributes:@{NSForegroundColorAttributeName: [UIColor colorWithWhite:0.75 alpha:1]} forState:UIControlStateNormal];
        [control addTarget:self action:@selector(segmentChanged:) forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = control;
    } else {
        cell.imageView.image = [UIImage systemImageNamed:@"flame.fill"];
        cell.imageView.tintColor = P6YRed();
    }
    return cell;
}

- (void)switchChanged:(UISwitch *)sender {
    if (sender.accessibilityIdentifier.length) [NSUserDefaults.standardUserDefaults setBool:sender.isOn forKey:sender.accessibilityIdentifier];
}

- (void)segmentChanged:(UISegmentedControl *)sender {
    if (sender.accessibilityIdentifier.length) [NSUserDefaults.standardUserDefaults setInteger:sender.selectedSegmentIndex forKey:sender.accessibilityIdentifier];
}

@end
