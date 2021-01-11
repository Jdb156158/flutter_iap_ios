#import "FlutterIapIosPlugin.h"
#import <NOVIAP/NOVAIAP.h>
#import <NOVIAP/NOVAIAPLocalReceiptValidator.h>
#import <NOVIAP/NOVAIAPUserDefaultProductStore.h>


@interface FlutterIapIosPlugin ()<NOVAIAPDelegate>{
}

@property(nonatomic, strong) NOVAIAPLocalReceiptValidator *validator;
@property(nonatomic, strong) NOVAIAPUserDefaultProductStore *store;

@property(nonatomic, strong) NSArray *allProductArray;//所有的商品ID
@property(nonatomic, strong) NSArray *autoRenewSubscriptionArray;//自动续期订阅
@property(nonatomic, strong) NSArray *foreverArray;//非消耗型（永久）

@property(nonatomic, strong) FlutterResult initProductsResult;//初始化商品信息成功
@property(nonatomic, strong) FlutterResult initRestoreResult;//恢复购买结果
@property(nonatomic, strong) FlutterResult payProductIdResult;//购买商品结果

@property(nonatomic, assign) bool isPayLoding;//是否正在购买操作
@end

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
    
    // 注册校验结果通知
    [[NSNotificationCenter defaultCenter] addObserverForName:kNOVAIAPValidateReceiptSuccessNotification object:nil queue:nil usingBlock:^(NSNotification * _Nonnull note) {
      // get valid product and refresh UI
        NSLog(@"=====相关操作后的校验完成=====");
    }];

    [[NSNotificationCenter defaultCenter] addObserverForName:kNOVAIAPValidateReceiptFailedNotification object:nil queue:nil usingBlock:^(NSNotification * _Nonnull note) {
      // get valid product and refresh UI
        NSLog(@"=====相关操作后的校验失败=====");
    }];

    
    //拉取商品信息成功通知
    [[NSNotificationCenter defaultCenter] addObserverForName:kNOVAIAPFetchProductSuccessNotification object:nil queue:nil usingBlock:^(NSNotification * _Nonnull note) {
        
        NSArray *unitDescArray = @[@"天",
                                   @"周",
                                   @"月",
                                   @"年"];
        NSMutableArray *dicArray = [[NSMutableArray alloc] init];
        
        for (SKProduct *p in [NOVAIAP shared].products) {
            
            //NSLog(@"[商品ID：%@,商品标题：%@,商品描述：%@,商品价格：%@]",[p productIdentifier],[p localizedTitle],[p localizedDescription],[p price]);
            if (p!=nil && ![p isEqual:[NSNull null]]) {
                NSString *subscribePriceStr = [self priceStringForProduct:p];
                NSString *numberOfTrialUnitsStr = @"";
                NSString *trialUnitStr = @"";
                if (@available(iOS 11.2, *)) {
                    numberOfTrialUnitsStr = [@(p.introductoryPrice.subscriptionPeriod.numberOfUnits) stringValue];
                    trialUnitStr = unitDescArray[p.introductoryPrice.subscriptionPeriod.unit];
                }
                NSDictionary *dict = @{@"productId":[self safeString:p.productIdentifier],@"price":p.price,@"priceLocale":[self safeString:subscribePriceStr],@"title":[self safeString:p.localizedTitle],@"desc":[self safeString:[p localizedDescription]],@"numberOfTrialUnitsStr":[self safeString:numberOfTrialUnitsStr],@"trialUnitStr":[self safeString:trialUnitStr]};
                [dicArray addObject:dict];
            }
        }
        
        if (self.initProductsResult) {
            self.initProductsResult(dicArray);
        }
                
    }];
    //拉取商品信息失败通知
    [[NSNotificationCenter defaultCenter] addObserverForName:kNOVAIAPFetchProductFailedNotification object:nil queue:nil usingBlock:^(NSNotification * _Nonnull note) {
        NSMutableArray *dicArray = [[NSMutableArray alloc] init];
        if (self.initProductsResult) {
            self.initProductsResult(dicArray);
        }
    }];
    
    //恢复购买成功通知
    [[NSNotificationCenter defaultCenter] addObserverForName:kNOVAIAPRestoreSuccessNotification object:nil queue:nil usingBlock:^(NSNotification * _Nonnull note) {
        NSLog(@"====恢复购买操作完成====");
        
        __block bool ishasSubscribe = NO;
        __block bool ishasForever= NO;
        [self.autoRenewSubscriptionArray enumerateObjectsUsingBlock:^(NSString *obj, NSUInteger idx, BOOL *stop) {
            if ([self.store isActivatedForRenewSubscriptionProduct:obj]) {
                ishasSubscribe = YES;
            }
        }];
        
        [self.foreverArray enumerateObjectsUsingBlock:^(NSString *obj, NSUInteger idx, BOOL *stop) {
            if ([self.store isActivatedForForeverProduct:obj]) {
                ishasForever = YES;
            }
        }];
        
        if (ishasSubscribe || ishasForever) {
            if (self.initRestoreResult) {
                self.initRestoreResult(@(YES));
            }
        }else{
            if (self.initRestoreResult) {
                self.initRestoreResult(@(NO));
            }
        }
        
        [self cleanAndRedeleiverProducts];
        
    }];
    //恢复购买失败通知
    [[NSNotificationCenter defaultCenter] addObserverForName:kNOVAIAPRestoreFailedNotification object:nil queue:nil usingBlock:^(NSNotification * _Nonnull note) {
        NSLog(@"====恢复购买操作失败====");
        if (self.initRestoreResult) {
            self.initRestoreResult(@(NO));
        }
    }];
    
    // 注册购买结果通知
    [[NSNotificationCenter defaultCenter] addObserverForName:kNOVAIAPPaidFailedNotification object:nil queue:nil usingBlock:^(NSNotification * _Nonnull note) {
      // restore UI interaction.
      NSLog(@"购买失败! %@", [note object]);
        if (self.payProductIdResult) {
            self.payProductIdResult(@(NO));
        }
    }];

    [[NSNotificationCenter defaultCenter] addObserverForName:kNOVAIAPPaidSuccessNotification object:nil queue:nil usingBlock:^(NSNotification * _Nonnull note) {
      // restore UI interaction.
      NSLog(@"payProductIdResult:购买成功!");
        if (self.payProductIdResult) {
            self.payProductIdResult(@(YES));
        }
    }];

}

- (void)setNoviap{
    [NOVAIAP shared].delegate = self;
    self.validator = [[NOVAIAPLocalReceiptValidator alloc] init];
    self.store = [NOVAIAPUserDefaultProductStore shared];

    [NOVAIAP shared].validator = self.validator;
    [NOVAIAP shared].store = self.store;
    
    //主动拉取商品信息
    [[NOVAIAP shared] fetchProductsInfo:self.allProductArray];
    
    // 获取当前沙盒内是否有票据数据
    if ([[NOVAIAP shared] bundleReceiptData]) {
        //1. 先清除永久性商品和订阅类商品
        if (self.autoRenewSubscriptionArray.count>0) {
            [self.store deactiveAutoRenewSubscriptionProducts:self.autoRenewSubscriptionArray];//订阅类商品
        }else if(self.foreverArray.count>0){
            [self.store deactiveForeverProducts:self.foreverArray];//非消耗型永久类商品
        }

        //2. 重新验证票据并添加商品
        [[NOVAIAP shared] validateReceiptDataAndDeleiverProductsForeUpdate:false];
    }
    
    
}

// 实现代理
- (NOVAIAPProductType)typeForProduct:(NSString *)productIdentifier {
    
    if ([self.autoRenewSubscriptionArray containsObject:productIdentifier]) {
        //自动续期可订阅
        return NOVAIAPProductAutoRenewSubscription;
    } else if ([self.foreverArray containsObject:productIdentifier]){
        //非消耗型（永久型）
        return NOVAIAPProductForever;
    } else {
        //可消耗型
        return NOVAIAPProductConsumable;
    }
}

- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
    
  if ([@"getPlatformVersion" isEqualToString:call.method]) {
      
    result([@"iOS " stringByAppendingString:[[UIDevice currentDevice] systemVersion]]);
      
  }else if ([@"initProducts" isEqualToString:call.method]){
      
      self.initProductsResult = result;
      
      NSLog(@"=====收到flutter传来的initProducts信息:%@======",call.arguments);
      
      if ([call.arguments isKindOfClass:[NSArray class]]) {
          self.allProductArray = call.arguments;
          [self setNoviap];
      }else{
          NSLog(@"======应用未正确传入数据，不可初始化======");
          NSMutableArray *dicArray = [[NSMutableArray alloc] init];
          result(dicArray);
      }
      
  }else if ([@"initAutoRenewSubscriptionProducts" isEqualToString:call.method]){
      
      NSLog(@"=====initAutoRenewSubscriptionProducts:%@======",call.arguments);
      
      if ([call.arguments isKindOfClass:[NSArray class]]) {
          self.autoRenewSubscriptionArray = call.arguments;
          result(@(YES));
      }else{
          NSLog(@"======应用未正确传入数据，不可初始化======");
          result(@(NO));
      }
      
  } else if ([@"initForeverProducts" isEqualToString:call.method]){
      
      NSLog(@"=====initForeverProducts:%@======",call.arguments);
      
      if ([call.arguments isKindOfClass:[NSArray class]]) {
          self.foreverArray = call.arguments;
          result(@(YES));
      }else{
          NSLog(@"======应用未正确传入数据，不可初始化======");
          result(@(NO));
      }
      
  }else if ([@"initRestore" isEqualToString:call.method]){
      
      self.initRestoreResult = result;
      //恢复购买
      [[NOVAIAP shared] restore];
      
  }else if ([@"payProductId" isEqualToString:call.method]){
      
      self.payProductIdResult = result;
      
      if ([call.arguments isKindOfClass:[NSString class]]) {
          [[NOVAIAP shared] buyProduct:call.arguments];
      }else{
          NSLog(@"======应用未正确传入数据，不可初始化======");
          result(@(NO));
      }
      
  }else if ([@"hasSubscribe" isEqualToString:call.method]){
      
      NSLog(@"====hasSubscribe判断====");
      
      if (self.autoRenewSubscriptionArray.count>0 || self.foreverArray.count>0) {
          __block bool ishasSubscribe = NO;
          __block bool ishasForever= NO;
          [self.autoRenewSubscriptionArray enumerateObjectsUsingBlock:^(NSString *obj, NSUInteger idx, BOOL *stop) {
              if ([self.store isActivatedForRenewSubscriptionProduct:obj]) {
                  ishasSubscribe = YES;
              }
          }];
          
          [self.foreverArray enumerateObjectsUsingBlock:^(NSString *obj, NSUInteger idx, BOOL *stop) {
              if ([self.store isActivatedForForeverProduct:obj]) {
                  ishasForever = YES;
              }
          }];
          
          if (ishasSubscribe || ishasForever) {
              NSLog(@"当前自动续期订阅产品在有效期内");
              result(@(YES));
          }else{
              NSLog(@"hasSubscribe：当前无自动续期订阅产品");
              result(@(NO));
          }
          
      }else {
          NSLog(@"未有商品信息列表,当前无自动续期订阅产品");
          result(@(NO));
      }
      

  }else if ([@"hasForever" isEqualToString:call.method]){
      
      NSLog(@"====hasForever判断====");
      
      if (self.foreverArray.count>0) {
          __block bool ishasForever= NO;
          [self.foreverArray enumerateObjectsUsingBlock:^(NSString *obj, NSUInteger idx, BOOL *stop) {
              if ([self.store isActivatedForForeverProduct:obj]) {
                  ishasForever = YES;
              }
          }];
          
          if (ishasForever) {
              result(@(YES));
              NSLog(@"购买过久类商品");
          }else{
              NSLog(@"未购买过非消耗永久类商品");
              result(@(NO));
          }
      }else{
          NSLog(@"未购买过非消耗永久类商品");
          result(@(NO));
      }
      
      
  } else {
    result(FlutterMethodNotImplemented);
  }
}

- (void)cleanAndRedeleiverProducts {
    //1. 先清除永久性商品和订阅类商品
    if (self.autoRenewSubscriptionArray.count>0) {
        [self.store deactiveAutoRenewSubscriptionProducts:self.autoRenewSubscriptionArray];//订阅类商品
    }else if(self.foreverArray.count>0){
        [self.store deactiveForeverProducts:self.foreverArray];//非消耗型永久类商品
    }
    
    //2. 重新验证票据并添加商品, 强制刷新票据 when receipt is not exsit.
    [[NOVAIAP shared] validateReceiptDataAndDeleiverProductsForeUpdate:true];
}


- (NSString *)priceStringForProduct:(SKProduct *)product {
    NSNumberFormatter *numberFormatter = [[NSNumberFormatter alloc] init];
    [numberFormatter setFormatterBehavior:NSNumberFormatterBehavior10_4];
    [numberFormatter setNumberStyle:NSNumberFormatterCurrencyStyle];
    [numberFormatter setLocale:product.priceLocale];
    NSString *formattedPrice = [numberFormatter stringFromNumber:product.price];
    return formattedPrice;
}

- (NSString *)safeString:(NSString *)str{
    if (str == nil || str.length == 0) {
        return  @"";
    }else{
        return  str;
    }
}

@end
