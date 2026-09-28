//
//  Tweak.xm — AuxSix 入口（6 功能，设置走微信"第三方插件"页）
//  参考 WechatEnhance 开源版：#import WCPluginsHeader.h 后直接调
//  registerControllerWithTitle:version:controller:（第3参 = 类名字符串）。
//

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "Headers/WCPluginsHeader.h"

#import "common/AuxConfig.h"
#import "common/AuxSettingController.h"

// 模块前向声明（实现在 modules/*.xm，这里只声明供本文件调用）
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
// ⚠️ 第3参数是"类名字符串"（微信内部 NSClassFromString 实例化），不是 Class。
static void auxRegisterInWeChatPlugins(void) {
    static BOOL tried = NO;
    if (tried) return;
    if (!NSClassFromString(@"WCPluginsMgr")) {
        NSLog(@"[AuxSix] WCPluginsMgr not found, skip register");
        return;
    }
    if (!NSClassFromString(@"AuxSettingController")) {
        NSLog(@"[AuxSix] AuxSettingController class missing");
        return;
    }
    @try {
        WCPluginsMgr *mgr = [WCPluginsMgr sharedInstance];
        if (!mgr) { NSLog(@"[AuxSix] WCPluginsMgr.sharedInstance nil"); return; }
        [mgr registerControllerWithTitle:@"AuxSix"
                                  version:@"v1.0.0"
                               controller:@"AuxSettingController"];
        tried = YES;
        NSLog(@"[AuxSix] registered in WCPluginsMgr (AuxSix v1.0.0 / AuxSettingController)");
    } @catch (NSException *e) {
        NSLog(@"[AuxSix] register exception: %@", e.reason);
    }
}

// 参考 WechatEnhance：hook 微信"我"页 MinimizeViewController viewDidLoad 注册（最稳）。
// 双通道：didBecomeActive 兜底 + 10s/40s 主线程守护，auxInstalled 幂等。
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

// 参考 WechatEnhance：微信"我"页(viewDidLoad)注册设置入口
%hook MinimizeViewController
- (void)viewDidLoad {
    %orig;
    dispatch_async(dispatch_get_main_queue(), ^{
        auxInstallAll();
        auxRegisterInWeChatPlugins();
    });
}
%end
