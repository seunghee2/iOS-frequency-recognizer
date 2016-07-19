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
        
        path = [[UIBezierPath alloc]init];
        count = 0;
        
        slB = [[CAShapeLayer alloc] init];
        slB.fillColor = [UIColor orangeColor].CGColor;
        slB.strokeColor = [UIColor orangeColor].CGColor;
        slB.lineWidth = 2;
        [self.layer addSublayer:slB];
    }
    return self;
}
- (void)addData:(NSNumber *) newData{
    [self.data addObject:newData];
    count++;
    [self drawLine:count];
    NSLog(@"%d", count);
}

-(void)drawLine:(int) index
{
    float px = kStepX * (index - 1);
    float py = 350 - [[data objectAtIndex:(index - 1)] floatValue] / 100;
   
    if (index == 1)
    {
        [path appendPath:[UIBezierPath bezierPathWithRoundedRect:CGRectMake(px, py, 6, 6) cornerRadius:5]];
        [path moveToPoint:CGPointMake(px + 3, py + 3)];
    }
    else
    {
        [path addLineToPoint:CGPointMake(px + 3, py + 3)];
        [path appendPath:[UIBezierPath bezierPathWithRoundedRect:CGRectMake(px, py, 5, 5) cornerRadius:5]];
        [path moveToPoint:CGPointMake(px + 3, py + 3)];
    }
    slB.path = path.CGPath;
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
}



@end
