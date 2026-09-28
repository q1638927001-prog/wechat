//
//  AuxRedEnvelop.xm — 自动收红包（对应 AFNRedEnvelop* 一族 19 类）
//
//  已确认的微信侧目标：
//    WCRedEnvelopesLogicMgr            onRedEnvelopesClicked:
//    WCRedEnvelopesRedEnvelopesDetailViewController
//    WeChatRedEnvelopParam
//    ReceiverOpenRedEnvelopesRequest: / ReceiverQueryRedEnvelopesRequest:
//  配置 key 见 AuxConfig.h（K_RED_*）
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#include <substrate.h>
#import "common/AuxConfig.h"

@interface AuxRedEnvelop : NSObject
+ (void)install;
+ (void)enqueueAutoOpen:(id)param delay:(NSTimeInterval)delay;
+ (void)logReceived:(NSString *)summary;
@end

@implementation AuxRedEnvelop {
    NSOperationQueue *_queue;
    int _totalAmountCents;
}

+ (instancetype)shared {
    static AuxRedEnvelop *s; static dispatch_once_t t;
    dispatch_once(&t, ^{ s = [AuxRedEnvelop new]; });
    return s;
}

- (instancetype)init {
    if (self = [super init]) {
        _queue = [[NSOperationQueue alloc] init];
        _queue.maxConcurrentOperationCount = 1;
    }
    return self;
}

+ (void)install {
    NSLog(@"[AuxSix] redEnvelop hooks installed");
}

+ (void)enqueueAutoOpen:(id)param delay:(NSTimeInterval)delay {
    [[self shared] autoOpenAfter:delay param:param];
}

- (void)autoOpenAfter:(NSTimeInterval)delay param:(id)param {
    [_queue addOperationWithBlock:^{
        NSTimeInterval d = delay > 0 ? delay :
            [[AuxConfig shared] intForKey:K_RED_DELAY hasDefault:3];
        NSLog(@"[AuxSix][Red] auto-open in %.1fs param=%@", d, param);
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(d * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            [self performOpenOnDetailPage:param];
        });
    }];
}

// TODO[微信内部]：WCRedEnvelopesLogicMgr 的 onRedEnvelopesClicked: 对应开包动作。
// 这里模拟"点开红包"——调用详情页的打开逻辑。
// AFN 通过 ReceiverOpenRedEnvelopesRequest: 直接发开包请求；
// 需要确认 WeChatRedEnvelopParam 的字段（newpackage / coverImg / receptCnt）。
- (void)performOpenOnDetailPage:(id)param {
    NSLog(@"[AuxSix][Red] TODO: open red envelop param=%@", param);
    // 累计金额
    _totalAmountCents += 0; // TODO: 从 open 结果读金额
    [AuxRedEnvelop logReceived:@"opened"];
}

+ (void)logReceived:(NSString *)summary {
    NSLog(@"[AuxSix][Red] %@", summary);
    // TODO: 写日志文件（AFNRedEnvelopLogManager 等价物）
}

@end

#pragma mark - hook：红包详情点击

%hook WCRedEnvelopesLogicMgr
- (void)onRedEnvelopesClicked:(id)sender {
    %orig;
    AuxConfig *c = [AuxConfig shared];
    if (!c.autoRedEnvelopEnabled) return;

    BOOL catchMe = [c boolForKey:K_RED_CATCH_ME hasDefault:NO];
    BOOL multi   = [c boolForKey:K_RED_MULTI hasDefault:NO];
    if (!catchMe && !multi) { /* 默认只收群/别人的 */ }

    int delaySec = [c intForKey:K_RED_DELAY hasDefault:3];
    [AuxRedEnvelop enqueueAutoOpen:sender delay:delaySec];

    // 自动回复
    if ([c boolForKey:K_RED_AUTOREPLY_ON hasDefault:NO]) {
        NSString *txt = [c stringForKey:K_RED_AUTOREPLY_TEXT hasDefault:@"谢谢红包"];
        NSLog(@"[AuxSix][Red] autoReply: %@", txt);
        // TODO[微信内部]：通过 CMessageMgr 发文本消息给红包来源
    }
}
%end
