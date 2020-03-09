//
//  WKLocationServer.h
//  AllLiveTV
//
//  Created by Anmo on 2019/8/7.
//  Copyright © 2019 com.Cingjin. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <WebKit/WebKit.h>

NS_ASSUME_NONNULL_BEGIN

#define GAODE       @"'GAODE'"    //  高德定位
#define TXVIDEO     @"'TXVIDEO'"  //  腾讯定位
#define BAIDU       @"'BAIDU'"    //  百度定位
#define LETV        @"'LETV'"     //  LETV定位
#define TAOBAO      @"'TAOBAO'"   //  TAOBAO定位
#define IPADRESS    @"'IP-ADRESS'"//  海外定位
#define QIHOO       @"'QIHOO'"    //  360定位

/**
 *  定位回调
 *  @param  locationAreaStr     定位字符串
 *  @param  locationWay         定位方式
 */
typedef void(^LocationResultBlock)(NSString  * locationAreaStr,NSString * locationWay);


@interface WKLocationServer : NSObject


+(WKLocationServer *)shareInstance;

- (instancetype)init UNAVAILABLE_ATTRIBUTE;

+ (instancetype)new UNAVAILABLE_ATTRIBUTE;

/**
 *  带有block回调
 *
 *  @param  system      是否需要系统定位，需要为YES不需要NO 若要使用系统定位需允许定位权限和在plist文件添加Privacy - Location When In Use Usage Description
 *  @param  timeOut     定位最长超时时间
 *  @param  ways        定位方式@[GAODE,TXVIDEO,BAIDU]，可以控制顺序和定位方式
 *  @param  success     成功结果返回，如果全部定位失败，如果最后一次失败是返回成功的，始终只返回一次
 *  @param  failure     定位失败回调
 */
-(void)location_ServiceOfsystem:(BOOL)system
                     ddObserver:(id)observer
                        TimeOut:(NSInteger)timeOut
                   LoacationWay:(NSArray * _Nonnull )ways
                   SuccessBlock:(LocationResultBlock)success
                   FailureBlock:(LocationResultBlock)failure;


/** 定位中：YES、定位完成：NO*/
@property (nonatomic ,assign ,readonly) BOOL    locationing;

/** 是否定位成功以地址为准*/
@property (nonatomic ,assign ,readonly) BOOL    locationSuccess;

/** 是否VPN环境*/
@property (nonatomic ,assign ,readonly) BOOL    locationVPNStauts;

/** 定位城市字符串*/
@property (nonatomic ,copy ,readonly) NSString  * locationResult;

/** 定位方式*/
@property (nonatomic ,copy ,readonly) NSString  * locationWay;


@end


@interface LocationDeallocWatcher : NSObject

@property (nonatomic, copy) dispatch_block_t deallocCallback;

- (instancetype)initWithDeallocCallback:(dispatch_block_t)callback;

@end


@interface LiveTVWebViewScriptMessageDelegate : NSObject<WKScriptMessageHandler>

//WKScriptMessageHandler 这个协议类专门用来处理JavaScript调用原生OC的方法
@property (nonatomic, weak)id<WKScriptMessageHandler> scriptDelegate;

- (instancetype)initWithDelegate:(id<WKScriptMessageHandler>)scriptDelegate;

@end

NS_ASSUME_NONNULL_END
