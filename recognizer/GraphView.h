//
//  GraphView.h
//  recognizer
//
//  Created by 이승희 on 7/16/16.
//  Copyright © 2016 이승희. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface GraphView : UIView{
    CGContextRef context;
    CAShapeLayer *slB;
    
}

@property (nonatomic, retain) NSMutableArray* data;

#define kStepY 50
#define kOffsetY 0
#define kGraphHeight 300
#define kDefaultGraphWidth 2000
#define kOffsetX 0
#define kStepX 50
#define kGraphBottom 300
#define kGraphTop 0

- (void)addData:(NSNumber *) newData;

@end

