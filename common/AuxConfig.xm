//
//  AuxConfig.xm — AuxConfig 实现（配置层，替换 AFN 的 AFNConfig + 各 *Store）
//
//  设计要点：
//  - 单例 + NSUserDefaults（key 前缀 com.auxsix.）
//  - 读：boolForKey:hasDefault: 区分"未设置"与"显式 false"（AFN 的 Store 也是这个语义）
//  - 写：setter 自动广播 AuxConfigDidChangeNotification（object=变更的 key），
//        各模块监听后自行重应用，实现"改配置立即生效"
//  - 本文件只编译一次（在 Makefile 的 MODULES 里）；
//    其他文件 #import "common/AuxConfig.h"（纯声明，无实现）
//

#import <Foundation/Foundation.h>
#import <dispatch/dispatch.h>

#import "common/AuxConfig.h"

#pragma mark - 实现

@implementation AuxConfig

+ (instancetype)shared {
    static AuxConfig *s = nil;
    static dispatch_once_t once = 0;
    dispatch_once(&once, ^{
        s = [AuxConfig new];
        [s migrateDefaults];
    });
    return s;
}

#pragma mark - 首次安装迁移

// 给 6 个总开关写默认值（NO），保证 boolForKey 的"未设置"分支有基准
- (void)migrateDefaults {
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    NSArray *switches = @[
        K_PREVENT_REVOKE, K_AUTO_RED_ENVELOP, K_AD_BLOCK,
        K_ROUND_CORNER, K_HIDE_DEVICE, K_TTS,
    ];
    for (NSString *k in switches) {
        if (![d objectForKey:k]) [d setBool:NO forKey:k];
    }
    [d synchronize];
}

#pragma mark - 总开关

- (BOOL)preventRevokeEnabled  { return [self boolForKey:K_PREVENT_REVOKE   hasDefault:NO]; }
- (BOOL)autoRedEnvelopEnabled { return [self boolForKey:K_AUTO_RED_ENVELOP hasDefault:NO]; }
- (BOOL)adBlockEnabled        { return [self boolForKey:K_AD_BLOCK         hasDefault:NO]; }
- (BOOL)roundCornerEnabled    { return [self boolForKey:K_ROUND_CORNER     hasDefault:NO]; }
- (BOOL)hideDeviceEnabled     { return [self boolForKey:K_HIDE_DEVICE      hasDefault:NO]; }
- (BOOL)ttsEnabled            { return [self boolForKey:K_TTS              hasDefault:NO]; }

#pragma mark - 通用访问器

- (BOOL)boolForKey:(NSString *)key hasDefault:(BOOL)def {
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    id v = [d objectForKey:key];
    if (v == nil || [v isKindOfClass:[NSNull class]]) return def;
    return [v boolValue];
}

- (void)setBool:(BOOL)v forKey:(NSString *)key {
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    [d setBool:v forKey:key];
    [d synchronize];
    NSLog(@"[AuxSix][Config] %@ = %d", key, (int)v);
    [[NSNotificationCenter defaultCenter] postNotificationName:AuxConfigDidChangeNotification
                                                        object:key];
}

- (int)intForKey:(NSString *)key hasDefault:(int)def {
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    id v = [d objectForKey:key];
    if (v == nil || [v isKindOfClass:[NSNull class]]) return def;
    return [v intValue];
}

- (void)setInt:(int)v forKey:(NSString *)key {
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    [d setInteger:v forKey:key];
    [d synchronize];
    NSLog(@"[AuxSix][Config] %@ = %d", key, v);
    [[NSNotificationCenter defaultCenter] postNotificationName:AuxConfigDidChangeNotification
                                                        object:key];
}

- (NSString *)stringForKey:(NSString *)key hasDefault:(NSString *)def {
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    NSString *v = [d stringForKey:key];
    if (v.length == 0) return def;
    return v;
}

- (void)setString:(NSString *)v forKey:(NSString *)key {
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    [d setObject:(v.length ? v : [NSNull null]) forKey:key];
    [d synchronize];
    NSLog(@"[AuxSix][Config] %@ set", key);
    [[NSNotificationCenter defaultCenter] postNotificationName:AuxConfigDidChangeNotification
                                                        object:key];
}

- (void)postChanged:(NSString *)key {
    [[NSNotificationCenter defaultCenter] postNotificationName:AuxConfigDidChangeNotification
                                                        object:key];
}

#pragma mark - 诊断

- (NSString *)debugSummary {
    return [NSString stringWithFormat:
            @"preventRevoke=%d autoRedEnvelop=%d adBlock=%d "
            @"roundCorner=%d hideDevice=%d tts=%d",
            (int)self.preventRevokeEnabled,
            (int)self.autoRedEnvelopEnabled,
            (int)self.adBlockEnabled,
            (int)self.roundCornerEnabled,
            (int)self.hideDeviceEnabled,
            (int)self.ttsEnabled];
}

@end
