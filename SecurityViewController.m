#import "SecurityViewController.h"

@implementation SecurityViewController

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    // Retained only as a compatibility stub for older hook code. P6YTOK no
    // longer performs Face ID, Touch ID, or device-passcode authentication.
    [self dismissViewControllerAnimated:NO completion:nil];
}

@end
