//
//  KBViewController.h
//  pebbleremote
//
//  Created by Katharine Berry on 25/05/2013.
//  Copyright (c) 2013 Katharine Berry. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface KBViewController : UIViewController <UINavigationControllerDelegate, UIImagePickerControllerDelegate>

-(void)initiateCamera;
-(void) removeCameraWindow;
-(void)operateCamera:(NSInteger)operationKey;
@end
