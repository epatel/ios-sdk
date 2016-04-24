#import "VolumeIndicator.h"

@implementation VolumeIndicator

- (void)drawRect:(CGRect)rect
{
    CGRect bounds = self.bounds;
    [_color set];
    CGFloat width = 10;
    CGFloat radius = bounds.size.width / 2.0 - 1 - width/2.0;
    {
        [[UIColor colorWithWhite:0.5 alpha:0.5] set];
        UIBezierPath *path = [UIBezierPath bezierPathWithArcCenter:CGPointMake(bounds.size.width/2.0, bounds.size.height/2.0)
                                                            radius:radius
                                                        startAngle:3.0*M_PI/4.0
                                                          endAngle:9.0*M_PI/4.0
                                                         clockwise:YES];
        path.lineWidth = width;
        [path stroke];
    }
    {
        [_color set];
        UIBezierPath *path = [UIBezierPath bezierPathWithArcCenter:CGPointMake(bounds.size.width/2.0, bounds.size.height/2.0)
                                                            radius:radius
                                                        startAngle:3.0*M_PI/4.0
                                                          endAngle:3.0*M_PI/4.0 + 3.0*M_PI/2.0*_value
                                                         clockwise:YES];
        path.lineWidth = width;
        [path stroke];
    }
}

@end
