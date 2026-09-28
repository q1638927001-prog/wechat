//
//  AuxConfig.h — AuxSix 配置层声明（替换 AFN 的 AFNConfig + 各 *Store）
//
//  - 持久化：NSUserDefaults（key 前缀 com.auxsix.）
//  - key 宏表：K_*（全部用宏定义，避免被多个编译单元 #import 时全局常量重复）
//  - 变更通知：AuxConfigDidChangeNotification（object = 变更的 key）
//

#import <Foundation/Foundation.h>

#pragma mark - 通知常量（宏形式，可被任意 TU 包含）

#define AuxConfigDidChangeNotification @"AuxConfigDidChangeNotification"

#pragma mark - key 宏表

#define AUX_PREFIX             @"com.auxsix."

// ---- 功能总开关 ----
#define K_PREVENT_REVOKE      (AUX_PREFIX @"preventRevoke")
#define K_AUTO_RED_ENVELOP    (AUX_PREFIX @"autoRedEnvelop")
#define K_AD_BLOCK            (AUX_PREFIX @"adBlock")
#define K_ROUND_CORNER        (AUX_PREFIX @"roundCorner")
#define K_HIDE_DEVICE         (AUX_PREFIX @"hideDevice")
#define K_TTS                 (AUX_PREFIX @"tts")

// ---- 防撤回 ----
#define K_PR_PROMPT_FORMAT    (AUX_PREFIX @"preventRevoke.promptFormat")
#define K_PR_SILENT           (AUX_PREFIX @"preventRevoke.silentMode")
#define K_PR_COLOR_HEX        (AUX_PREFIX @"preventRevoke.colorHex")

// ---- 自动收红包 ----
#define K_RED_DELAY           (AUX_PREFIX @"redEnvelop.delay")
#define K_RED_CATCH_ME        (AUX_PREFIX @"redEnvelop.catchMe")
#define K_RED_MULTI           (AUX_PREFIX @"redEnvelop.multipleCatch")
#define K_RED_GROUP_FILTER    (AUX_PREFIX @"redEnvelop.groupFilter")
#define K_RED_TEXT_FILTER     (AUX_PREFIX @"redEnvelop.textFilter")
#define K_RED_AUTOREPLY_ON    (AUX_PREFIX @"redEnvelop.autoReplyEnable")
#define K_RED_AUTOREPLY_TEXT  (AUX_PREFIX @"redEnvelop.autoReplyText")
#define K_RED_REMINDER        (AUX_PREFIX @"redEnvelop.reminderEnable")
#define K_RED_VOICE_BROADCAST (AUX_PREFIX @"redEnvelop.voiceBroadcastEnable")
#define K_RED_TOTAL_AMOUNT    (AUX_PREFIX @"redEnvelop.totalAmount")
#define K_RED_DETAIL_ON       (AUX_PREFIX @"redEnvelop.detailEnabled")

// ---- 广告净化 ----
#define K_ADBLOCK_TIMELINE    (AUX_PREFIX @"adBlock.timeline")
#define K_ADBLOCK_SEARCH      (AUX_PREFIX @"adBlock.search")
#define K_ADBLOCK_CHANNELS    (AUX_PREFIX @"adBlock.channels")
#define K_ADBLOCK_MP          (AUX_PREFIX @"adBlock.mp")
#define K_ADBLOCK_MINIPROG    (AUX_PREFIX @"adBlock.miniProgram")
#define K_ADBLOCK_DIAG        (AUX_PREFIX @"adBlock.diagnosticMode")

// ---- 列表圆角 ----
#define K_ROUND_SEARCHBOX     (AUX_PREFIX @"roundCorner.searchBox")
#define K_ROUND_INPUTTEXT     (AUX_PREFIX @"roundCorner.inputText")
#define K_ROUND_MOREDISC      (AUX_PREFIX @"roundCorner.moreDiscover")

// ---- 隐藏设备 ----
#define K_HIDE_MULTILogin     (AUX_PREFIX @"hideDevice.multiLogin")

// ---- 文字转语音 ----
#define K_TTS_VOICE           (AUX_PREFIX @"tts.selectedVoice")
#define K_TTS_API_URL         (AUX_PREFIX @"tts.apiURL")
#define K_TTS_TOKEN           (AUX_PREFIX @"tts.token")
#define K_TTS_SPEED           (AUX_PREFIX @"tts.speed")
#define K_TTS_VOLUME          (AUX_PREFIX @"tts.volume")

#pragma mark - 接口

@interface AuxConfig : NSObject

+ (instancetype)shared;

// ---- 功能总开关（只读，值来自 NSUserDefaults）----
@property (nonatomic, readonly) BOOL preventRevokeEnabled;
@property (nonatomic, readonly) BOOL autoRedEnvelopEnabled;
@property (nonatomic, readonly) BOOL adBlockEnabled;
@property (nonatomic, readonly) BOOL roundCornerEnabled;
@property (nonatomic, readonly) BOOL hideDeviceEnabled;
@property (nonatomic, readonly) BOOL ttsEnabled;

// ---- 通用访问器 ----
- (BOOL)boolForKey:(NSString *)key hasDefault:(BOOL)def;
- (void)setBool:(BOOL)v forKey:(NSString *)key;

- (int)intForKey:(NSString *)key hasDefault:(int)def;
- (void)setInt:(int)v forKey:(NSString *)key;

- (NSString *)stringForKey:(NSString *)key hasDefault:(NSString *)def;
- (void)setString:(NSString *)v forKey:(NSString *)key;

// 手动发变更通知（setter 已自动发，仅在外部改 defaults 时用）
- (void)postChanged:(NSString *)key;

// 诊断：一行输出 6 个总开关状态
- (NSString *)debugSummary;

@end
