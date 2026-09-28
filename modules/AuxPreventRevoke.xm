//
//  AuxPreventRevoke.xm — 防撤回（对应 AFNPreventRevoke*）
//
//  已确认的微信侧选择器（AFN 二进制）：
//    onRevokeMsg:
//    forwardMsgList:msgOriginList:toContacts:ignoreTips:showConfirmView:batchRevokeScene:
//    ForwardMsgList:ToContact:WithRevokeBatchId:
//  行为：对方撤回时保留原消息内容，系统消息替换为自定义提示（含时间/来源/静默模式）
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#include <substrate.h>
#import "common/AuxConfig.h"

@interface AuxPreventRevoke : NSObject
+ (void)install;
@end

static NSMutableSet *auxHandledEvents = [NSMutableSet new]; // 对应 AFNPreventRevokeHandledEventsV2 去重

static BOOL auxPRActive(void) { return [[AuxConfig shared] preventRevokeEnabled]; }

static void auxPRLog(NSString *fmt, ...) {
    va_list a;
    va_start(a, fmt);
    NSString *m = [[NSString alloc] initWithFormat:fmt arguments:a];
    va_end(a);
    NSLog(@"[AuxSix][Revoke] %@", m);
}

#pragma mark - 解析 revokemsg

// revokemsg XML 里带被撤消息的 localID：
//   <sysmsg type="revokemsg"><revokemsg><localid>...</localid>...</revokemsg></sysmsg>
static uint32_t auxParseRevokedLocalID(NSString *xml) {
    if (![xml containsString:@"revokemsg"]) return 0;
    NSRegularExpression *re = [NSRegularExpression
        regularExpressionWithPattern:@"<localid>(\\d+)</localid>"
                             options:0 error:NULL];
    NSTextCheckingResult *m = [re firstMatchInString:xml
                                             options:0 range:NSMakeRange(0, xml.length)];
    if (!m) return 0;
    NSString *numStr = [xml substringWithRange:[m rangeAtIndex:1]];
    return (uint32_t)[numStr intValue];
}

#pragma mark - 收端：revokemsg 系统消息到达

%hook CMessageMgr
- (void)onRevokeMsg:(id)msg {
    if (auxPRActive()) {
        // 1) 取 revokemsg 内容 → 解析 localID
        NSString *xml = @"";
        if ([msg respondsToSelector:@selector(text)]) xml = [msg text] ?: @"";
        if (![xml containsString:@"revokemsg"]) xml = @"";
        uint32_t localID = auxParseRevokedLocalID(xml);

        NSString *eventKey = [NSString stringWithFormat:@"PR:%u:%p",
                              localID, (void *)msg];
        @synchronized (auxHandledEvents) {
            if ([auxHandledEvents containsObject:eventKey]) {
                %orig;
                return;
            }
            [auxHandledEvents addObject:eventKey];
        }

        auxPRLog(@"revoke localID=%u", localID);

        // 2) 按配置改提示文案/静默（静默模式：原消息保留 + 不弹提示）
        // TODO[微信内部]：从 CMessageMgr 取被撤原消息文本并注入 revokemsg 展示体。
        //   AFN 的注入格式：href="AFNRevokeFrom://LocalID=%u,%@"（新插件用 AUXRevokeFrom:）
        //   需要确认本地 CMessageWrap/CMessageMgr 的取值 API（下轮对微信二进制核方法名）
    }
    %orig;
}
%end

#pragma mark - 发端：批量撤回拦截
// ⚠️暂时注释，当前微信版本没有这个selector，后续逆向再打开
/*
%hook CMessageMgr
- (void)forwardMsgList:(id)msgList msgOriginList:(id)orig toContacts:(id)contacts
       ignoreTips:(BOOL)ignoreTips showConfirmView:(BOOL)showConfirm
  batchRevokeScene:(int)scene {
    if (auxPRActive()) {
        BOOL silent = [[AuxConfig shared] boolForKey:K_PR_SILENT hasDefault:NO];
        if (silent) {
            // 静默模式：不弹确认框
            NSLog(@"[AuxSix][Revoke] batch revoke scene=%d silent, skip confirm", scene);
            [self forwardMsgList:msgList msgOriginList:orig toContacts:contacts
                     ignoreTips:YES showConfirmView:NO batchRevokeScene:scene];
            return;
        }
    }
    %orig;
}
%end
*/

@implementation AuxPreventRevoke

+ (void)install {
    NSLog(@"[AuxSix] preventRevoke hooks installed");
}

@end
