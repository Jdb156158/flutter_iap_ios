//
//  IAPDelegate.m
//  flutter_iap_ios
//
//  Created by db J on 2020/12/24.
//

#import "IAPDelegate.h"
#import "HudManager.h"

@interface IAPDelegate () <IAPResultDelegate>
@property(nonatomic, strong) IAP *iap;
@property(nonatomic, strong) NSTimer *timeout;
@end
@implementation IAPDelegate

+ (instancetype)shared {
    static id _sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedInstance = [[self alloc] init];
    });
    
    return _sharedInstance;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.iap = [[IAP alloc] initWithValidator:[[LocalReceiptValidator alloc] init] delegate:self];
    }
    return self;
}

- (void)fetchAllProducts:(NSArray *)Products compelete:(void(^)(NSArray * newProductsArray))compelete{
    
    NSArray *unitDescArray = @[@"天",
                               @"周",
                               @"月",
                               @"年"];
    
    [self.iap getProductsInfo:[NSSet setWithArray:Products] success:^(NSArray<SKProduct *> *products, NSSet<NSString *> *invalidProductIdentifiers) {
        NSMutableArray *dicArray = [[NSMutableArray alloc] init];
        for (SKProduct *p in products) {
            
            NSString *subscribePriceStr = [[[IAPDelegate shared] iap] priceStringForProduct:p];
            NSString *numberOfTrialUnitsStr = @"";
            NSString *trialUnitStr = @"";
            if (@available(iOS 11.2, *)) {
                numberOfTrialUnitsStr = [@(p.introductoryPrice.subscriptionPeriod.numberOfUnits) stringValue];
            }
            if (@available(iOS 11.2, *)) {
                trialUnitStr = unitDescArray[p.introductoryPrice.subscriptionPeriod.unit];
            }
            NSDictionary *dict = @{@"productId":p.productIdentifier,@"price":p.price,@"priceLocale":subscribePriceStr,@"title":p.localizedTitle,@"desc":[p localizedDescription],@"numberOfTrialUnitsStr":numberOfTrialUnitsStr,@"trialUnitStr":trialUnitStr};
            [dicArray addObject:dict];
        }
        if (compelete) {
            compelete(dicArray);
        }
    } failed:^(NSError *error) {
        if (compelete) {
            compelete(nil);
        }
    }];
    
}

- (void)buy:(NSString *)productIdentifier {
    NSError *error = [self.iap makePaymentWithProductIdentifier:productIdentifier];
    if (error) {
        if (error.code == IAPErrorCanNotFindProduct) {
            [HudManager showWord:@"未找到商品, 请稍后重试"];
        } else if (error.code == IAPErrorCanNotPay) {
            [HudManager showWord:@"当前设备不允许购买"];
        } else if (error.code == IAPErrorJailbreakPayNotAllowed) {
            [HudManager showWord:@"越狱设备不允许购买"];
        } else {
            [HudManager showWord:[error localizedDescription]];
        }
    } else {
        //[HudManager showLoading];
        self.timeout = [NSTimer timerWithTimeInterval:60 target:self selector:@selector(timeoutFired:) userInfo:nil repeats:false];
    }
}

- (void)timeoutFired:(id)timer {
    [HudManager hideLoading];
}

- (void)restore {
    [HudManager showLoading];
    [self.iap restoreAllPurchasedProductExceptConsumable];
}

- (void)check {
    [self.iap checkReceiptForAllPurchasedProductExceptConsumable];
}

- (IAPProductType)typeForProduct:(NSString *)productIdentifier {
    return IAPProductTypeAutoRenewSubscription;
}

- (void)paidSuccessWithProductIdentifier:(NSString *)productIdentifier transaction:(SKPaymentTransaction *)transaction {
    [self hideLoadingIfNeeded];
    
    /*
    SKProduct *product = [self.iap productForIdentifier:productIdentifier];
    if ([self typeForProduct:productIdentifier] == IAPProductTypeAutoRenewSubscription ) {
        [HudManager showWord:[NSString stringWithFormat:@"您已成功购买"]];
    } else {
        [HudManager showWord:[NSString stringWithFormat:@"购买成功! %@", product.localizedTitle]];
    }*/
    
    [self addProduct:productIdentifier];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kIAPDelegateSuccess object:nil userInfo:@{@"obj": productIdentifier}];
}

- (void)paidFailedWithProductIdentifier:(NSString *)productIdentifier transaction:(SKPaymentTransaction *)transaction error:(NSError *)error {
    [self hideLoadingIfNeeded];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kIAPDelegateFailed object:nil userInfo:@{@"obj": productIdentifier}];
}

- (void)restoredValidProductIdentifiers:(NSSet<NSString *> *)productIdentifiers error:(NSError *)error {
    [self hideLoadingIfNeeded];
    
    if (error) {
        if (error.code == IAPErrorCanNotFindReceipt) {
            [HudManager showWord:@"恢复失败, 请稍后重试"];
        }
        
        [[NSNotificationCenter defaultCenter] postNotificationName:kIAPDelegateRestoredFailed object:nil userInfo:@{@"error": error}];
    }
    // 成功过后要对所有商品进行保存， 无论是否为空
    else {
        if (productIdentifiers.count > 0) {
            [HudManager showWord:@"恢复成功!"];
            [[NSNotificationCenter defaultCenter] postNotificationName:kIAPDelegateRestored object:nil userInfo:@{@"obj": productIdentifiers}];
            [self saveAllProducts:productIdentifiers];
        } else {
            [HudManager showWord:@"没有可恢复的商品"];
        }
    }
}

- (void)checkedValidProductIdentifiers:(NSSet<NSString *> *)productIdentifiers error:(NSError *)error {
    [self hideLoadingIfNeeded];
    
    if (error) {
        [[NSNotificationCenter defaultCenter] postNotificationName:kIAPDelegateChecked object:nil userInfo:@{@"error": error}];
    }
    // 成功过后要对所有商品进行保存， 无论是否为空
    else {
        
        [self saveAllProducts:productIdentifiers];
        
        [[NSNotificationCenter defaultCenter] postNotificationName:kIAPDelegateChecked object:nil userInfo:@{@"obj": productIdentifiers}];
        
    }
}

- (void)hideLoadingIfNeeded {
    
    [self.timeout invalidate];
    self.timeout = nil;
    
    [HudManager hideLoading];
}

- (NSSet *)allProductsInKeychain {
    NSString *allProducts = [[UICKeyChainStore keyChainStoreWithService:KeyChainIAPService] stringForKey:KeyChainAllProductKey];
    if (allProducts.length > 0) {
        NSArray *array = [allProducts componentsSeparatedByString:@"----"];
        NSSet *set = [NSSet setWithArray:array];
        return set;
    } else {
        return [NSSet set];
    }
}

- (void)saveAllProducts:(NSSet *)productIdentifiers {
    
    [[UICKeyChainStore keyChainStoreWithService:KeyChainIAPService] setString:[[productIdentifiers allObjects] componentsJoinedByString:@"----"] forKey:KeyChainAllProductKey];
    
    NSLog(@"saveAllProducts=======productIdentifiers:%@",productIdentifiers);
    
    if (productIdentifiers.count>0) {
        [USERDEFAULTS setBool:true forKey:SUBSCIBE_SUCCESS];
    } else {
        [USERDEFAULTS setBool:false forKey:SUBSCIBE_SUCCESS];
    }
    
    [USERDEFAULTS synchronize];
}

- (void)addProduct:(NSString *)product {
    NSMutableSet *set = [NSMutableSet setWithSet:[self allProductsInKeychain]];
    [set addObject:product];
    [self saveAllProducts:set];
}

- (BOOL)hasSubscribe {
    return [[NSUserDefaults standardUserDefaults] boolForKey:SUBSCIBE_SUCCESS];
}

@end
