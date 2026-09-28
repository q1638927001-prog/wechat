//
//  AuxAdBlock.xm — 广告净化 5 渠道（对应 AFNAdBlockerManager + AFNAdTools）
//
//  渠道：朋友圈(Timeline) / 搜索(Search) / 视频号-看一看(Channels) / 公众号(MP) / 小程序(MiniProgram)
//
//  已确认的微信侧目标：
//    Swift: _TtC6WeChat19MagicAdBrandService  createMagicAdBrandServiceScene:error:
//           _TtC6WeChat20MagicAdPublicService / 22MagicAdBrandServiceBiz
//           _TtC6WeChat28MagicSclBrandAdFlutterPlugin
//           _TtC6WeChat31MBJsEventOnFinderMediaAdPreload
//           _TtC6WeChat33MagicAdPublicServicePkgManagement
//    ObjC:  WCAdvertise / WCAdvertisePushService / WCAdvertiseStorage / WCAdvertiseDataHelper
//           WCAdvertiseStatMgr / WCAdCanvasLoadParams / WCAdDynamicCanvasPageInfo
//           WCAdFinderInfo / WCAdFormWebViewJSLogic / WCAdDB
//           WCFinderFeedFlowViewDataSource / WCFinderFeedNoAds
//  网络层 URL 黑名单（正则）：
//    advert_group|getadvert|getAdPreloadData|ad_posid|_ads_|/ads_|advertisement_
//  选择器：getAdPreloadData / getAdData / getAdvertiseInfoForItem: /
//          getFirstCanvasAdCard / getFirstCanvasAdCardInMaxGroup /
//          getFirstUnexposedCanvasAdCard / getInsertedAdCardListWithLimit:
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#include <substrate.h>
#import "common/AuxConfig.h"

@interface AuxAdBlock : NSObject
+ (void)install;
@end

@implementation AuxAdBlock

static __attribute__((unused)) BOOL auxAdChannelOn(NSString *k, int def) {
    return [[AuxConfig shared] boolForKey:k hasDefault:0];
}

+ (void)install {
    NSLog(@"[AuxSix] adBlock hooks installed");
}

// 网络层：空数据任务拦截（对应 AFNAdBlockEmptyDataTask）
static NSString *const AUX_AD_URL_PATTERNS =
    @"advert_group|getadvert|getAdPreloadData|ad_posid|_ads_|/ads_|advertisement_";

static BOOL auxIsAdURL(NSURL *url) {
    AuxConfig *c = [AuxConfig shared];
    if (!c.adBlockEnabled) return NO;
    if (![c boolForKey:K_ADBLOCK_SEARCH hasDefault:NO]
        && ![c boolForKey:K_ADBLOCK_MP hasDefault:NO]
        && ![c boolForKey:K_ADBLOCK_CHANNELS hasDefault:NO]
        && ![c boolForKey:K_ADBLOCK_MINIPROG hasDefault:NO]
        && ![c boolForKey:K_ADBLOCK_TIMELINE hasDefault:NO]) return NO;
    NSString *s = [url absoluteString];
    NSRegularExpression *re = [NSRegularExpression
        regularExpressionWithPattern:AUX_AD_URL_PATTERNS options:0 error:NULL];
    return [re firstMatchInString:s options:0 range:NSMakeRange(0, s.length)] != nil;
}

@end

#pragma mark - 网络拦截

%hook NSURLSession
- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)req {
    if (auxIsAdURL(req.URL)) {
        NSLog(@"[AuxSix][Ad] block %@", req.URL.absoluteString);
        if ([[AuxConfig shared] boolForKey:K_ADBLOCK_DIAG hasDefault:NO])
            NSLog(@"[AuxSix][Ad][diag] url=%@ host=%@", req.URL.absoluteString, req.URL.host);
        // 返回空任务，不发广告请求
        return nil;
    }
    return %orig;
}
%end

#pragma mark - 广告数据层

%hook WCAdvertise
// 以下选择器均从 AFN 二进制确认存在；归属类（是 WCAdvertise 还是其 DataHelper）需对微信二进制复核
- (id)getAdPreloadData {
    if ([[AuxConfig shared] adBlockEnabled]) {
        NSLog(@"[AuxSix][Ad] nil getAdPreloadData");
        return nil;
    }
    return %orig;
}
- (id)getAdData {
    if ([[AuxConfig shared] adBlockEnabled]) return nil;
    return %orig;
}
- (id)getAdvertiseInfoForItem:(id)item {
    if ([[AuxConfig shared] adBlockEnabled]) return nil;
    return %orig;
}
- (id)getFirstCanvasAdCard {
    if ([[AuxConfig shared] adBlockEnabled]) return nil;
    return %orig;
}
- (id)getFirstCanvasAdCardInMaxGroup {
    if ([[AuxConfig shared] adBlockEnabled]) return nil;
    return %orig;
}
- (id)getFirstUnexposedCanvasAdCard {
    if ([[AuxConfig shared] adBlockEnabled]) return nil;
    return %orig;
}
- (id)getInsertedAdCardListWithLimit:(id)limit {
    if ([[AuxConfig shared] adBlockEnabled]) return [NSMutableArray array];
    return %orig;
}
%end

// TODO[微信内部]：WCAdvertisePushService 的推送方法名未从二进制确认，先不 hook，
// 避免挂不存在的选择器。后续对微信二进制核方法名后补。

#pragma mark - 看一看 / 视频号 品牌广告（Swift 类，按类名 hook）

// MagicAd 品牌场景：直接拦掉
%hook _TtC6WeChat19MagicAdBrandService
- (id)createMagicAdBrandServiceScene:(id)scene error:(id*)err {
    if ([[AuxConfig shared] adBlockEnabled]) {
        if (err) *err = nil;
        NSLog(@"[AuxSix][Ad] block brand service scene");
        return nil;
    }
    return %orig;
}
%end

%hook WCFinderFeedFlowViewDataSource
// TODO[微信内部]：getFirstUnexposedCanvasAdCard 归属类未确认（可能属 WCAdDynamicCanvasPageInfo）。
// Theos 对未匹配到方法的选择器不报错，编译能通过，跑起来看日志判断是否命中。
- (id)getFirstUnexposedCanvasAdCard {
    if ([[AuxConfig shared] boolForKey:K_ADBLOCK_CHANNELS hasDefault:NO]) return nil;
    return %orig;
}
%end
