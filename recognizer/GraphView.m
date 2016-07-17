//
//  GraphView.m
//  recognizer
//
//  Created by 이승희 on 7/16/16.
//  Copyright © 2016 이승희. All rights reserved.
//

#import "GraphView.h"
#import <QuartzCore/QuartzCore.h>



@implementation GraphView
@synthesize data;

-(id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if(self)
    {
        self.data = [[NSMutableArray alloc]init];
        slB = [[CAShapeLayer alloc] init];
        slB.fillColor = [UIColor clearColor].CGColor;
        slB.strokeColor = [UIColor redColor].CGColor;
        slB.lineWidth = 2;
        [self.layer addSublayer:slB];
    }
    return self;
}
- (void)addData:(NSNumber *) newData{
    [self.data addObject:newData];
}


- (void)drawRect:(CGRect)rect
{
    context = UIGraphicsGetCurrentContext();
    CGContextSetLineWidth(context, 0.6);
    CGContextSetStrokeColorWithColor(context, [[UIColor lightGrayColor] CGColor]);
    
    
    // How many lines?
    int howMany = (kDefaultGraphWidth - kOffsetX) / kStepX;
    
    // Here the lines go
    for (int i = 0; i < howMany; i++)
    {
        CGContextMoveToPoint(context, kOffsetX + i * kStepX, kGraphTop);
        CGContextAddLineToPoint(context, kOffsetX + i * kStepX, kGraphBottom);
    }
    
    int howManyHorizontal = (kGraphBottom - kGraphTop - kOffsetY) / kStepY;
    for (int i = 0; i <= howManyHorizontal; i++)
    {
        CGContextMoveToPoint(context, kOffsetX, kGraphBottom - kOffsetY - i * kStepY);
        CGContextAddLineToPoint(context, kDefaultGraphWidth, kGraphBottom - kOffsetY - i * kStepY);
    }
    
    
    CGFloat dash[] = {2.0, 2.0};
    CGContextSetLineDash(context, 0.0, dash, 2);
    
    CGContextStrokePath(context);
    
   
    NSTimer* timer = [NSTimer timerWithTimeInterval:3.0f target:self selector:@selector(drawLine) userInfo:nil repeats:YES];
    [[NSRunLoop mainRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
    
}

-(void)drawLine
{
    if([data count] > 0){
        
        UIBezierPath *path = [[UIBezierPath alloc]init];
        for(int i = 0; i < [data count]; i++)
        {
            float px = kStepX * i;
            float py = 200 - [[data objectAtIndex:i] floatValue] / 1000 * 20;
            if(i == 0)
            {
                [path appendPath:[UIBezierPath bezierPathWithRoundedRect:CGRectMake(px, py, 10, 10) cornerRadius:5]];
                [path moveToPoint:CGPointMake(px + 5, py + 5)];
            }
            else
            {
                [path addLineToPoint:CGPointMake(px + 5, py + 5)];
                [path appendPath:[UIBezierPath bezierPathWithRoundedRect:CGRectMake(px, py, 10, 10) cornerRadius:5]];
                [path moveToPoint:CGPointMake(px + 5, py + 5)];
            }
            slB.path = path.CGPath;
        }
        
        /*
        CGContextSetLineWidth(context, 2.0);
        CGContextSetStrokeColorWithColor(context, [[UIColor colorWithRed:1.0 green:0.5 blue:0 alpha:1.0] CGColor]);
        
        int maxGraphHeight = kGraphHeight - kOffsetY;
        CGContextBeginPath(context);
        
        float tmp = [[data objectAtIndex:0] floatValue] / 1000;

        CGContextMoveToPoint(context, kOffsetX, kGraphHeight - maxGraphHeight * tmp);
        
        for (int i = 1; i < data.count; i++)
        {
            float value = [[data objectAtIndex:i] floatValue] / 1000;
            CGContextAddLineToPoint(context, kOffsetX + i * kStepX, kGraphHeight - maxGraphHeight * value);
            NSLog(@"data : %0.3f", value);
        }
        
        CGContextDrawPath(context, kCGPathStroke);
        */
    }
}

@end
