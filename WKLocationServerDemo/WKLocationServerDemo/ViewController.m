//
//  ViewController.m
//  WKLocationServerDemo
//
//  Created by Anmo on 2020/3/9.
//  Copyright © 2020 com.Cingjin. All rights reserved.
//

#import "ViewController.h"
#import "WKLocationServer.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [[WKLocationServer shareInstance]location_ServiceOfsystem:NO
                                                   ddObserver:self
                                                      TimeOut:3.0
                                                 LoacationWay:@[GAODE,BAIDU]
                                                 SuccessBlock:^(NSString * _Nonnull locationAreaStr, NSString * _Nonnull locationWay) {
        
    } FailureBlock:^(NSString * _Nonnull locationAreaStr, NSString * _Nonnull locationWay) {
        
    }];
}


@end
