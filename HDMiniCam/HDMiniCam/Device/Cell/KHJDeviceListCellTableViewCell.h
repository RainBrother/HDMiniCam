//
//  KHJDeviceListCellTableViewCell.h
//  HDMiniCam
//
//  Created by khj888 on 2020/1/15.
//  Copyright © 2020 王涛. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface KHJDeviceListCellTableViewCell : KHJBaseCell

@property (weak, nonatomic) IBOutlet UIImageView *bigIMGV;
@property (weak, nonatomic) IBOutlet UIImageView *smalIMGV;
@property (weak, nonatomic) IBOutlet UILabel *name;
@property (weak, nonatomic) IBOutlet UILabel *status;
@property (weak, nonatomic) IBOutlet UILabel *idd;

@end

NS_ASSUME_NONNULL_END
