#import "P6YCompatCore.h"

%group P6YCompatLoginSafeObserver

%hook UIViewController

- (void)viewDidAppear:(BOOL)animated {
    %orig;
    P6YCompatObserveViewController(self);
}

%end

%end

%ctor {
    @autoreleasepool {
        P6YCompatBootstrap();
        %init(P6YCompatLoginSafeObserver);
    }
}
