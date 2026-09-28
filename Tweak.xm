
//
//  Tweak.xm — AuxSix 入口（6 功能，设置走微信"第三方插件"页）
//  WCPluginsMgr 是微信内部类，编译期不存在 → 全用 NSClassFromString + NSInvocation
//  动态调用，不 #import 微信头、不直接引用类符号，避免链接 undefined。
//

#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#import "common/AuxConfig.h"
#import "common/AuxSettingController.h"

// 模块前向声明（实现在 modules/*.xm）
@interface AuxPreventRevoke : NSObject
+ (void)install;
@end
@interface AuxRedEnvelop : NSObject
+ (void)install;
@end
@interface AuxAdBlock : NSObject
+ (void)install;
@end
@interface AuxRoundCorner : NSObject
+ (void)install;
@end
@interface AuxHideDevice : NSObject
+ (void)install;
@end
@interface AuxTTS : NSObject
+ (void)install;
@end

static BOOL auxInstalled = NO;

static void auxInstallAll(void) {
    if (auxInstalled) return;
    auxInstalled = YES;

    NSLog(@"[AuxSix] installing...");
    [AuxPreventRevoke install];
    [AuxRedEnvelop install];
    [AuxAdBlock install];
    [AuxRoundCorner install];
    [AuxHideDevice install];
    [AuxTTS install];
    NSLog(@"[AuxSix] done. config=%@", [[AuxConfig shared] debugSummary]);
}

// 注册到微信"第三方插件"设置页。
// 第3参数是"类名字符串"（微信内部 NSClassFromString 实例化），不是 Class。
// WCPluginsMgr 编译期不存在 → NSClassFromString + NSInvocation 动态调。
static void auxRegisterInWeChatPlugins(void) {
    static BOOL tried = NO;
    if (tried) return;

    Class host = NSClassFromString(@"WCPluginsMgr");
    if (!host) { NSLog(@"[AuxSix] WCPluginsMgr not found, skip register"); return; }

    SEL selShared = NSSelectorFromString(@"sharedInstance");
    if (![host respondsToSelector:selShared]) {
        NSLog(@"[AuxSix] WCPluginsMgr has no sharedInstance");
        return;
    }
    NSMethodSignature *s1 = [host methodSignatureForSelector:selShared];
    NSInvocation *inv1 = [NSInvocation invocationWithMethodSignature:s1];
    [inv1 setTarget:host];
    [inv1 setSelector:selShared];
    [inv1 invoke];
    id mgr = nil;
    [inv1 getReturnValue:&mgr];
    if (!mgr) { NSLog(@"[AuxSix] WCPluginsMgr.sharedInstance nil"); return; }

    if (!NSClassFromString(@"AuxSettingController")) {
        NSLog(@"[AuxSix] AuxSettingController class missing");
        return;
    }

    SEL selReg = NSSelectorFromString(@"registerControllerWithTitle:version:controller:");
    if (![mgr respondsToSelector:selReg]) {
        NSLog(@"[AuxSix] no registerControllerWithTitle:version:controller:, skip");
        return;
    }
    NSMethodSignature *s2 = [mgr methodSignatureForSelector:selReg];
    NSInvocation *inv2 = [NSInvocation invocationWithMethodSignature:s2];
    [inv2 setTarget:mgr];
    [inv2 setSelector:selReg];
    NSString *title   = @"AuxSix";
    NSString *version = @"v1.0.0";
    NSString *ctrlCls = @"AuxSettingController";   // 类名字符串
    [inv2 setArgument:&title   atIndex:2];
    [inv2 setArgument:&version atIndex:3];
    [inv2 setArgument:&ctrlCls atIndex:4];
    [inv2 invoke];
    tried = YES;
    NSLog(@"[AuxSix] registered in WCPluginsMgr (AuxSix v1.0.0 / AuxSettingController)");
}

__attribute__((constructor))
static void auxConstructor(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
                           auxInstallAll();
                           auxRegisterInWeChatPlugins();
                       });
    });

    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification
        object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *n) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{
                               auxInstallAll();
                               auxRegisterInWeChatPlugins();
                           });
        }];
}

static void auxGuardFire(void) {
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{ auxGuardFire(); });
        return;
    }
    NSLog(@"[AuxSix] guard: main thread, app state=%ld",
          (long)([UIApplication sharedApplication].applicationState));
}
__attribute__((constructor(101)))
static void auxConstructorGuard(void) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 10 * NSEC_PER_SEC),
                   dispatch_get_main_queue(), ^{
        auxGuardFire();
        auxInstallAll();
        auxRegisterInWeChatPlugins();
    });
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 40 * NSEC_PER_SEC),
                   dispatch_get_main_queue(), ^{
        auxGuardFire();
        auxInstallAll();
        auxRegisterInWeChatPlugins();
    });
}
