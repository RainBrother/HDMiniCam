//
//  KHJBackPlayListVC.m
//  HDMiniCam
//
//  Created by khj888 on 2020/2/23.
//  Copyright © 2020 王涛. All rights reserved.
//

#import "KHJBackPlayListVC.h"
#import "KHJBackPlayListCell.h"
#import "KHJDeviceManager.h"
//
#import "JSONStructProtocal.h"

extern IPCNetRecordCfg_st recordCfg;
extern const char *mCurViewPath_date;
extern RemoteDirInfo_t *mCurRemoteDirInfo;

@interface KHJBackPlayListVC ()<UITableViewDelegate,UITableViewDataSource>
{
    __weak IBOutlet UITableView *contentList;
    __weak IBOutlet UILabel *numLab;
}

@property (nonatomic, strong) NSMutableArray *listArr;

@end

@implementation KHJBackPlayListVC

- (NSMutableArray *)listArr
{
    if (!_listArr) {
        _listArr = [NSMutableArray array];
    }
    return _listArr;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    if (self.exitVideoList) {
        [self reloadTableView];
    }
    else {
        [self getVideoList];
    }
    self.titleLab.text = self.deviceID;
    [self.leftBtn addTarget:self action:@selector(backAction) forControlEvents:UIControlEventTouchUpInside];
}

- (void)backAction
{
    [self.navigationController popViewControllerAnimated:YES];
}

- (IBAction)btnAction:(UIButton *)sender
{
    if (sender.tag == 10) {
        CLog(@"刷新");
    }
    else if (sender.tag == 20) {
        CLog(@"返回");
    }
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.listArr.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    KHJBackPlayListCell *cell = [tableView dequeueReusableCellWithIdentifier:@"KHJBackPlayListCell"];
    if (cell == nil) {
        cell = [[NSBundle mainBundle] loadNibNamed:@"KHJBackPlayListCell" owner:nil options:nil][0];
    }
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        
        NSDictionary *body = self.listArr[indexPath.row];
        NSString *date  = @"2020/02/23";
        NSInteger time = [body[@"end"] integerValue] - [body[@"start"] integerValue];
        int hour = (int)time / 3600;
        int min  = (int)(time - hour * 3600) / 60;
        int sec  = (int)(time - hour * 3600 - min * 60);
        NSString *times = KHJString(@"%02d:%02d:%02d", hour, min, sec);
        
        long size = [body[@"size"] longLongValue];
        NSString *sizeUnit = [self imageSizeString:size];

        dispatch_async(dispatch_get_main_queue(), ^{
            cell.nameLab.text = body[@"name"];
            cell.detailsLab.text = KHJString(@"%@-%@ (%@ %@M)",date,body[@"start"],times, sizeUnit);
        });
    });
    return cell;
}

//单位转换
- (NSString *)imageSizeString:(unsigned long long)size
{
    if (size >= 1024*1024) {
        return [NSString stringWithFormat:@"%.2f",size/(1024*1024.0)];
    }
    else if (size > 1024) {
        return [NSString stringWithFormat:@"%.2f",size/1024.0];
    }
    else {
        return @"";
    }
}

- (void)getVideoList
{
    [[KHJDeviceManager sharedManager] getRecordConfig_with_deviceID:self.deviceID json:@"" resultBlock:^(NSInteger code) {
        CLog(@"code = %ld",(long)code);
    }];
    // 1、获取录像配置信息：获取文件路径
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(noti_1073_key:) name:noti_1073_KEY object:nil];
    // 2、获取远程信息：获取文件数量
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(noti_1075_key:) name:noti_1075_KEY object:nil];
    // 3、通过文件路径 + 文件数量 => 获取 回放视频列表
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(noti_1077_key:) name:noti_1077_KEY object:nil];
}

#pragma mark - 获取录像配置信息：获取文件路径

- (void)noti_1073_key:(NSNotification *)obj
{
    [self getBackPlayList];
}

- (void)getBackPlayList
{
    NSDate *date = [NSDate date];
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyyMM/dd"];
    //获取当前时间日期展示字符串 如：2019-05-23-13:58:59
    NSString *str = [formatter stringFromDate:date];
    mCurViewPath_date = str.UTF8String;
    
    NSString *rootdir = KHJString(@"%@/%@",[NSString stringWithUTF8String:recordCfg.DiskInfo->Path.c_str()],str);
    int vi = 0;
    // 0: 只扫描文件   1: 扫描目录和文件
    int mode = 1;
    // 文件开始时间
    int start = 0;
    // 文件结束时间
    int end = 240000;

    // 组织json字符串，lir是list remote简写，p为path简写，si是sensor index简写，m是mode简写，st是start time，e是end time
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    NSMutableDictionary *body = [NSMutableDictionary dictionary];
    [body setValue:rootdir forKey:@"p"];
    [body setValue:@(vi) forKey:@"si"];
    [body setValue:@(mode) forKey:@"m"];
    [body setValue:@(start) forKey:@"st"];
    [body setValue:@(end) forKey:@"e"];
    [dict setValue:body forKey:@"lir"];
    // "{\"lir\":{\"p\":\"%s\",\"si\":%d,\"m\":%d,\"st\":%d,\"e\":%d}}"
//    CLog(@"dict = %@",dict);
    NSString *json = [KHJUtility convertToJsonData:(NSDictionary *)dict];
//    CLog(@"json = %@",json);
    [[KHJDeviceManager sharedManager] getRemoteDirInfo_with_deviceID:self.deviceID json:json resultBlock:^(NSInteger code) {
        CLog(@"code = %ld",(long)code);
    }];
}

#pragma mark - 获取远程信息：获取文件数量

- (void)noti_1075_key:(NSNotification *)obj
{
    NSDate *date = [NSDate date];
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyyMM/dd"];
    //获取当前时间日期展示字符串 如：2019-05-23-13:58:59
    NSString *str = [formatter stringFromDate:date];
    
    NSString *rootdir = KHJString(@"%@/%@",[NSString stringWithUTF8String:recordCfg.DiskInfo->Path.c_str()],str);
    NSDictionary *result = (NSDictionary *)obj.object;
    CLog(@"num of files:%@ disk size:%@ MB used size:%@ MB\n",result[@"n"], result[@"t"], result[@"u"]);
    //组织json字符串，lp是list path简写， p为path简写，s是start简写，c是count简写
//    int count = [result[@"n"] intValue];
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    NSMutableDictionary *body = [NSMutableDictionary dictionary];
    [body setValue:rootdir  forKey:@"p"];
    [body setValue:@(0)     forKey:@"s"];
    [body setValue:@(10)    forKey:@"c"];
    [dict setValue:body     forKey:@"lp"];
    NSString *json = [KHJUtility convertToJsonData:(NSDictionary *)dict];
    [[KHJDeviceManager sharedManager] getRemotePageFile_with_deviceID:self.deviceID path:json resultBlock:^(NSInteger code) {
        CLog(@"code = %ld",(long)code);
    }];
}

#pragma mark - 通过文件路径 + 文件数量 => 获取 回放视频列表 (存入)

- (void)noti_1077_key:(NSNotification *)obj
{
    [self reloadTableView];
}

- (void)reloadTableView
{
    WeakSelf
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        for (list<RemoteFileInfo_t*>::iterator i= mCurRemoteDirInfo->mRemoteFileInfoList.begin(); i != mCurRemoteDirInfo->mRemoteFileInfoList.end(); i++){
            RemoteFileInfo_t *rfi = *i;
            NSMutableDictionary *body = [NSMutableDictionary dictionary];
            NSString *name = [NSString stringWithUTF8String:rfi->name.c_str()];
            NSArray *timeArr1 = [name componentsSeparatedByString:@"."];
            NSArray *timeArr2 = [timeArr1.firstObject componentsSeparatedByString:@"-"];
            NSString *start = timeArr2.firstObject;
            NSString *end = timeArr2.lastObject;
            [body setValue:[NSString stringWithUTF8String:rfi->name.c_str()] forKey:@"name"];
            [body setValue:[NSString stringWithUTF8String:rfi->path.c_str()] forKey:@"videoPath"];
            [body setValue:@(rfi->size) forKey:@"size"];
            [body setValue:start forKey:@"start"];
            [body setValue:end forKey:@"end"];
            [weakSelf.listArr addObject:body];
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            if (weakSelf.delegate && [weakSelf.delegate respondsToSelector:@selector(exitListData:)]) {
                if (weakSelf.listArr.count > 0) {
                    [weakSelf.delegate exitListData:YES];
                }
                else {
                    [weakSelf.delegate exitListData:NO];
                }
            }
            [self->contentList reloadData];
        });
    });
}

@end