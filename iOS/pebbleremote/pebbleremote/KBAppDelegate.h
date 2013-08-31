//
//  KBAppDelegate.h
//  pebbleremote
//
//  Created by Katharine Berry on 25/05/2013.
//  Copyright (c) 2013 Katharine Berry. All rights reserved.
//

#import <UIKit/UIKit.h>

@class KBiPodRemote;
@class KBViewController;

@interface KBAppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;

@property (strong, nonatomic) KBViewController *viewController;

@property (nonatomic, strong) UINavigationController *navigationController;

@property (nonatomic, strong) KBiPodRemote *remote;

@end
