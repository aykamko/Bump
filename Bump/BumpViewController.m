//
//  BumpViewController.m
//  Bump
//
//  Created by Aleks Kamko on 7/30/13.
//  Copyright (c) 2013 Facebook. All rights reserved.
//

#define kUpdateFrequency         100.0
#define kAccelerationThreshold   1.4
#define kDifferenceThreshold     3.0

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
        [_bumpButton setFrame:CGRectMake(0, 0, 280, 350)];
        [_bumpButton setBackgroundColor:[UIColor colorWithRed:0 green:0 blue:1 alpha:0.1]];
        [_bumpButton setTitle:@"Bump!" forState:UIControlStateNormal];
        [_bumpButton addTarget:self
                        action:@selector(startAccelerometer:)
              forControlEvents:UIControlEventTouchUpInside];
        _accelData = [[NSMutableArray alloc] init];
        
        _facebookButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
        [_facebookButton setFrame:CGRectMake(0, 0, 280, 60)];
        [_facebookButton setBackgroundColor:[UIColor colorWithRed:0 green:0 blue:1 alpha:0.1]];
        [_facebookButton setCenter:CGPointMake(self.view.center.x, self.view.center.y)];
        
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

- (void)viewDidLoad
{
    if ([[FBSession activeSession] isOpen]) {
        CGPoint newCenter = CGPointMake(self.view.center.x, self.view.center.y - 215);
        [_facebookButton setTitle:@"Log Out" forState:UIControlStateNormal];
        [_facebookButton setCenter:newCenter];
        [self.view addSubview:_bumpButton];
    }
}

- (void)facebookButtonPressed:(id)sender
{
    if ([[FBSession activeSession] isOpen]) {
        [[FBSession activeSession] closeAndClearTokenInformation];
        [UIView animateWithDuration:0.4
                         animations:^{
                             CGFloat xPos = (self.view.bounds.size.width - _bumpButton.bounds.size.width) / 2.0;
                             CGPoint newOrigin = CGPointMake(xPos, UIScreen.mainScreen.bounds.size.height);
                             CGRect newFrame = CGRectMake(newOrigin.x, newOrigin.y, _bumpButton.frame.size.width, _bumpButton.frame.size.height);
                             
                             [_facebookButton setTitle:@"Log In" forState:UIControlStateNormal];
                             [_facebookButton setCenter:self.view.center];
                             [_bumpButton setFrame:newFrame];
                         } completion:^(BOOL finished) {
                             [_bumpButton removeFromSuperview];
                         }];
    } else {
        [FBSession openActiveSessionWithReadPermissions:nil
                                           allowLoginUI:YES
                                      completionHandler:^(FBSession *session, FBSessionState status, NSError *error) {
          [UIView animateWithDuration:0.4
                           animations:^{
                               
                               CGFloat xPos = (self.view.bounds.size.width - _bumpButton.bounds.size.width) / 2.0;
                               CGPoint newOrigin = CGPointMake(xPos, UIScreen.mainScreen.bounds.size.height);
                               CGRect newFrame = CGRectMake(newOrigin.x, newOrigin.y, _bumpButton.frame.size.width, _bumpButton.frame.size.height);
                               [_bumpButton setFrame:newFrame];
                               [self.view addSubview:_bumpButton];
                               
                               CGPoint fbButtonCenter = CGPointMake(self.view.center.x, self.view.center.y - 215);
                               CGPoint bumpButtonCenter = self.view.center;
                               [_facebookButton setTitle:@"Log Out" forState:UIControlStateNormal];
                               [_facebookButton setCenter:fbButtonCenter];
                               [_bumpButton setCenter:bumpButtonCenter];
                           }];
                                      }];
    }
}

- (IBAction)startAccelerometer:(id)sender
{
    
    if ([self isBumping] == NO) {
        [_bumpButton setTitle:@"Stop Bump" forState:UIControlStateNormal];
        _motionManager = [[CMMotionManager alloc] init];
        _motionManager.accelerometerUpdateInterval = 1.0 / kUpdateFrequency;
        
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
                    if (vectorMagnitude > kAccelerationThreshold) {
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
        [_bumpButton setTitle:@"Bump!" forState:UIControlStateNormal];
        [self setIsBumping:NO];
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
    if (difference < kDifferenceThreshold) {
        NSLog(@"bumped at time: %f", CFAbsoluteTimeGetCurrent());
        
        [_motionManager stopAccelerometerUpdates];
        
        [_bumpButton setTitle:nil forState:UIControlStateNormal];
        __block UIActivityIndicatorView *spinner = [[UIActivityIndicatorView alloc]
                                            initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
        
        spinner.center = _bumpButton.center;
        [self.view addSubview:spinner];
        [spinner startAnimating];
        
        _heroku = [[HerokuDataStore alloc] init];
        [_heroku registerBumpAtTime:[[NSDate date] timeIntervalSince1970] andGetCloseUsers:^(NSArray *closeUsers, NSError *error) {
            [spinner stopAnimating];
            [spinner removeFromSuperview];
            [_bumpButton setTitle:@"Bump!" forState:UIControlStateNormal];
            [self setIsBumping:NO];
            if (error) {
                NSLog(@"Error: %@", error.localizedDescription);
            } else {
                if ([closeUsers count] == 0) {
                    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Sorry!"
                                                                        message:@"We couldn't find any Facebook users that matched your bump."
                                                                       delegate:self
                                                              cancelButtonTitle:@"Bump again!"
                                                              otherButtonTitles:nil];
                    [alertView show];
                    return;
                }
                
                NSDictionary *closestUser = [closeUsers firstObject];
                
                NSString *bumpedID = closestUser[@"fbid"];
                NSString *facebookPageURL = [NSString stringWithFormat:@"fb://profile/%@",
                                             bumpedID];
                NSURL *url = [NSURL URLWithString:facebookPageURL];
                
                if (![[UIApplication sharedApplication] openURL:url])
                    NSLog(@"%@%@",@"Failed to open url:",[url description]);
                
            }
        }];
    }
    
}

@end
