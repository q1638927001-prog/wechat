//
//  AuxRoundCorner.xm — 列表圆角（对应 AFNListRoundCornerEngine + AFNCellRoundCornerSettingEngine）
//
//  配置 key：
//    K_ROUND_CORNER       总开关
//    K_ROUND_SEARCHBOX    搜索框圆角
//    K_ROUND_INPUTTEXT    输入框圆角
//    K_ROUND_MOREDISC     "更多发现"列表圆角
//  微信侧目标（从 AFN 二进制确认存在的类）：
//    WCSearchBar / WCSearchTextView / WCSearchController（搜索框/输入框）
//    CMessageNodeCellView（消息 cell）
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#include <substrate.h>
#import "common/AuxConfig.h"

@interface AuxRoundCorner : NSObject
+ (void)install;
+ (void)applyIfNeededToView:(UIView *)v;
@end

@implementation AuxRoundCorner

+ (void)install {
    NSLog(@"[AuxSix] roundCorner hooks installed");
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onConfigChanged)
                                                name:AuxConfigDidChangeNotification object:nil];
}

+ (void)onConfigChanged {
    // 只在开关相关项开启时才扫，且限深（防闪退/卡死）
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        if ([[AuxConfig shared] roundCornerEnabled]) [self applyToKeyWindow];
    });
}

+ (CGFloat)radius { return 12.0; }

+ (void)applyIfNeededToView:(UIView *)v {
    if (!v) return;
    v.layer.cornerRadius = [self radius];
    v.layer.masksToBounds = YES;
}

+ (void)applyToKeyWindow {
    if (![[AuxConfig shared] roundCornerEnabled]) return;
    
    UIWindow *win = nil;
    for (UIWindowScene *scene in [[UIApplication sharedApplication] connectedScenes]) {
        if(scene.activationState == UISceneActivationStateForegroundActive){
            win = scene.windows.firstObject;
            break;
        }
    }
    if(!win) return;
    [self scan:win];
}

// 限深扫描：只沿"搜索/输入"类子树往下，最大 12 层，避免遍历整棵微信 view 树
// （原无深度限制的全树递归是"开关打开闪退/卡死"的高危点）。
+ (void)scan:(UIView *)root { [self scan:root maxDepth:12]; }

+ (void)scan:(UIView *)root maxDepth:(int)d {
    if (d <= 0 || !root) return;
    AuxConfig *c = [AuxConfig shared];
    NSString *cls = NSStringFromClass([root class]);
    BOOL isSearchBar = [cls containsString:@"SearchBar"] ||
                       [cls containsString:@"SearchController"] ||
                       [cls containsString:@"SearchTextView"];
    if (isSearchBar && [c boolForKey:K_ROUND_SEARCHBOX hasDefault:NO]) {
        [self applyIfNeededToView:root];
    }
    if ([cls containsString:@"Search"] || [cls containsString:@"Input"]) {
        for (UIView *sub in root.subviews) [self scan:sub maxDepth:d-1];
    }
}

@end

#pragma mark - 微信侧 hook（cell 级圆角）

%hook CMessageNodeCellView
- (void)layoutSubviews {
    %orig;
    AuxConfig *c = [AuxConfig shared];
    if (c.roundCornerEnabled && [c boolForKey:K_ROUND_MOREDISC hasDefault:NO]) {
        ((UIView *)self).layer.cornerRadius = 12.0;
        ((UIView *)self).layer.masksToBounds = YES;
    }
}
%end

%hook WCSearchBar
- (void)layoutSubviews {
    %orig;
    if ([[AuxConfig shared] roundCornerEnabled] &&
         [[AuxConfig shared] boolForKey:K_ROUND_SEARCHBOX hasDefault:NO]) {
        ((UIView *)self).layer.cornerRadius = 12.0;
        ((UIView *)self).layer.masksToBounds = YES;
    }
}
%end
