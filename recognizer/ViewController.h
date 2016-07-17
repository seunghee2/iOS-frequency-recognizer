//
//  ViewController.h
//  recognizer
//
//  Created by 이승희 on 7/14/16.
//  Copyright © 2016 이승희. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "GraphView.h"

@interface ViewController : UIViewController {
    
    __weak IBOutlet UILabel *HzValueLabel;
    __weak IBOutlet UIScrollView *scroller;

}
@property (weak, nonatomic) IBOutlet GraphView *graphView;

@end
