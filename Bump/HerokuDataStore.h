//
//  HerokuDataStore.h
//  Bump
//
//  Created by Aleks Kamko on 7/30/13.
//  Copyright (c) 2013 Facebook. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface HerokuDataStore : UIViewController

- (void)registerBumpAtTime:(time_t)bumpTime andGetCloseUsers:(void (^)(NSArray *closeUsers, NSError *error))completionHandler;

@end
