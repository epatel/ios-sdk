#import "ProgressIndicator.h"

@implementation ProgressIndicator

- (void)drawRect:(CGRect)rect
{
    CGRect bounds = self.bounds;
    [[UIColor colorWithWhite:0.5 alpha:0.5] set];
    [[UIBezierPath bezierPathWithRect:bounds] fill];
    bounds.size.width *= _value;
    [_color set];
    [[UIBezierPath bezierPathWithRect:bounds] fill];
}

@end
