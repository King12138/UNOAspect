//
//  ViewController.m
//  UNOAspect
//
//  Created by intebox on 2018/5/10.
//  Copyright © 2018年 unovo. All rights reserved.
//

#import "ViewController.h"
#import "NSObject+UNO_aspect.h"

@interface ViewController ()
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    [self aspect_fromSelector:@selector(touchesBegan:withEvent:)
                           to:@selector(_test_touchesBegan:withEvent:)];
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event{
    NSLog(@"origin %p  %p",touches,event);
    self.hidesBottomBarWhenPushed = !self.hidesBottomBarWhenPushed;
}

- (void)_test_touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event{
    NSLog(@"aspect %p  %p",touches,event);
}

@end
