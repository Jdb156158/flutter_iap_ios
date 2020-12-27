//
//  IAPDelegate.h
//  flutter_iap_ios
//
//  Created by db J on 2020/12/24.
//

#import <Foundation/Foundation.h>
#import <IAP/IAP.h>
#import <BlocksKit/BlocksKit.h>
#import <IAP/LocalReceiptValidator.h>
#import <UICKeyChainStore/UICKeyChainStore.h>

NS_ASSUME_NONNULL_BEGIN

#define USERDEFAULTS [NSUserDefaults standardUserDefaults]

#define kIAPDelegateSuccess     @"kIAPDelegateSuccess"
#define kIAPDelegateFailed      @"kIAPDelegateFailed"
#define kIAPDelegateRestored    @"kIAPDelegateRestored"
#define kIAPDelegateRestoredFailed    @"kIAPDelegateRestoredFailed"
#define kIAPDelegateChecked     @"kIAPDelegateChecked"

#define kObjKey                 @"obj"
#define kErrorKey               @"error"

#define KeyChainIAPService      @"IAPService"
#define KeyChainAllProductKey   @"KeyChainAllProductKey"

#define SUBSCIBE_SUCCESS @"subscibe_success"
#define SUBSCIBE_SUCCESS_NOTIFY @"subscibe_success_notify"

@interface IAPDelegate : NSObject <IAPResultDelegate>

+ (instancetype)shared;

// 通过商品ID获取产品的相关信息
- (void)fetchAllProducts:(NSArray *)Products compelete:(void(^)(NSArray * newProductsArray))compelete;

// 购买
- (void)buy:(NSString *)productIdentifier;

// 恢复
- (void)restore;

// check
- (void)check;

// keychain的所有商品
- (NSSet *)allProductsInKeychain;

- (BOOL)hasSubscribe;

@end

NS_ASSUME_NONNULL_END
