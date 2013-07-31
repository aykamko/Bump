//
//  BumpViewController.m
//  Bump
//
//  Created by Aleks Kamko on 7/30/13.
//  Copyright (c) 2013 Facebook. All rights reserved.
//

#import "BumpViewController.h"
#import <CoreMotion/CoreMotion.h>
#import <FacebookSDK/FacebookSDK.h>
#import "HerokuDataStore.h"

@interface BumpViewController ()

@property (nonatomic, strong) HerokuDataStore *heroku;

@property (nonatomic, strong) CMMotionManager *motionManager;
@property (nonatomic, strong) NSOperationQueue *accelerometerQueue;

@property (nonatomic, strong) IBOutlet UIButton *facebookButton;
@property (nonatomic, strong) IBOutlet UIButton *bumpButton;
- (IBAction)startAccelerometer:(id)sender;
- (IBAction)facebookButtonPressed:(id)sender;

@property (nonatomic) BOOL isBumping;

@property (nonatomic, strong) NSMutableArray *accelData;
@property (nonatomic) BOOL thresholdReached;
@property (nonatomic) int hitsBelowThreshold;

@end

@implementation BumpViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        _bumpButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
        [_bumpButton setFrame:CGRectMake(0, 0, 260, 50)];
        [_bumpButton setBackgroundColor:[UIColor colorWithRed:0 green:0 blue:1 alpha:0.1]];
        [_bumpButton setCenter:self.view.center];
        [_bumpButton setTitle:@"Bump!" forState:UIControlStateNormal];
        [_bumpButton addTarget:self
                        action:@selector(startAccelerometer:)
              forControlEvents:UIControlEventTouchUpInside];
        _accelData = [[NSMutableArray alloc] init];
        
        _facebookButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
        [_facebookButton setFrame:CGRectMake(0, 0, 260, 50)];
        [_facebookButton setBackgroundColor:[UIColor colorWithRed:0 green:0 blue:1 alpha:0.1]];
        [_facebookButton setCenter:CGPointMake(self.view.center.x, self.view.center.y - 60)];
        
        if ([[FBSession activeSession] isOpen]) {
            [_facebookButton setTitle:@"Log Out" forState:UIControlStateNormal];
        } else {
            [_facebookButton setTitle:@"Log In" forState:UIControlStateNormal];
        }
        
        [_facebookButton addTarget:self
                            action:@selector(facebookButtonPressed:)
                  forControlEvents:UIControlEventTouchUpInside];
        [self.view addSubview:_facebookButton];
    }
    return self;
}

- (void)facebookButtonPressed:(id)sender
{
    if ([[FBSession activeSession] isOpen]) {
        [[FBSession activeSession] closeAndClearTokenInformation];
        [_bumpButton removeFromSuperview];
        [_facebookButton setTitle:@"Log In" forState:UIControlStateNormal];
    } else {
        [FBSession openActiveSessionWithReadPermissions:nil
                                           allowLoginUI:YES
                                      completionHandler:^(FBSession *session, FBSessionState status, NSError *error) {
                                              [self.view addSubview:_bumpButton];
                                          [_facebookButton setTitle:@"Log Out" forState:UIControlStateNormal];
                                      }];
    }
}

- (IBAction)startAccelerometer:(id)sender
{
    
    if ([self isBumping] == NO) {
        [_bumpButton setTitle:@"Stop Bump" forState:UIControlStateNormal];
        _motionManager = [[CMMotionManager alloc] init];
        _motionManager.accelerometerUpdateInterval = 0.01f;
        
        _accelerometerQueue = [[NSOperationQueue alloc] init];
        
        [_motionManager startAccelerometerUpdatesToQueue:_accelerometerQueue withHandler:^(CMAccelerometerData *accelerometerData, NSError *error) {
            if (error) {
                NSLog(@"error");
            } else {
                dispatch_sync(dispatch_get_main_queue(), ^{
                    if ([self isBumping] == NO)
                        [self setIsBumping:YES];
                    double xAccel = accelerometerData.acceleration.x;
                    double yAccel = accelerometerData.acceleration.y;
                    double zAccel = accelerometerData.acceleration.z;
                    double vectorMagnitude = sqrt((xAccel * xAccel) + (yAccel * yAccel) + (zAccel * zAccel));
                    if (vectorMagnitude > 1.4) {
                        if (_thresholdReached == NO)
                            _thresholdReached = YES;
                            [_accelData addObject:@(vectorMagnitude)];
                    } else {
                        if (_thresholdReached == YES) {
                            _hitsBelowThreshold++;
                            if (_hitsBelowThreshold > 100) {
                                [self logIfArrayIsBump:_accelData time:accelerometerData.timestamp];
                                _accelData = [[NSMutableArray alloc] init];
                                _thresholdReached = NO;
                            }
                        } else {
                            _hitsBelowThreshold = 0;
                        }
                    }
                });
            }
        }];
    } else {
        [_motionManager stopAccelerometerUpdates];
        _accelerometerQueue = nil;
        _motionManager = nil;
        [_bumpButton setTitle:@"Bump!" forState:UIControlStateNormal];
    }
}

- (void)logIfArrayIsBump:(NSArray *)dataPoints time:(double)time
{
    if ([dataPoints count] > 12)
        return;
    
    NSNumber* min = [dataPoints valueForKeyPath:@"@min.self"];
    NSNumber* max = [dataPoints valueForKeyPath:@"@max.self"];
    
    double minDouble = [min doubleValue];
    double maxDouble = [max doubleValue];
    
    double difference = maxDouble - minDouble;
    if (difference < 2.4f) {
        NSLog(@"bumped at time: %f", CFAbsoluteTimeGetCurrent());
        _heroku = [[HerokuDataStore alloc] init];
        [_motionManager stopAccelerometerUpdates];
        [_heroku registerBumpAtTime:[[NSDate date] timeIntervalSince1970] andGetCloseUsers:nil];
    }
    
}

@end
