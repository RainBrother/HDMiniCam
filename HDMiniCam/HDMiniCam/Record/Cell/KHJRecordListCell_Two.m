//
//  KHJRecordListCell_Two.m
//  HDMiniCam
//
//  Created by khj888 on 2020/3/4.
//  Copyright © 2020 王涛. All rights reserved.
//

#import "KHJRecordListCell_Two.h"
#import "KHJHelpCameraData.h"

@implementation KHJRecordListCell_Two

- (void)awakeFromNib
{
    [super awakeFromNib];
}

- (void)setDeviceID:(NSString *)deviceID
{
    NSString *imagePath     = [[[KHJHelpCameraData sharedModel] get_screenShot_DocPath_deviceID:deviceID] stringByAppendingPathComponent:KHJString(@"%@.png",self.date)];
    self.picImgView.image   = [UIImage imageWithContentsOfFile:imagePath];
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

- (IBAction)btnAction:(UIButton *)sender
{
    if (_delegate && [_delegate respondsToSelector:@selector(chooseDateWith:)]) {
        [_delegate chooseDateWith:self.tag - FLAG_TAG];
    }
}

@end