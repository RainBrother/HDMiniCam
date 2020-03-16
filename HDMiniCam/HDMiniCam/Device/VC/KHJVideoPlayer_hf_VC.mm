//
//  KHJVideoPlayer_hf_VC.m
//  HDMiniCam
//
//  Created by khj888 on 2020/2/13.
//  Copyright © 2020 王涛. All rights reserved.
//

#import "KHJVideoPlayer_hf_VC.h"
#import "KHJDeviceManager.h"
#import "ZFTimeLine.h"
#import "NSDate+JLZero.h"
#import "KHJBackPlayListVC.h"
// 
#import "TuyaTimeLineModel.h"
#import "TYCameraTimeLineScrollView.h"
//
#import "JKUIPickDate.h"
#import "KHJVideoModel.h"
#import "JSONStructProtocal.h"

typedef void(^runloopBlock)(void);

// 当前解码类型
extern IPCNetRecordCfg_st recordCfg;

@interface KHJVideoPlayer_hf_VC ()
<ZFTimeLineDelegate,
KHJBackPlayListVCSaveListDelegate,
H26xHwDecoderDelegate,
TYCameraTimeLineScrollViewDelegate>
{
    __weak IBOutlet UILabel *nameLab;
    __weak IBOutlet UIView *reconnectView;
    __weak IBOutlet UIImageView *playerImageView;
    __weak IBOutlet UIButton *preDayBtn;
    __weak IBOutlet UILabel *dateLAB;
    __weak IBOutlet UIButton *nextDayBtn;
    
    __weak IBOutlet UIView *timeLineContent;
    __weak IBOutlet UIButton *recordBtn;
    
    __weak IBOutlet UILabel *listenLab;
    __weak IBOutlet UIImageView *listenImgView;
    
    BOOL exitVideoList;
    NSTimer *delayHiddenTimer;
    
    H26xHwDecoder *h264Decode;
    BOOL isRebackPlaying;
    // 录屏模块
    KHJRebackPlayRecordType rebackPlayRecordType;
    RecSess_t rebackPlayRecordSession;
    dispatch_queue_t recordQueue;
    NSString *rebackPlayRecordVideoPath;
    
    NSTimer *recordTimer;
    NSInteger recordTimes;
    __weak IBOutlet UIView *recordTimeView;
    __weak IBOutlet UILabel *recordTimeLab;
}

@property (nonatomic, assign) NSInteger delayHiddenTimes;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *activityView;
// 装记任务的Arr
@property (nonatomic, strong) NSMutableArray *MP4_taskArray;

@property (nonatomic, assign) NSTimeInterval zeroTimeInterval;
@property (nonatomic, assign) NSTimeInterval todayTimeInterval;
@property (nonatomic, assign) NSTimeInterval currentTimeInterval;

@property (nonatomic, assign) NSInteger currentIndex;
@property (nonatomic, strong) NSMutableArray *videoList;

@property (nonatomic, copy) ZFTimeLine *zfTimeView;
@property (nonatomic, strong) TYCameraTimeLineScrollView *timeLineView;

@end

@implementation KHJVideoPlayer_hf_VC

#pragma MARK - H26xHwDecoderDelegate

- (void)getImageWith:(UIImage * _Nullable)image imageSize:(CGSize)imageSize deviceID:(NSString *)deviceID
{
    dispatch_async(dispatch_get_main_queue(), ^{
        self->playerImageView.image = image;
    });
}

- (NSMutableArray *)videoList
{
    if (!_videoList) {
        _videoList = [NSMutableArray array];
    }
    return _videoList;
}

- (ZFTimeLine *)zfTimeView
{
    if (!_zfTimeView) {
        _zfTimeView = [[ZFTimeLine alloc] initWithFrame:CGRectMake(0, 0, SCREEN_WIDTH, 80)];
        _zfTimeView.delegate = self;
    }
    return _zfTimeView;
}

- (TYCameraTimeLineScrollView *)timeLineView
{
    if (_timeLineView == nil) {
        _timeLineView = [[TYCameraTimeLineScrollView alloc] initWithFrame:CGRectMake(0, 0, SCREEN_WIDTH, 80)];
        _timeLineView.delegate = self;
        _timeLineView.spacePerUnit = 100;
        _timeLineView.showShortLine = YES;
    }
    return _timeLineView;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    isRebackPlaying = NO;
    self.delayHiddenTimes = 2;
    nextDayBtn.hidden = YES;
    rebackPlayRecordSession = NULL;
    recordQueue = dispatch_queue_create("recordQueue", DISPATCH_QUEUE_SERIAL);
    [self customizeDataSource];
}

- (void)customizeDataSource
{
    h264Decode = [[H26xHwDecoder alloc] init];
    h264Decode.delegate = self;
    
//    [timeLineContent addSubview:self.zfTimeView];
    [timeLineContent addSubview:self.timeLineView];
    NSDate *date = [NSDate date];
    self.currentTimeInterval = [date timeIntervalSince1970];
    self.todayTimeInterval = [NSDate getZeroWithTimeInterverl:self.currentTimeInterval];
    self.zeroTimeInterval = [NSDate getZeroWithTimeInterverl:self.currentTimeInterval];
    NSDateFormatter *formatter1 = [[NSDateFormatter alloc] init];
    [formatter1 setDateFormat:@"yyyy_MM_dd"];
    dateLAB.text = [formatter1 stringFromDate:date];
    [self fireTimer];
    [self getTimeLineDataWith:dateLAB.text];
    [self addMP4_RunloopObserver];
    [self addNoti];
}

- (void)addNoti
{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(noti_timeLineInfo_1075_key:) name:noti_timeLineInfo_1075_KEY object:nil];
}

- (void)noti_timeLineInfo_1075_key:(NSNotification *)noti
{
    WeakSelf
    [self addMP4_tasks:^{
        dispatch_async(dispatch_get_global_queue(0, 0), ^{
            NSArray *backPlayList = [NSArray arrayWithArray:(NSArray *)noti.object];

            for (int i = 0; i < backPlayList.count; i++) {
                NSDictionary *body = backPlayList[i];
                int type                = [body[@"type"] intValue];
                NSString *startString   = KHJString(@"%06d",[body[@"start"] intValue]);
                NSString *endString     = KHJString(@"%06d",[body[@"end"] intValue]);

                int startHour   = [[startString substringWithRange:NSMakeRange(0, 2)] intValue];
                int startMin    = [[startString substringWithRange:NSMakeRange(2, 2)] intValue];
                int startSec    = [[startString substringWithRange:NSMakeRange(4, 2)] intValue];
                int startTimeInterval   = startHour * 3600 + startMin * 60 + startSec;

                int endHour = [[endString substringWithRange:NSMakeRange(0, 2)] intValue];
                int endMin  = [[endString substringWithRange:NSMakeRange(2, 2)] intValue];
                int endSec  = [[endString substringWithRange:NSMakeRange(4, 2)] intValue];
                int endTimeInterval = endHour * 3600 + endMin * 60 + endSec;

                KHJVideoModel *model = [[KHJVideoModel alloc] init];
                model.startTime = startTimeInterval + weakSelf.zeroTimeInterval; // 起始时间
                model.durationTime = endTimeInterval - startTimeInterval;// 视频时长
                if (type == 0) {        // 正常录制
                    model.recType = 0;
                }
                else if (type == 1) {   // 移动检测录制
                    model.recType = 2;
                }
                else if (type == 3) {   // 声音检测录制
                    model.recType = 4;
                }
                [weakSelf.videoList addObject:model];
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                
                CLog(@"weakSelf.videoList = %@",weakSelf.videoList);
                CLog(@"currentTimeInterval ==================================================================== %f",weakSelf.currentTimeInterval);
                
//                weakSelf.zfTimeView.timesArr = weakSelf.videoList;
//                CLog(@"currentTimeInterval ==================================================================== %f",weakSelf.currentTimeInterval);
//
//                [weakSelf.zfTimeView updateCurrentInterval:weakSelf.currentTimeInterval];
            });
        });
    }];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self.navigationController setNavigationBarHidden:YES animated:YES];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self registerCallBack];
};

// 注册回放监听
- (void)registerCallBack
{
    WeakSelf
    [[KHJDeviceManager sharedManager] setPlaybackAudioVideoDataCallBack_with_deviceID:self.deviceID resultBlock:^(const char * _Nonnull uuid, int type, unsigned char * _Nonnull data, int len, long timestamp) {
        self->isRebackPlaying = YES;
        [weakSelf.activityView stopAnimating];
        self->playerImageView.hidden = NO;
        if (type < 20) {
            // h264数据
//            CLog(@"h264数据");
            [weakSelf getPlayBackVideo_With_deviceID:uuid dataType:type data:data length:len timeStamps:timestamp];
        }
        else if (type >= 50) {
            // h265数据
//            CLog(@"h265数据");
            [weakSelf getPlayBackVideo_With_deviceID:uuid dataType:type data:data length:len timeStamps:timestamp];
        }
        else {
            // 音频数据
        }
    }];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [[KHJDeviceManager sharedManager] stopPlayback_with_deviceID:self.deviceID resultBlock:^(NSInteger code) {}];
    [super viewWillDisappear:animated];
}

- (IBAction)btnAction:(UIButton *)sender
{
    if (sender.tag == 10) {
        [self.navigationController popViewControllerAnimated:YES];
    }
    else if (sender.tag == 20) {
        // 连接失败，点击重连
    }
    else if (sender.tag == 30) {
        // 前一天
        [self preDay];
    }
    else if (sender.tag == 40) {
        // 选择日历
        [self chooseDate];
    }
    else if (sender.tag == 50) {
        // 后一天
        [self nextDay];
    }
    else if (sender.tag == 60) {
        // 拍照
    }
    else if (sender.tag == 70) {
        recordBtn.selected = !recordBtn.selected;
        if (recordBtn.selected) {
            // 开始录屏
            [self gotoStartRecord];
        }
        else {
            // 停止录屏
            [self gotoStopRecord];
        }
    }
    else if (sender.tag == 80) {
        // 监听
        listenImgView.highlighted = !listenImgView.highlighted;
    }
    else if (sender.tag == 90) {
        // 浏览
        KHJBackPlayListVC *vc = [[KHJBackPlayListVC alloc] init];
        vc.delegate = self;
        vc.date = dateLAB.text;
        vc.deviceID = self.deviceID;
        vc.exitVideoList = exitVideoList;
        [self.navigationController pushViewController:vc animated:YES];
    }
}

- (void)getTimeLineDataWith:(NSString *)date
{
    NSString *time = [date stringByReplacingOccurrencesOfString:@"_" withString:@""];
    // 获取远程回放的配置信息
    [[KHJDeviceManager sharedManager] getRemoteDirInfo_timeLine_with_deviceID:self.deviceID vi:0 date:[time intValue] resultBlock:^(NSInteger code) {}];
}

- (void)exitListData:(BOOL)isExit
{
    exitVideoList = isExit;
}

#pragma mark - 时间轴滑动

- (void)LineBeginMove
{
    CLog(@"LineBeginMove 停止回放");
    [[KHJDeviceManager sharedManager] stopPlayback_with_deviceID:self.deviceID resultBlock:^(NSInteger code) {}];
}

- (void)timeLine:(ZFTimeLine *)timeLine moveToDate:(NSTimeInterval)date
{
    CLog(@" timeLine: moveToDate: %f",date - _zeroTimeInterval);
    NSInteger index = [KHJCalculate binarySearchSDCardStart:self.videoList target:date];
    if (self.videoList.count < index) {
        return;
    }
    if (index == -1) {
        [self.view makeToast:@"当前没有视频！"];
    }
    else {
//        [self.view makeToast:KHJString(@"当前第 %ld 个视频，总共 %ld 个视频", index, self.videoList.count)];
        int date_int = [[dateLAB.text stringByReplacingOccurrencesOfString:@"_" withString:@""] intValue];
        NSDateFormatter *formatterShow = [[NSDateFormatter alloc]init];
        [formatterShow setDateFormat:@"HHmmss"];
        NSDate *date1 = [NSDate dateWithTimeIntervalSince1970:date];
        int timestamp_int = [[formatterShow stringFromDate:date1] intValue];
        // 播放回放视频
        [[KHJDeviceManager sharedManager] starPlayback_timeLine_with_deviceID:self.deviceID vi:0 date:date_int time:timestamp_int resultBlock:^(NSInteger code) {}];
    }
    self.currentIndex = index;
}

#pragma mark - Timer ---------------------------------------------------------------

/* 开启倒计时 */
- (void)fireTimer
{
    [self stopTimer];
    delayHiddenTimer = [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(timerAction) userInfo:nil repeats:YES];
    [[NSRunLoop currentRunLoop] addTimer:delayHiddenTimer forMode:NSRunLoopCommonModes];
    [delayHiddenTimer fire];
}

- (void)timerAction
{
    _delayHiddenTimes--;
    if (_delayHiddenTimes == 0) {
        [self stopTimer];
        self.activityView.hidden = YES;
    }
    else {
        self.activityView.hidden = NO;
    }
}

/* 停止倒计时 */
- (void)stopTimer
{
    if ([delayHiddenTimer isValid] || delayHiddenTimer != nil) {
        [delayHiddenTimer invalidate];
        _delayHiddenTimes = 2;
        delayHiddenTimer = nil;
    }
}

/* 开启倒计时 */
- (void)fireRecordTimer
{
    [self stopRecordTimer];
    recordTimer = [NSTimer scheduledTimerWithTimeInterval:1
                                                   target:self
                                                 selector:@selector(recordTimerAction)
                                                 userInfo:nil
                                                  repeats:YES];
    [[NSRunLoop currentRunLoop] addTimer:recordTimer forMode:NSRunLoopCommonModes];
    [recordTimer fire];
}

- (void)recordTimerAction
{
    int hour = (int)recordTimes / 3600;
    int min  = (int)(recordTimes - hour * 3600) / 60;
    int sec  = (int)(recordTimes - hour * 3600 - min * 60);
    recordTimes ++;
    recordTimeLab.text = KHJString(@"%02d:%02d:%02d", hour, min, sec);
}

/* 停止倒计时 */
- (void)stopRecordTimer
{
    if ([recordTimer isValid] || recordTimer != nil) {
        [recordTimer invalidate];
        recordTimer = nil;
        recordTimes = 0;
    }
}

#pragma mark - ---------------------------------------------------------------

- (NSMutableArray *)MP4_taskArray
{
    if (!_MP4_taskArray) {
        _MP4_taskArray = [NSMutableArray array];
    }
    return _MP4_taskArray;
}

/* 添加MP4，预览图加载任务 */
- (void)addMP4_tasks:(runloopBlock)task
{
    [self.MP4_taskArray addObject:task];
}

// 添加runloop观察者
- (void)addMP4_RunloopObserver
{
    // 1.获取当前Runloop
    CFRunLoopRef runloop = CFRunLoopGetCurrent();
    CFRunLoopObserverContext context = {
        0,
        (__bridge void *)(self),
        &CFRetain,
        &CFRelease,
        NULL
    };
    // 2.定义观察者
    static CFRunLoopObserverRef defaultModeObserver;
    defaultModeObserver = CFRunLoopObserverCreate(kCFAllocatorDefault,
                                                  kCFRunLoopBeforeWaiting,
                                                  YES,
                                                  0,
                                                  &MP4_callBack,
                                                  &context);
    // 3. 给当前Runloop添加观察者
    CFRunLoopAddObserver(runloop, defaultModeObserver, kCFRunLoopCommonModes);
    // C中出现 copy,retain,Create等关键字,都需要release
    CFRelease(defaultModeObserver);
}

static void MP4_callBack(CFRunLoopObserverRef observer, CFRunLoopActivity activity, void *info) {
    KHJVideoPlayer_hf_VC *vc  = (__bridge KHJVideoPlayer_hf_VC *)info;
    if (vc.MP4_taskArray.count == 0) {
        return;
    }
    runloopBlock block          = [vc.MP4_taskArray firstObject];
    if (block) {
        block();
    }
    [vc.MP4_taskArray removeObjectAtIndex:0];
    vc.delayHiddenTimes = 2;
}

#pragma mark - 视频解码

/// 获取sd卡回放 视频数据
/// @param deviceID 设备id
/// @param dataType 数据类型
/// @param data 音频 或 视频
/// @param length 数据长度
/// @param timeStamps 时间戳
- (void)getPlayBackVideo_With_deviceID:(const char* )deviceID
                              dataType:(int)dataType
                                  data:(unsigned char *)data
                                length:(int)length
                            timeStamps:(long)timeStamps
{
//    [self.zfTimeView updateTime:timeStamps/1000 + self.zeroTimeInterval];
//    [self.zfTimeView updateCurrentInterval:timeStamps/1000 + self.zeroTimeInterval];
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        [self->h264Decode decodeH26xVideoData:data videoSize:length frameType:dataType timestamp:timeStamps];
    });
    
    if (rebackPlayRecordType == KHJRebackPlayRecordType_Recording) {
         CLog(@"正在回放录屏 rebackPlayRecordVideoPath = %@",rebackPlayRecordVideoPath);
        dispatch_sync(recordQueue, ^{
            if (self->rebackPlayRecordSession) {
                if (dataType >= 20 && dataType < 30) {
                    int ret = IPCNetPutLocalRecordAudioFrame(rebackPlayRecordSession, dataType, (const char *)data, length, timeStamps);
                    if (ret == 0) CLog(@"输入 Audio 数据");
                }
                else {
                    int ret = IPCNetPutLocalRecordVideoFrame(rebackPlayRecordSession, dataType, (const char *)data, length, timeStamps);
                    if (ret == 0) CLog(@"输入 视频 数据");
                }
            }
            else {
                if (dataType >= 20 && dataType < 30) {
                    // Audio
                }
                else {
                    if (dataType >= 0 && dataType < 20)
                        self->rebackPlayRecordSession = IPCNetStartRecordLocalVideo(rebackPlayRecordVideoPath.UTF8String, IPCNET_VIDEO_ENCODE_TYPE_H264, 30, IPCNET_AUDIO_ENCODE_TYPE_G711A, 8000, 2, 1);
                    else
                        self->rebackPlayRecordSession = IPCNetStartRecordLocalVideo(rebackPlayRecordVideoPath.UTF8String, IPCNET_VIDEO_ENCODE_TYPE_H265, 30, IPCNET_AUDIO_ENCODE_TYPE_G711A, 8000, 2, 1);
                }
            }
        });
    }
    else if (rebackPlayRecordType == KHJRebackPlayRecordType_stopRecoding) {
         CLog(@"停止回放录屏 rebackPlayRecordVideoPath = %@",rebackPlayRecordVideoPath);
        rebackPlayRecordType = KHJRebackPlayRecordType_Normal;
        IPCNetFinishLocalRecord(self->rebackPlayRecordSession);
        self->rebackPlayRecordSession = NULL;
    }
}


#pragma mark - 录像

/// 开始录像
- (void)gotoStartRecord
{
    recordTimeView.hidden = NO;
    [self fireRecordTimer];
    // 回放录屏，截取数据
    rebackPlayRecordType = KHJRebackPlayRecordType_Recording;
    rebackPlayRecordVideoPath = [[[KHJHelpCameraData sharedModel] getTakeVideo_rebackPlay_DocPath_with_deviceID:self.deviceID] stringByAppendingPathComponent:[[KHJHelpCameraData sharedModel] getVideoNameWithType:@"mp4" deviceID:self.deviceID]];
}

/// 停止录像
- (void)gotoStopRecord
{
    [self stopRecordTimer];
    isRebackPlaying = NO;
    recordTimeView.hidden = YES;
    // 结束回放录屏，停止截取数据
    rebackPlayRecordVideoPath = @"";
    rebackPlayRecordType = KHJRebackPlayRecordType_stopRecoding;
}

#pragma mark - 前一天

- (void)preDay
{
    _zeroTimeInterval -= 24*3600;
    _currentTimeInterval -= 24*3600;
    [self.videoList removeAllObjects];
    dateLAB.text = [KHJCalculate prevDay:dateLAB.text];
    [self getTimeLineDataWith:dateLAB.text];
    nextDayBtn.hidden = NO;
}

#pragma mark - 后一天

- (void)nextDay
{
    _zeroTimeInterval += 24*3600;
    _currentTimeInterval += 24*3600;
    [self.videoList removeAllObjects];
    dateLAB.text = [KHJCalculate nextDay:dateLAB.text];
    [self getTimeLineDataWith:dateLAB.text];
    if (_zeroTimeInterval == _todayTimeInterval) {
        nextDayBtn.hidden = YES;
    }
}

#pragma mark - 选择日历

- (void)chooseDate
{
    JKUIPickDate *pickdate = [JKUIPickDate setDate];
    WeakSelf
    [pickdate passvalue:^(NSString *date) {
        self->dateLAB.text = date;
        [weakSelf chooseDateWith_date:date];
    }];
}

- (void)chooseDateWith_date:(NSString *)date
{
    NSTimeInterval tt       = [KHJCalculate UTCDateFromLocalString2:date];
    NSTimeInterval cTime    = [[NSDate date] timeIntervalSince1970];
    NSTimeInterval ct = _currentTimeInterval - [NSDate getZeroWithTimeInterverl:_currentTimeInterval];
    _currentTimeInterval = tt + ct;
    _zeroTimeInterval = [NSDate getZeroWithTimeInterverl:_currentTimeInterval];
    if (cTime - tt < 24*60*60) {//是当前日期
        nextDayBtn.hidden = _zeroTimeInterval == _todayTimeInterval;
    }
    else {//是之前日期
        [self.videoList removeAllObjects];
        [self getTimeLineDataWith:dateLAB.text];
        nextDayBtn.hidden = _zeroTimeInterval == _todayTimeInterval;
    }
}

#pragma mark - TYCameraTimeLineScrollViewDelegate

- (void)timeLineViewWillBeginDraging:(TYCameraTimeLineScrollView *)timeLineView
{
//    [self.tuyaCamera stopPlayback];
//    CLog(@"开始拖拽 ============================= %f",timeLineView.currentTime);
}

- (void)timeLineViewDidEndDraging:(TYCameraTimeLineScrollView *)timeLineView
{
//    CLog(@"结束拖拽 currentTime ================= %f",timeLineView.currentTime);
//    if (!indicatorView.animating) {
//        indicatorView.hidden = NO;
//        [indicatorView startAnimating];
//    }
}

- (void)timeLineView:(TYCameraTimeLineScrollView *)timeLineView didEndScrollingAtTime:(NSTimeInterval)timeInterval
            inSource:(id<TYCameraTimeLineViewSource>)source
{
//    CLog(@"didEndScrollingAtTime timeInterval = %f",timeInterval);
//    self.currentTimeInterval = _zeroTimeInterval + timeInterval;
//
//    NSDictionary *dict          = self.dictArr[self.index];
//    NSInteger currentEndTime    = [dict[@"endTime"] integerValue] - _zoreTimeStamp;
//    if (_currentTimeStamp < currentEndTime) {
//        [self dragPlayRebackVideo:dict currentTime:_currentTimeStamp index:self.index];
//    }
//    else {
//
//        WeakSelf
//        dispatch_async(dispatch_get_global_queue(0, 0), ^{
//
//            BOOL canPlay = NO;
//            for (int i = 0; i < weakSelf.dictArr.count; i++) {
//
//                NSDictionary *dict          = weakSelf.dictArr[i];
//                NSInteger startTimeStamp    = [dict[@"startTime"] integerValue];
//                NSInteger endTimeStamp      = [dict[@"endTime"] integerValue];
//
//                if (weakSelf.currentTimeStamp < endTimeStamp && weakSelf.currentTimeStamp > startTimeStamp) {
//                    canPlay = YES;
//                    CLog(@"正在播放，第%d段视频",i);
//                    [weakSelf dragPlayRebackVideo:dict currentTime:weakSelf.currentTimeStamp index:(NSInteger)i];
//                    break;
//                }
//            }
//
//            if (!canPlay) {
//                dispatch_async(dispatch_get_main_queue(), ^{
//
//                    if (self->indicatorView.animating) {
//                        self->indicatorView.hidden = YES;
//                        [self->indicatorView stopAnimating];
//                    }
//                    [weakSelf enableAllControl:NO];
//                    [weakSelf.tuyaCamera.videoView tuya_clear];
//                    [weakSelf.view makeToast:KHJLocalizedString(@"TuyaNoVideoPlay", nil)];
//
//                });
//            }
//        });
//    }
}

@end
