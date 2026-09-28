//
//  AuxHideDevice.xm — 隐藏设备（对应 AFNHideDeviceStore/SettingController）
//
//  配置 key：K_HIDE_MULTILogin（隐藏"多设备登录"入口）
//  微信侧目标（AFN 二进制确认引用的类）：
//    WCAccountLoginUsersViewController（账号-登录设备页）
//    WCDeviceStepObject / ProvisionsAllDevices / ProvisionedDevices / UploadDeviceStepReq
//
//  行为：隐藏「多设备登录」开关/入口行
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#include <substrate.h>
#import "common/AuxConfig.h"

@interface AuxHideDevice : NSObject
+ (void)install;
+ (UIWindow *)getActiveWindow;
+ (void)applyToWindow:(UIWindow *)win;
@end

@implementation AuxHideDevice

+ (UIWindow *)getActiveWindow {
    UIWindow *win = nil;
    for (UIWindowScene *scene in [[UIApplication sharedApplication] connectedScenes]) {
        if(scene.activationState == UISceneActivationStateForegroundActive){
            win = scene.windows.firstObject;
            break;
        }
    }
    return win;
}

+ (void)install {
    NSLog(@"[AuxSix] hideDevice hooks installed");
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onConfigChanged)
                                                name:AuxConfigDidChangeNotification object:nil];
}

+ (void)onConfigChanged {
    // 只在开关 + 子项开时才扫，且限深（防闪退）
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
       if (![[AuxConfig shared] hideDeviceEnabled]) return;
       if (![[AuxConfig shared] boolForKey:K_HIDE_MULTILogin hasDefault:NO]) return;
       UIWindow *win = [self getActiveWindow];
       [self applyToWindow:win];
   });
}

// 按标题隐藏目标行（稳妥：不依赖微信内部数据模型）
+ (void)applyToWindow:(UIWindow *)win {
    if (![[AuxConfig shared] hideDeviceEnabled]) return;
    if (![[AuxConfig shared] boolForKey:K_HIDE_MULTILogin hasDefault:NO]) return;
    if(!win) return;
    [self hideRowsIn:win matchingTitle:@"多设备登录"];
}

+ (void)hideRowsIn:(UIView *)root matchingTitle:(NSString *)title {
    [self hideRowsIn:root matchingTitle:title maxDepth:15];
}
+ (void)hideRowsIn:(UIView *)root matchingTitle:(NSString *)title maxDepth:(int)d {
    if (d <= 0 || !root) return;
    for (UIView *v in root.subviews) {
        if ([v isKindOfClass:[UITableViewCell class]]) {
            UITableViewCell *c = (UITableViewCell *)v;
            if ([c.textLabel.text containsString:title]) {
                c.hidden = YES;
                NSLog(@"[AuxSix][HideDevice] hid row: %@", c.textLabel.text);
            }
        }
        [self hideRowsIn:v matchingTitle:title maxDepth:d-1];
    }
}

@end

#pragma mark - 微信侧 hook（入口级隐藏）

%hook WCAccountLoginUsersViewController
- (void)viewWillAppear:(BOOL)animated {
    %orig;
    UIWindow *win = [AuxHideDevice getActiveWindow];
    [AuxHideDevice applyToWindow:win];
}
%end

// TODO[微信内部]：设备清单数据层
//   ProvisionsAllDevices / WCDeviceStepObject 的取值方法未确认；
//   若要"设备页整页隐藏"，再 hook 页面路由。目前按标题隐藏行已覆盖"多设备登录"入口。
