//
//  AuxSettingController.xm — 微信"第三方插件"设置页（6 个功能开关）
//  由 Tweak.xm 通过 WCPluginsMgr registerControllerWithTitle:version:controller: 注册。
//  参考 WechatEnhance 开源版写法：纯 UIViewController，被微信导航容器 push，不闪退。
//
#import "common/AuxSettingController.h"
#import "common/AuxConfig.h"

@interface AuxSettingController () <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) UITableView *table;
@end

@implementation AuxSettingController

// 固定 6 行（dispatch_once，避免每次返回新数组造成 cell 复用越界）
static NSArray<NSDictionary *> *auxRows(void) {
    static NSArray *_rows = nil;
    static dispatch_once_t once = 0;
    dispatch_once(&once, ^{
        _rows = @[
            @{ @"t": @"防止撤回",   @"k": K_PREVENT_REVOKE },
            @{ @"t": @"自动收红包", @"k": K_AUTO_RED_ENVELOP },
            @{ @"t": @"广告净化",   @"k": K_AD_BLOCK },
            @{ @"t": @"列表圆角",   @"k": K_ROUND_CORNER },
            @{ @"t": @"隐藏设备",   @"k": K_HIDE_DEVICE },
            @{ @"t": @"文字转语音", @"k": K_TTS },
        ];
    });
    return _rows;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"AuxSix";
    self.view.backgroundColor = [UIColor systemBackgroundColor];

    _table = [[UITableView alloc] initWithFrame:CGRectZero
                                          style:UITableViewStyleInsetGrouped];
    _table.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _table.dataSource = self;
    _table.delegate = self;
    _table.rowHeight = 44.0;
    _table.backgroundColor = [UIColor systemGroupedBackgroundColor];
    [self.view addSubview:_table];

    NSLog(@"[AuxSix] AuxSettingController viewDidLoad, rows=%lu",
          (unsigned long)auxRows().count);
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    _table.frame = self.view.bounds;
}

- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)s {
    return (NSInteger)auxRows().count;
}

- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    static NSString *idn = @"AuxRow";
    UITableViewCell *c = [tv dequeueReusableCellWithIdentifier:idn];
    if (!c) c = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                        reuseIdentifier:idn];

    NSArray *rows = auxRows();
    if (ip.row >= (NSInteger)rows.count) {
        c.textLabel.text = @"";
        [c setAccessoryView:nil];
        return c;
    }
    NSDictionary *r = rows[ip.row];
    c.textLabel.text = r[@"t"];
    c.imageView.image = nil;

    // 复用安全：清掉旧 accessory
    c.accessoryView = nil;
    UISwitch *sw = [UISwitch new];
    sw.on = [[AuxConfig shared] boolForKey:r[@"k"] hasDefault:NO];
    sw.tag = ip.row;
    [sw addTarget:self action:@selector(switched:) forControlEvents:UIControlEventValueChanged];
    c.accessoryView = sw;
    return c;
}

// 开/关总开关时立即广播，各模块监听到后自行重应用（幂等、带限深保护）
- (void)switched:(UISwitch *)sw {
    NSArray *rows = auxRows();
    NSInteger idx = sw.tag;
    if (idx >= (NSInteger)rows.count) {
        NSLog(@"[AuxSix][Setting] switched: bad tag %ld", (long)idx);
        return;
    }
    NSDictionary *r = rows[idx];
    BOOL v = sw.on;
    [[AuxConfig shared] setBool:v forKey:r[@"k"]];
    NSLog(@"[AuxSix][Setting] %@ = %d", r[@"k"], (int)v);
}

@end
