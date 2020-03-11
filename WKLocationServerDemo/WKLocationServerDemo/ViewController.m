//
//  ViewController.m
//  WKLocationServerDemo
//
//  Created by Anmo on 2020/3/9.
//  Copyright © 2020 com.Cingjin. All rights reserved.
//

#ifdef DEBUG

#define Log(FORMAT, ...) fprintf(stderr,"%s\n",[[NSString stringWithFormat:FORMAT, ##__VA_ARGS__] UTF8String]);

#else

#define Log(...)

#endif

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
                                                 LoacationWay:@[BAIDU,GAODE,TXVIDEO]
                                                 SuccessBlock:^(NSString * _Nonnull locationAreaStr, NSString * _Nonnull locationWay) {
        Log(@"成功 -> 定位地址：%@  定位方式：%@",locationAreaStr,locationWay);
    } FailureBlock:^(NSString * _Nonnull locationAreaStr, NSString * _Nonnull locationWay) {
        Log(@"失败 -> 定位地址：%@  定位方式：%@",locationAreaStr,locationWay);
    }];
}


@end
