//
//  AuxTTS.xm — 文字转语音（对应 AFNTextToSpeech* 一族 31 类）
//
//  外部 TTS 服务（AFN 原版用 fineshare.net / Fish Audio）：
//    https://aivoiceover.fineshare.net/api/{checkin,getcredits,redemptioncredits}
//    凭据 key：AFNTextToSpeechFishToken / SignatureKey / Token
//  ⚠️ 该服务属于 AFN 作者，提取后建议换成自己的 TTS 后端
//     （OpenAI / Edge-TTS / 自建），配置层已留 K_TTS_API_URL / K_TTS_TOKEN
//
//  微信侧目标（AFN 二进制确认）：
//    convertAndSendText:toContact:source:  （文本消息发送路径 → 拦截转 TTS 发出）
//    afn_ttsConvertToVoice:               （TTS 转换入口）
//    语音消息 XML：<msg><voicemsg voicelength="%u" voiceformat="4" forwardflag="0" /></msg>
//  本地缓存：AFN/UserData/TextToSpeech，预览 afn_tts_preview_%lu.mp3
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#include <substrate.h>
#import "common/AuxConfig.h"

@interface AuxTTS : NSObject
+ (void)install;
// 文本 → 语音文件
+ (void)convert:(NSString *)text
       completion:(void (^)(NSURL *audioFile, BOOL ok))cb;
@end

@implementation AuxTTS

+ (void)install {
    NSLog(@"[AuxSix] tts hooks installed");
}

+ (NSString *)cacheDir {
    NSArray *dirs = NSSearchPathForDirectoriesInDomains(NSCachesDirectory,
                                                         NSUserDomainMask, YES);
    NSString *base = dirs.firstObject ?: NSTemporaryDirectory();
    NSString *p = [base stringByAppendingPathComponent:@"AuxSix/TextToSpeech"];
    [[NSFileManager defaultManager] createDirectoryAtPath:p
                          withIntermediateDirectories:YES attributes:nil error:nil];
    return p;
}

// 调 TTS API 拿音频（简化：POST text 到配置的 API URL）
+ (void)convert:(NSString *)text completion:(void (^)(NSURL *, BOOL))cb {
    AuxConfig *c = [AuxConfig shared];
    NSString *url = [c stringForKey:K_TTS_API_URL hasDefault:@""];
    NSString *tok = [c stringForKey:K_TTS_TOKEN hasDefault:@""];
    if (url.length == 0) {
        NSLog(@"[AuxSix][TTS] no API URL configured");
        if (cb) cb(NULL, NO);
        return;
    }
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]];
    req.HTTPMethod = @"POST";
    [req setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    if (tok.length) [req setValue:[NSString stringWithFormat:@"Bearer %@", tok]
                 forHTTPHeaderField:@"Authorization"];
    NSData *body = [NSJSONSerialization dataWithJSONObject:
                    @{@"text": text,
                      @"voice": [c stringForKey:K_TTS_VOICE hasDefault:@"default"],
                      @"speed": @([c intForKey:K_TTS_SPEED hasDefault:5])}
                        options:0 error:NULL];
    [req setHTTPBody:body];

    // ✅修复：保存task对象，不要链式直接调用resume
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:req
        completionHandler:^(NSData *d, NSURLResponse *r, NSError *e) {
        if (e || !d) { NSLog(@"[AuxSix][TTS] api err %@", e); if (cb) cb(NULL, NO); return; }
        // TODO: 确认响应的音频编码（mp3/wav）→ 落盘缓存 → 交给发送管线
        NSURL *f = [NSURL fileURLWithPath:
            [NSString stringWithFormat:@"%@/afn_tts_preview_%lu.mp3",
             [AuxTTS cacheDir], (unsigned long)fabs(text.hash % 100000)]];
        [d writeToURL:f options:NSDataWritingAtomic error:NULL];
        NSLog(@"[AuxSix][TTS] audio cached %@ (%lu bytes)", f.lastPathComponent, (unsigned long)d.length);
        if (cb) cb(f, YES);
    }];
    [task resume];
}

@end

#pragma mark - 微信侧 hook：文本发送拦截

%hook CMessageMgr
- (void)convertAndSendText:(id)text toContact:(id)contact source:(id)source {
    if ([[AuxConfig shared] ttsEnabled]) {
        // TODO[微信内部]：拦截文本 → 调 [AuxTTS convert:] 拿音频 → 走语音发送管线
        // （AFN 通过 CMessageMgr 的 AudioSender/upload 发 voicemsg：
        //   <msg><voicemsg voicelength="%u" voiceformat="4" forwardflag="0" /></msg>）
        NSLog(@"[AuxSix][TTS] intercept convertAndSendText %@ -> %@", text, contact);
    }
    %orig;
}
%end
