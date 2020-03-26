//
//  AppDelegate.m
//  SuperIPC
//
//  Created by 王涛 on 2020/1/12.
//  Copyright © 2020年 王涛. All rights reserved.
//

#import "AppDelegate.h"
#import "KHJDeviceListVC.h"
#import "KHJBaseNavigationController.h"
#import "KHJPictureListVC.h"
#import "KHJRecordListVC.h"
#import "KHJVideoPlayer_hf_VC.h"
#pragma mark - ios13 开启地理位置权限，获取Wi-Fi名称
#import <CoreLocation/CoreLocation.h>
#import "TTFirmwareInterface_API.h"
#import "KHJDataBase.h"
#import "AFNetworkReachabilityManager.h"

@interface AppDelegate ()<CLLocationManagerDelegate>

@property (nonatomic, strong) CLLocationManager *locationManager;

@end

@implementation AppDelegate

- (CLLocationManager *)locationManager
{
    if (_locationManager == nil) {
        _locationManager = [[CLLocationManager alloc] init];
    }
    return _locationManager;
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    #pragma mark - 启动时，调动底层
    KHJDataBase *db = [KHJDataBase sharedDataBase];
    [db initDataBase];
    NSArray *list = [[KHJDataBase sharedDataBase] getAllDeviceInfo];
    for (int i = 0; i < list.count; i++) {
        KHJDeviceInfo *info = [[KHJDeviceInfo alloc] init];
        info = list[i];
        [[TTFirmwareInterface_API sharedManager] connect_with_deviceID:info.deviceID password:info.devicePassword reBlock:^(NSInteger code) {}];
    }

    // 如果是iOS13 未开启地理位置权限 需要提示一下
    if ([[UIDevice currentDevice] systemVersion].floatValue >= 13) {
        [self.locationManager requestWhenInUseAuthorization];
    }
    [self initHomeView];
    
    [self checkNetworking];
    return YES;
}

- (void)initHomeView
{
    //三个导航栏控制器，注意标题问题
    AppDelegate * appDelegate = (AppDelegate *)[UIApplication sharedApplication].delegate;
    if (appDelegate.rootTabBarVC) {
        [UIApplication sharedApplication].delegate.window.rootViewController = nil;
        appDelegate.rootTabBarVC = nil;
    }
    KHJTabBarBaseVC * tabbar = [[KHJTabBarBaseVC alloc] init];
    appDelegate.rootTabBarVC = tabbar;//关闭横屏仅允许竖屏
    
    KHJDeviceListVC *vc1 = [[KHJDeviceListVC alloc] init];
    KHJBaseNavigationController *deviceListNavi = [[KHJBaseNavigationController  alloc] initWithRootViewController:vc1];
    deviceListNavi.tabBarItem.title = KHJLocalizedString(@"vide_", nil);
    
    KHJPictureListVC *vc2 = [[KHJPictureListVC alloc] init];
    KHJBaseNavigationController *pictureNavi = [[KHJBaseNavigationController  alloc] initWithRootViewController:vc2];
    pictureNavi.tabBarItem.title = KHJLocalizedString(@"pic_", nil);
    
    KHJRecordListVC *vc3 = [[KHJRecordListVC alloc] init];
    KHJBaseNavigationController *recordNavi = [[KHJBaseNavigationController  alloc] initWithRootViewController:vc3];
    recordNavi.tabBarItem.title = KHJLocalizedString(@"recrd_", nil);
    
    [deviceListNavi.tabBarItem setTitleTextAttributes:@{NSForegroundColorAttributeName:TTCommon.appMainColor}
                                             forState:UIControlStateSelected];
    [deviceListNavi.tabBarItem setTitleTextAttributes:@{NSForegroundColorAttributeName:UIColor.blackColor}
                                             forState:UIControlStateNormal];
    [pictureNavi.tabBarItem setTitleTextAttributes:@{NSForegroundColorAttributeName:TTCommon.appMainColor}
                                          forState:UIControlStateSelected];
    [pictureNavi.tabBarItem setTitleTextAttributes:@{NSForegroundColorAttributeName:UIColor.blackColor}
                                          forState:UIControlStateNormal];
    [recordNavi.tabBarItem setTitleTextAttributes:@{NSForegroundColorAttributeName:TTCommon.appMainColor}
                                         forState:UIControlStateSelected];
    [recordNavi.tabBarItem setTitleTextAttributes:@{NSForegroundColorAttributeName:UIColor.blackColor}
                                         forState:UIControlStateNormal];
    [tabbar setViewControllers:@[deviceListNavi, pictureNavi, recordNavi]];
    
    pictureNavi.tabBarItem.image            = [KHJIMAGE(@"picture_n") imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
    pictureNavi.tabBarItem.selectedImage    = [KHJIMAGE(@"picture_s") imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal] ;
    recordNavi.tabBarItem.image             = [KHJIMAGE(@"record_n") imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
    recordNavi.tabBarItem.selectedImage     = [KHJIMAGE(@"record_s") imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
    deviceListNavi.tabBarItem.image         = [KHJIMAGE(@"video_n") imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
    deviceListNavi.tabBarItem.selectedImage = [KHJIMAGE(@"video_s") imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
    [UIApplication sharedApplication].delegate.window.rootViewController = appDelegate.rootTabBarVC;
    [self.window makeKeyAndVisible];
}

- (void)applicationWillResignActive:(UIApplication *)application {
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
}


- (void)applicationDidEnterBackground:(UIApplication *)application {
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}


- (void)applicationWillEnterForeground:(UIApplication *)application {
    // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
}


- (void)applicationDidBecomeActive:(UIApplication *)application {
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}


- (void)applicationWillTerminate:(UIApplication *)application {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

#pragma mark - 监听手机 “横屏、竖屏” 状态

- (UIInterfaceOrientationMask)application:(UIApplication *)application supportedInterfaceOrientationsForWindow:(nullable UIWindow *)window
{
    if (self.canLandscape)  {
        /* 横屏 */
        return UIInterfaceOrientationMaskLandscape;
    }
    else {
        /* 竖屏 */
        return UIInterfaceOrientationMaskPortrait;
    }
}

// 是否支持设备自动旋转

- (BOOL)shouldAutorotate
{
    if (self.canLandscape == YES) {
        //为1的话,支持旋转
        return YES;
    }
    return NO;
}

- (void)checkNetworking
{
    [[AFNetworkReachabilityManager sharedManager] startMonitoring];
    [[AFNetworkReachabilityManager sharedManager] setReachabilityStatusChangeBlock:^(AFNetworkReachabilityStatus status) {
        switch (status) {
            case -1:
                TLog(@"---------------------------------------------------- 未知网络");
                break;
            case 0:
                TLog(@"---------------------------------------------------- 网络不可达");
                break;
            case 1:
                TLog(@"---------------------------------------------------- GPRS网络");
                break;
            case 2:
                TLog(@"---------------------------------------------------- wifi网络");
                break;
            default:
                break;
        }
        if (status == AFNetworkReachabilityStatusReachableViaWWAN
           || status == AFNetworkReachabilityStatusReachableViaWiFi) {
            TLog(@"有网");
            [[NSNotificationCenter defaultCenter] postNotificationName:@"netStateChange" object:@"手机有网络"];
        }
        else {
            TLog(@"没网");
            [[NSNotificationCenter defaultCenter] postNotificationName:@"netStateChange" object:@"手机无网络"];
        }
    }];
}

@end
