//
//  KHJChangePasswordVC.m
//  SuperIPC
//
//  Created by 王涛 on 2020/1/18.
//  Copyright © 2020年 王涛. All rights reserved.
//

#import "KHJChangePasswordVC.h"

@interface KHJChangePasswordVC ()
{
    __weak IBOutlet UITextField *oldtf;
    __weak IBOutlet UITextField *newtf;
    __weak IBOutlet UITextField *suretf;
}
@end

@implementation KHJChangePasswordVC

- (void)viewDidLoad {
    [super viewDidLoad];
    if (self.isFinderPassword) {
        self.titleLab.text = KHJLocalizedString(@"chagPwd_", nil);
    }
    else {
        self.titleLab.text = KHJLocalizedString(@"APPwd_", nil);
        oldtf.placeholder = KHJLocalizedString(@"APPDeftNull_", nil);
    }
    [self.leftBtn addTarget:self action:@selector(backAction) forControlEvents:UIControlEventTouchUpInside];
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    [self.view endEditing:YES];
}

- (void)backAction
{
    [self.navigationController popViewControllerAnimated:YES];
}

- (IBAction)btn:(UIButton *)sender
{
    if (sender.tag == 10) {
        TLog(@"确定");
    }
    else if (sender.tag == 20) {
        TLog(@"取消");
    }
}

@end
