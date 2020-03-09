//
//  WKLocationServer.m
//  AllLiveTV
//
//  Created by Anmo on 2019/8/7.
//  Copyright © 2019 com.Cingjin. All rights reserved.
//

#define locationWeb         @"http://pd4c.jrysdq.cn:10081/location/index.html"
#define locationWebCache    @"locationWebCache"

#import "WKLocationServer.h"

// System
#import <objc/runtime.h>
#import <netinet/in.h>
#import <CoreLocation/CoreLocation.h>
#import <SystemConfiguration/SystemConfiguration.h>

@interface WKLocationServer()

<WKUIDelegate,
WKNavigationDelegate,
WKScriptMessageHandler,
CLLocationManagerDelegate>

/** 系统定位是否回调过*/
@property (nonatomic ,assign) BOOL                  isSuccess;
/** 超时时间*/
@property (nonatomic ,assign) NSInteger             timeOut;
/** jsCoder*/
@property (nonatomic ,copy) NSString                * jsCode;
/** 系统定位*/
@property (nonatomic, strong) CLLocationManager     * locationManager;
/** webview */
@property (nonatomic, strong) WKWebView             * wkWebView;
/** 定位方式数组*/
@property (nonatomic ,strong) NSMutableArray        * locationWays;
/** successTable*/
@property (nonatomic, strong) NSMapTable            * successBlockTable;
/** failureTable*/
@property (nonatomic, strong) NSMapTable            * failureBlockTable;

@end

@implementation WKLocationServer


@synthesize locationWay         = _locationWay;
@synthesize locationing         = _locationing;
@synthesize locationResult      = _locationResult;
@synthesize locationSuccess     = _locationSuccess;
@synthesize locationVPNStauts   = _locationVPNStauts;


static WKLocationServer * _instance = nil;



+(WKLocationServer *)shareInstance{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [[self alloc] initPrivate];
    });
    return _instance;
}

- (instancetype)init {
    return [[self class] shareInstance];
}

- (instancetype)initPrivate{
    self = [super init];
    if (self) {
        // key为 observer 注册对象，用 weak 属性表示不持有 observer，仅指向 observer
        // value 为 observer 注册的 block 回调，使用 strong 属性意味着映射表要持有 block
        self.successBlockTable = [[NSMapTable alloc] initWithKeyOptions:NSPointerFunctionsWeakMemory valueOptions:NSPointerFunctionsStrongMemory capacity:1];
        self.failureBlockTable = [[NSMapTable alloc] initWithKeyOptions:NSPointerFunctionsWeakMemory valueOptions:NSPointerFunctionsStrongMemory capacity:1];
    }
    return self;
}

- (void)location_ServiceOfsystem:(BOOL)system
                      ddObserver:(id)observer
                         TimeOut:(NSInteger)timeOut
                    LoacationWay:(NSArray *)ways
                    SuccessBlock:(LocationResultBlock)success
                    FailureBlock:(LocationResultBlock)failure {
    
    // 把调用的block加入到NSMapTable中后面统一回调
    [self location_saveObserver:observer Block:success MapTable:self.successBlockTable];

    if (self.locationSuccess) {
        // 回调缓存数据回去
        [self location_callBack];
    } else {
        // 如果正在定位等定位完了统一回调出去
        [self location_saveObserver:observer Block:failure MapTable:self.failureBlockTable];
        if (!self.locationing) {
            self.timeOut        = timeOut;
            self.locationing    = YES;
            [self location_processLocationWay:ways];
            // 如果需要系统定位那就只先系统定位，系统定位失败再执行解析定位
            if (system) {
                [self location_ofSystem];
            } else {
                [self location_startOfIPLocation];
            }
        }
    }
}

/** 开始定位*/
- (void)location_ofSystem {
    
    if (!_locationManager) {
        self.locationManager = [[CLLocationManager alloc] init];
        self.locationManager.delegate = self;
        self.locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters;
    }
    // 1. 请求系统定位
    CLAuthorizationStatus authStatus = [CLLocationManager authorizationStatus];
    switch (authStatus) {
        case kCLAuthorizationStatusNotDetermined: {                 // 第一次未授权，未弹框
            [self.locationManager requestWhenInUseAuthorization];
            [self.locationManager startUpdatingLocation];
            // 有种问题就是弹框的时候进入到后台，等过段时间再回来的时候如果没有重新调用定位则不会再次弹框
            [self performSelector:@selector(location_ofSystem) withObject:nil afterDelay:10.0];
            break;
        }
        case kCLAuthorizationStatusRestricted:                      // 限制和拒绝授权
            
        case kCLAuthorizationStatusDenied: {
            [self location_startOfIPLocation];
            break;
        }
        case kCLAuthorizationStatusAuthorizedWhenInUse:             // 允许定位
            
        case kCLAuthorizationStatusAuthorizedAlways:{
            [self.locationManager startUpdatingLocation];
            break;
        }
    }
}

#pragma mark - CLLocationManagerDelegate

// 定位错误
- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error {
    
    // 取消延迟执行
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(location_startOfIPLocation) object:nil];
    [self.locationManager stopUpdatingLocation];
    [self location_startOfIPLocation];
}

// 定位更新
- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations {
    
    // 取消延迟执行
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(location_startOfIPLocation) object:nil];
    
    CLLocation *currentLocation = [locations lastObject];
    // 获取当前所在的城市名
    CLGeocoder *geocoder = [[CLGeocoder alloc] init];
    // 将系统语言强制转换为中文再获取城市名称
    // 保存 Device 的现语言 (英语 法语 ，，，)
    NSMutableArray *userDefaultLanguages = [[NSUserDefaults standardUserDefaults] objectForKey:@"AppleLanguages"];
    // 强制转成 简体中文
    [[NSUserDefaults standardUserDefaults] setObject:[NSArray arrayWithObjects:@"zh-hans",nil] forKey:@"AppleLanguages"];
    
    //    currentLocation = [[CLLocation alloc]initWithLatitude:38.42 longitude:112.73];
    // 根据经纬度反向地理编译出地址信息
    [geocoder reverseGeocodeLocation:currentLocation completionHandler:^(NSArray *array, NSError *error){
        
        if (!error && array.count > 0) {
            
            CLPlacemark *placemark = [array objectAtIndex:0];
            // 获取城市
            // 国家
            NSString *country = placemark.country;
            // 省份
            NSString *area = placemark.administrativeArea;
            // 市区
            NSString *city = placemark.locality;
            
            NSString * location = @"";
            if (area) { // 如果省份有值 直接取省份
                
                location = [NSString stringWithFormat:@"%@|%@|%@", country, area, city];
                
                // 定位信息一样 不做处理
                //                if ([self.locationStr isEqualToString:location]) { return; }
                self.locationResult = location;
                
            } else {
                
                location = [NSString stringWithFormat:@"%@|%@|%@", country, @"", city];
                // 定位信息一样 不做处理
                //                if ([self.locationStr isEqualToString:location]) { return; }
                self.locationResult = location;
            }
            [self location_result:location success:YES way:@"SYSTEM"];
        }else { // 定位失败
            [self location_startOfIPLocation];
            [self location_result:@"失败" success:NO way:@"SYSTEM"];
        }
        // 还原Device 的语言
        [[NSUserDefaults standardUserDefaults] setObject:userDefaultLanguages forKey:@"AppleLanguages"];
    }];
    [self.locationManager stopUpdatingLocation];
}

// 定位状态修改
- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status {
    
    switch (status) {
        case kCLAuthorizationStatusNotDetermined:                   // 第一次未授权，未弹框
            break;
        case kCLAuthorizationStatusRestricted:                      // 限制和拒绝授权
        case kCLAuthorizationStatusDenied: {
            
            break;
        }
        case kCLAuthorizationStatusAuthorizedWhenInUse:             // 允许定位
        case kCLAuthorizationStatusAuthorizedAlways:{
            break;
        }
    }
}

- (void)location_startOfIPLocation {
    // 判断是否是 VPN
    if (self.location_isVPN) {
        // 计算定位信息
        [self location_result:@"失败" success:YES way:@"VPN"];
    }else{
        // 检测网络状态如果当前网络状态可以连通则可以进行定位网络请求
        if (self.location_netStatus) {
            [self location_ofWebLocation];
            if (self.timeOut > 0) {
                // timeOut超时处理，如果timeOut时间内还没定位完成则回调
                [self performSelector:@selector(location_TimeOutBlock) withObject:self afterDelay:self.timeOut inModes:@[NSRunLoopCommonModes]];
            }
        } else {
            [self location_result:@"失败" success:YES way:@"NOWAY"];
        }
    }
}


-(void)location_ofWebLocation{
    
//    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:locationWeb]];
    NSMutableURLRequest * request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:locationWeb]
                                                            cachePolicy:NSURLRequestUseProtocolCachePolicy
                                                        timeoutInterval:20];
    NSDictionary * cacheHeader = [[NSUserDefaults standardUserDefaults]objectForKey:locationWebCache];
    if (cacheHeader) {
        NSString * etag = [cacheHeader objectForKey:@"Etag"];
        if (etag) {
            [request setValue:etag forHTTPHeaderField:@"If-None-Match"];
        }
        NSString * lastModified = [cacheHeader objectForKey:@"Last-Modified"];
        if (lastModified) {
            [request setValue:lastModified forHTTPHeaderField:@"If-Modified-Since"];
        }
    }
    [self.wkWebView loadRequest:request];
    [self location_reloadWkCache:request];
}

// 添加缓存策略
- (void)location_reloadWkCache:(NSMutableURLRequest *)request {
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        // 异步更新缓存
        [[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
            NSHTTPURLResponse * httpResponse = (NSHTTPURLResponse *)response;
            NSLog(@"httpResponse == %@",httpResponse);
            // 根据statusCode设置缓存策略
            if (httpResponse.statusCode == 200 || httpResponse.statusCode == 0) {
                [request setCachePolicy:NSURLRequestReturnCacheDataElseLoad];
            } else {
                [request setCachePolicy:NSURLRequestReloadIgnoringLocalCacheData];
            }
            // 保存当前NSHTTPURLRespon
            [[NSUserDefaults standardUserDefaults]setObject:httpResponse.allHeaderFields forKey:locationWebCache];
            dispatch_async(dispatch_get_main_queue(), ^{
                // 重新刷新
                [self.wkWebView reload];
            });
        }] resume];
    });
}

#pragma mark - WKNavigationDelegate

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    
    [self location_jsFunc:self.jsCode];
}

#pragma mark - WKScriptMessageHandler

- (void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *)message {
    
    if ([message.name isEqualToString: @"OCProxy"]) {
        NSDictionary * dict = (NSDictionary * )message.body;
        NSDictionary * headerDic = [dict objectForKey:@"headers"];
        NSString * url = [dict objectForKey:@"url"];
        NSString * headerKey    = @"";
        NSString * heaaderValue = @"";
        NSDictionary * paramaDict = [dict objectForKey:@"params"];
        NSString * callBack = [dict objectForKey:@"callback"];
        if (headerDic) {
            NSArray * keys      = [headerDic allKeys];
            NSArray * values    = [headerDic allValues];
            if (keys.count > 0 && keys) {headerKey = keys[0];}
            if (values.count > 0 && values) {heaaderValue = values[0];}
        }
        [self loation_request:url headerKey:headerKey headerValue:heaaderValue param:paramaDict jsCallback:callBack];
    } else {
        // 方法名
        NSString *methods = [NSString stringWithFormat:@"%@:", message.name];
        SEL selector = NSSelectorFromString(methods);
        // 调用方法
        if ([self respondsToSelector:selector]) {
            [self performSelector:selector withObject:message.body];
        } else {
            NSLog(@"未调用方法");
        }
    }
}

- (void)JavaScriptCallOC:(id)dict{
    
    if (self.isSuccess) {   // 如果是之前成功了就不用回调了
        self.isSuccess = !self.isSuccess;
        return;
    }
    NSString *locationString;
    NSString *locationWay;
    if ([[dict objectForKey:@"status"]integerValue] == 200) {
        
        NSString * str = [dict objectForKey:@"data"];
        NSData *data = [self locetion_dataWithBase64EncodedString:str];
        locationString  = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        locationWay = [dict objectForKey:@"server"];
        self.isSuccess = YES;
        [self location_result:locationString success:YES way:locationWay];
        
    } else {
        locationString  = @"失败";
        locationWay = [dict objectForKey:@"server"];
        if ([locationWay containsString:[self.locationWays lastObject]]) {
            self.isSuccess = YES;
            [self location_result:locationString success:YES way:locationWay];
        } else {
            [self location_result:locationString success:NO way:locationWay];
        }
    }
}

- (void)location_TimeOutBlock {
    if (self.isSuccess) {   // 如果是之前成功了就不用回调了
        self.isSuccess = !self.isSuccess;
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(location_TimeOutBlock) object:nil];
        return;
    }
    self.isSuccess = YES;
    [self location_result:@"失败" success:YES way:@"NOWAY"];
}


- (void)location_jsFunc:(NSString *)js {
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.wkWebView evaluateJavaScript:js completionHandler:^(id object, NSError * _Nullable error) {
           if (error) {  [self location_jsError];}
        }];
    });
}

- (void)location_jsError {
    [self.wkWebView evaluateJavaScript:@"window.handler();" completionHandler:^(id object, NSError * _Nullable error) {
        NSLog(@"error %@",error.description);
    }];
}

- (void)loation_request:(NSString *)url
              headerKey:(NSString *)headerKey
            headerValue:(NSString *)headerValue
                  param:(id)parama
             jsCallback:(NSString *)callback {
    
    NSMutableURLRequest * request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]];
    NSString * userAgent = [request valueForHTTPHeaderField:headerKey];
    userAgent = headerValue;
    [request setValue:userAgent forHTTPHeaderField:headerKey];
    [request setHTTPMethod:@"GET"];
    request.timeoutInterval = 5.0;
    NSURLSession * session = [NSURLSession sharedSession];
    NSURLSessionDataTask * dataTask = [session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        //判断statusCode
        NSHTTPURLResponse *res = (NSHTTPURLResponse *)response;
        NSString * js = [callback stringByReplacingOccurrencesOfString:@"%@" withString:@""];
        if (res.statusCode == 200 && !error) {
            js = [callback stringByReplacingOccurrencesOfString:@"%@" withString:[data base64EncodedStringWithOptions:0]];
        }
        [self location_jsFunc:js];
        return ;
    }];
    // 开始任务
    [dataTask resume];
}


- (NSString *)location_dictionaryToJson:(NSDictionary *)dic {
    NSError *parseError = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dic options:NSJSONWritingPrettyPrinted error:&parseError];
    return [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
}

#pragma mark - PrivateMethod

/// 处理定位方式组装JS
- (void)location_processLocationWay:(NSArray * )ways {
    
    self.locationWays = @[].mutableCopy;
    if (ways && ways.count > 0) {
        for (int i = 0; i<ways.count; i++) {
            [self.locationWays addObject:ways[i]];
        }
    } else {
        // 默认定位排序方式
        [self.locationWays addObjectsFromArray:@[GAODE,BAIDU,TXVIDEO,LETV,TAOBAO,IPADRESS]];
    }
    // '' 定位方式这两个符号必须是英文输入法下分符号 ’‘中文下错误
    NSString *text = [self.locationWays componentsJoinedByString:@","];
    self.jsCode = [NSString stringWithFormat:@"window.parsing([%@])",text];
}

/// 参考资料：https://www.jianshu.com/p/b7d0b78a7661
- (void)location_saveObserver:(id)observer Block:(LocationResultBlock)block MapTable:(NSMapTable *)table {
    //将block进行判空处理，防止存储时为nil造成crash
    if (block == nil) {
        return;
    }
    // 这里要打破循环引用，因为关联代码中 watch 被 observer 持有，而 watch 中的 callback 去调用了 observer
    __weak typeof (observer) weakObserver = observer;
    LocationDeallocWatcher *watch = [[LocationDeallocWatcher alloc] initWithDeallocCallback:^{
        __strong typeof (observer) strongObserver = weakObserver;
        [self lcoation_removeObserver:strongObserver MapTable:table];
    }];
    [table setObject:block forKey:observer];
    // 将 observer 与 watch 进行绑定关联，key 则使用 observer 的打印地址
    objc_setAssociatedObject(observer, [[NSString stringWithFormat:@"%p", &observer] UTF8String], watch, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [table objectForKey:observer];
}

- (void)lcoation_removeObserver:(id)observer MapTable:(NSMapTable *)table{
    [table removeObjectForKey:observer];
    objc_setAssociatedObject(observer, [[NSString stringWithFormat:@"%p", &observer] UTF8String], nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)location_runBlockMethod:(NSString *)locationAddress locationWay:(NSString *)locationWay  MapTable:(NSMapTable *)table {
    // 当需要去执行映射表中的block代码块时，遍历映射表并执行已有的block块然后统一回调block
    [[[table objectEnumerator] allObjects] enumerateObjectsUsingBlock:^(LocationResultBlock resultBlock, NSUInteger idx, BOOL * _Nonnull stop) {
        resultBlock(locationAddress,locationWay);
    }];
    [table removeAllObjects];
}

- (void) location_callBack {
    
    [self location_runBlockMethod:self.locationResult locationWay:self.locationWay MapTable:self.successBlockTable];
}

/// 处理回调
- (void)location_result:(NSString *)result success:(BOOL)success way:(NSString *)way{
    
    if (!way || !(way.length >0)) {way = @"NOWAY";}
    if (!result || !(result.length >0)) { result = @"失败";}
    self.locationWay = way;
    self.locationResult = result;
    if (success) {
        self.locationing = NO;
        self.locationSuccess = ![self.locationResult isEqualToString:@"失败"];
        // 完成回调
        [self location_runBlockMethod:self.locationResult locationWay:way MapTable:self.successBlockTable];
    } else {
        [self location_runBlockMethod:self.locationResult locationWay:way MapTable:self.failureBlockTable];
    }
}

///  判断是否是VPN定位
- (BOOL)location_isVPN {
    
    NSDictionary *dict = CFBridgingRelease(CFNetworkCopySystemProxySettings());
    NSArray *keys = [dict[@"__SCOPED__"]allKeys];
    for (NSString *key in keys) {
        if ([key rangeOfString:@"tap"].location != NSNotFound ||
            [key rangeOfString:@"tun"].location != NSNotFound ||
            [key rangeOfString:@"ppp"].location != NSNotFound ||
            [key rangeOfString:@"sec"].location != NSNotFound){
            return YES;
        }
    }
    return NO;
}

/// 检测App内网络连接情况
- (BOOL)location_netStatus {

    struct sockaddr zeroAddress;
    bzero(&zeroAddress,sizeof(zeroAddress));
    zeroAddress.sa_len=sizeof(zeroAddress);
    zeroAddress.sa_family= AF_INET;
    //根据传入的地址创建网络连接引用
    SCNetworkReachabilityRef defaultRouteReachability = SCNetworkReachabilityCreateWithAddress(NULL, (struct sockaddr *)&zeroAddress);
    SCNetworkReachabilityFlags flags;
    //获取网络连接状态(是否存在网络连接)第一个参数为之前建立的测试连接的引用，第二个参数用来保存获得的状态，如果能获得状态则返回TRUE，否则返回FALSE
    BOOL didReceiveFlags =SCNetworkReachabilityGetFlags(defaultRouteReachability, &flags);
    CFRelease(defaultRouteReachability);
    if(!didReceiveFlags) {
        return NO;
    }
    BOOL isReachable = flags &kSCNetworkFlagsReachable;//表明网络可以访问。
    BOOL needsConnection = flags & kSCNetworkFlagsConnectionRequired;//无需更多链接。
    return(isReachable && !needsConnection) ?YES:NO;
}

/// 参照YYKit
static const short location_base64DecodingTable[256] = {
    -2, -2, -2, -2, -2, -2, -2, -2, -2, -1, -1, -2,  -1,  -1, -2, -2,
    -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2,  -2,  -2, -2, -2,
    -1, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, 62,  -2,  -2, -2, 63,
    52, 53, 54, 55, 56, 57, 58, 59, 60, 61, -2, -2,  -2,  -2, -2, -2,
    -2, 0,  1,  2,  3,  4,  5,  6,  7,  8,  9,  10,  11,  12, 13, 14,
    15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, -2,  -2,  -2, -2, -2,
    -2, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36,  37,  38, 39, 40,
    41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, -2,  -2,  -2, -2, -2,
    -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2,  -2,  -2, -2, -2,
    -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2,  -2,  -2, -2, -2,
    -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2,  -2,  -2, -2, -2,
    -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2,  -2,  -2, -2, -2,
    -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2,  -2,  -2, -2, -2,
    -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2,  -2,  -2, -2, -2,
    -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2,  -2,  -2, -2, -2,
    -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2,  -2,  -2, -2, -2
};

- (NSData *)locetion_dataWithBase64EncodedString:(NSString *)base64EncodedString {
    
    NSInteger length = base64EncodedString.length;
    const char *string = [base64EncodedString cStringUsingEncoding:NSASCIIStringEncoding];
    if (string  == NULL)
        return nil;
    
    while (length > 0 && string[length - 1] == '=')
        length--;
    
    NSInteger outputLength = length * 3 / 4;
    NSMutableData *data = [NSMutableData dataWithLength:outputLength];
    if (data == nil)
        return nil;
    if (length == 0)
        return data;
    
    uint8_t *output = data.mutableBytes;
    NSInteger inputPoint = 0;
    NSInteger outputPoint = 0;
    while (inputPoint < length) {
        char i0 = string[inputPoint++];
        char i1 = string[inputPoint++];
        char i2 = inputPoint < length ? string[inputPoint++] : 'A';
        char i3 = inputPoint < length ? string[inputPoint++] : 'A';
        
        output[outputPoint++] = (location_base64DecodingTable[i0] << 2)
        | (location_base64DecodingTable[i1] >> 4);
        if (outputPoint < outputLength) {
            output[outputPoint++] = ((location_base64DecodingTable[i1] & 0xf) << 4)
            | (location_base64DecodingTable[i2] >> 2);
        }
        if (outputPoint < outputLength) {
            output[outputPoint++] = ((location_base64DecodingTable[i2] & 0x3) << 6)
            | location_base64DecodingTable[i3];
        }
    }
    
    return data;
}


#pragma mark - Setter

- (void)setLocationWay:(NSString * _Nonnull)locationWay {
    _locationWay = locationWay;
}

- (void)setLocationResult:(NSString * _Nonnull)locationResult {
    _locationResult = locationResult;
}

- (void)setLocationing:(BOOL)locationing {
    _locationing = locationing;
}

- (void)setLocationSuccess:(BOOL)locationSuccess {
    _locationSuccess = locationSuccess;
}

- (void)setLocationVPNStauts:(BOOL)locationVPNStauts {
    _locationVPNStauts = locationVPNStauts;
}

#pragma mark - Getter

- (BOOL)locationVPNStauts {
    
    return self.location_isVPN;

}

- (WKWebView *)wkWebView{
    if (_wkWebView == nil) {
        WKWebViewConfiguration *config = [[WKWebViewConfiguration alloc] init];
        WKUserScript *partScript = [[WKUserScript alloc] initWithSource:@"(function(){if(window.parent != window){parent.postMessage({event:'IFRAME_CONTENT_CAPTURED',domain:document.domain, content:document.body.innerText},'*')}})();" injectionTime:WKUserScriptInjectionTimeAtDocumentEnd forMainFrameOnly:NO];
        _wkWebView = [[WKWebView alloc]initWithFrame:CGRectZero configuration:config];
        _wkWebView.navigationDelegate = self;
        _wkWebView.UIDelegate = self;
         [config.userContentController addUserScript:partScript];
        LiveTVWebViewScriptMessageDelegate * weakScriptMessageDelegate = [[LiveTVWebViewScriptMessageDelegate alloc]initWithDelegate:self];
         [[_wkWebView configuration].userContentController addScriptMessageHandler:weakScriptMessageDelegate name:@"JavaScriptCallOC"];
         [[_wkWebView configuration].userContentController addScriptMessageHandler:weakScriptMessageDelegate name:@"OCProxy"];
    }
    return _wkWebView;
}

@end


@implementation  LocationDeallocWatcher

- (instancetype)initWithDeallocCallback:(dispatch_block_t)callback {
    self = [super init];
    if (self) {
        self.deallocCallback = callback;
    }
    return self;
}

- (void)dealloc
{
    // 关键代码，当该对象释放触发 dealloc 方法时，会去执行 callback 回调
    if (self.deallocCallback) {
        self.deallocCallback();
    }
}

@end


@implementation LiveTVWebViewScriptMessageDelegate

- (instancetype)initWithDelegate:(id<WKScriptMessageHandler>)scriptDelegate {
    self = [super init];
    if (self) {
        _scriptDelegate = scriptDelegate;
    }
    return self;
}


#pragma mark - WKScriptMessageHandler
//遵循WKScriptMessageHandler协议，必须实现如下方法，然后把方法向外传递
//通过接收JS传出消息的name进行捕捉的回调方法
- (void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *)message {
    if ([self.scriptDelegate respondsToSelector:@selector(userContentController:didReceiveScriptMessage:)]) {
        [self.scriptDelegate userContentController:userContentController didReceiveScriptMessage:message];
    }
}


@end
