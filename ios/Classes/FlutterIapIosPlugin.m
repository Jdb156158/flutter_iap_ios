#import "FlutterIapIosPlugin.h"
#import "IAPDelegate.h"

@implementation FlutterIapIosPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  FlutterMethodChannel* channel = [FlutterMethodChannel
      methodChannelWithName:@"flutter_iap_ios"
            binaryMessenger:[registrar messenger]];
  FlutterIapIosPlugin* instance = [[FlutterIapIosPlugin alloc] init];
  [registrar addMethodCallDelegate:instance channel:channel];
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
              result(newProductsArray);
          }
      }];
  } else {
    result(FlutterMethodNotImplemented);
  }
}

@end
