#import "SecurityViewController.h"
#import <QuartzCore/QuartzCore.h>
#import <LocalAuthentication/LocalAuthentication.h>

@interface SecurityViewController ()
@property (nonatomic, strong) UIButton *unlockButton;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, assign) BOOL authenticationRunning;
@end

@implementation SecurityViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.blackColor;

    CAGradientLayer *gradient = [CAGradientLayer layer];
    gradient.colors = @[(id)UIColor.blackColor.CGColor, (id)[UIColor colorWithRed:0.22 green:0 blue:0 alpha:1].CGColor, (id)UIColor.blackColor.CGColor];
    gradient.startPoint = CGPointMake(0, 0);
    gradient.endPoint = CGPointMake(1, 1);
    gradient.frame = self.view.bounds;
    [self.view.layer insertSublayer:gradient atIndex:0];

    UILabel *brand = [[UILabel alloc] init];
    brand.text = @"P6YTOK";
    brand.textColor = [UIColor colorWithRed:0.95 green:0 blue:0.04 alpha:1];
    brand.font = [UIFont systemFontOfSize:40 weight:UIFontWeightBlack];
    brand.textAlignment = NSTextAlignmentCenter;
    brand.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:brand];

    self.statusLabel = [[UILabel alloc] init];
    self.statusLabel.text = @"Authentication required";
    self.statusLabel.textColor = [UIColor colorWithWhite:0.78 alpha:1];
    self.statusLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
    self.statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.statusLabel];

    self.unlockButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.unlockButton setTitle:@"Unlock" forState:UIControlStateNormal];
    [self.unlockButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    self.unlockButton.titleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightBold];
    self.unlockButton.backgroundColor = [UIColor colorWithRed:0.88 green:0 blue:0.03 alpha:1];
    self.unlockButton.layer.cornerRadius = 14;
    self.unlockButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.unlockButton addTarget:self action:@selector(authenticate) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.unlockButton];

    [NSLayoutConstraint activateConstraints:@[
        [brand.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [brand.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor constant:-80],
        [self.statusLabel.topAnchor constraintEqualToAnchor:brand.bottomAnchor constant:12],
        [self.statusLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:24],
        [self.statusLabel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-24],
        [self.unlockButton.topAnchor constraintEqualToAnchor:self.statusLabel.bottomAnchor constant:28],
        [self.unlockButton.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.unlockButton.widthAnchor constraintEqualToConstant:190],
        [self.unlockButton.heightAnchor constraintEqualToConstant:50]
    ]];

    [self authenticate];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    ((CAGradientLayer *)self.view.layer.sublayers.firstObject).frame = self.view.bounds;
}

- (void)authenticate {
    if (self.authenticationRunning) return;
    self.authenticationRunning = YES;
    self.unlockButton.enabled = NO;
    self.statusLabel.text = @"Checking identity…";

    LAContext *context = [[LAContext alloc] init];
    NSError *policyError = nil;
    if (![context canEvaluatePolicy:LAPolicyDeviceOwnerAuthentication error:&policyError]) {
        self.authenticationRunning = NO;
        self.unlockButton.enabled = YES;
        self.statusLabel.text = @"Device authentication is unavailable";
        return;
    }

    [context evaluatePolicy:LAPolicyDeviceOwnerAuthentication localizedReason:@"Unlock P6YTOK" reply:^(BOOL success, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.authenticationRunning = NO;
            self.unlockButton.enabled = YES;
            if (success) {
                [self dismissViewControllerAnimated:YES completion:nil];
            } else {
                self.statusLabel.text = error.localizedDescription.length ? error.localizedDescription : @"Authentication failed";
            }
        });
    }];
}

@end
