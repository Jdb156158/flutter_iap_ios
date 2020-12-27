#import "FlutterIapIosPlugin.h"
#import "IAPDelegate.h"
#import "HudManager.h"

#define kIAPDelegateSuccess     @"kIAPDelegateSuccess"
#define kIAPDelegateFailed      @"kIAPDelegateFailed"
#define kIAPDelegateRestored    @"kIAPDelegateRestored"
#define kIAPDelegateChecked     @"kIAPDelegateChecked"


@implementation FlutterIapIosPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  FlutterMethodChannel* channel = [FlutterMethodChannel
      methodChannelWithName:@"flutter_iap_ios"
            binaryMessenger:[registrar messenger]];
  FlutterIapIosPlugin* instance = [[FlutterIapIosPlugin alloc] init];
  [registrar addMethodCallDelegate:instance channel:channel];
    
    //初始化通知
    [instance initNSNotificationCenter];
}

- (void)initNSNotificationCenter{
    // 注册恢复购买结果通知
    [[NSNotificationCenter defaultCenter] addObserverForName:kIAPDelegateRestored object:nil queue:nil usingBlock:^(NSNotification * _Nonnull note) {
        //NSLog(@"恢复购买成功!");
    }];
    
    // 注册购买结果通知
    [[NSNotificationCenter defaultCenter] addObserverForName:kIAPDelegateFailed object:nil queue:nil usingBlock:^(NSNotification * _Nonnull note) {
        //NSLog(@"payProductId====购买失败!");
    }];
    
    [[NSNotificationCenter defaultCenter] addObserverForName:kIAPDelegateSuccess object:nil queue:nil usingBlock:^(NSNotification * _Nonnull note) {
        // restore UI interaction.
        //NSLog(@"payProductId====购买成功!");
    }];
}

- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
    
  if ([@"getPlatformVersion" isEqualToString:call.method]) {
    result([@"iOS " stringByAppendingString:[[UIDevice currentDevice] systemVersion]]);
  }else if ([@"initProducts" isEqualToString:call.method]){
            
      //初始化商品信息
      NSLog(@"=====初始化商品信息:%@======",call.arguments);
      [[IAPDelegate shared] fetchAllProducts:call.arguments compelete:^(NSArray * _Nonnull newProductsArray) {
          NSLog(@"=====初始化商品的详细信息:%@======",newProductsArray);
          if (newProductsArray.count>0) {
              
              //result(newProductsArray);
              
              // 注册恢复购买结果通知
              [[NSNotificationCenter defaultCenter] addObserverForName:kIAPDelegateChecked object:nil queue:nil usingBlock:^(NSNotification * _Nonnull note) {
                  NSLog(@"=====kIAPDelegateChecked完成校验工作======");
                  result(newProductsArray);
              }];
              
              //检查一下订阅类型数据,对已有的receipt校验
              [[IAPDelegate shared] check];
          }
      }];
      
  }else if ([@"initRestore" isEqualToString:call.method]){
            
      // 注册恢复购买结果通知
      [[NSNotificationCenter defaultCenter] addObserverForName:kIAPDelegateRestored object:nil queue:nil usingBlock:^(NSNotification * _Nonnull note) {
          NSLog(@"恢复购买成功!");
          result(@(YES));
      }];
      
      //恢复购买
      [[IAPDelegate shared] restore];
      
  }else if ([@"payProductId" isEqualToString:call.method]){
      
      if ([IAPDelegate shared].hasSubscribe) {
          [HudManager showWord:@"目前已经购买过此订阅产品"];
          result(@(YES));
      }else{
          //购买商品
          NSLog(@"=====需要购买的商品ID:%@======",call.arguments);
          
          // 注册购买结果通知
          [[NSNotificationCenter defaultCenter] addObserverForName:kIAPDelegateFailed object:nil queue:nil usingBlock:^(NSNotification * _Nonnull note) {
              NSLog(@"payProductId====购买失败!");
              result(@(NO));
          }];

          [[NSNotificationCenter defaultCenter] addObserverForName:kIAPDelegateSuccess object:nil queue:nil usingBlock:^(NSNotification * _Nonnull note) {
              // restore UI interaction.
              NSLog(@"payProductId====购买成功!");
              result(@(YES));
          }];
          
          [[IAPDelegate shared] buy:call.arguments];
      }
      
  }else if ([@"hasSubscribe" isEqualToString:call.method]){
      if ([[IAPDelegate shared] hasSubscribe]) {
          NSLog(@"hasSubscribe:是订阅用户");
          result(@(YES));
      }else{
          NSLog(@"hasSubscribe:不是订阅用户");
          result(@(NO));
      }
  } else {
    result(FlutterMethodNotImplemented);
  }
}

@end
