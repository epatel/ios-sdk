#import "ProxyDelegate.h"
#import "AppDelegate.h"

@implementation ProxyDelegate

- (void)setViewController:(ViewController *)viewController
{
    AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    appDelegate.viewController = viewController;
}

- (ViewController*)viewController
{
    AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    return appDelegate.viewController;
}

@end
