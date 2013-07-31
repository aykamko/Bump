//
//  HerokuDataStore.m
//  Bump
//
//  Created by Aleks Kamko on 7/30/13.
//  Copyright (c) 2013 Facebook. All rights reserved.
//

#import "HerokuDataStore.h"
#import <FacebookSDK/FacebookSDK.h>
#import <CoreLocation/CoreLocation.h>

@interface HerokuDataStore () <CLLocationManagerDelegate>

@property (nonatomic, strong) NSString *myId;
@property (nonatomic, strong) NSString *myName;

@property (nonatomic) double bumpTime;
@property (nonatomic, strong) CLLocationManager *locationManager;
@property (nonatomic, copy) void (^completionHandler)(NSDictionary *closeUsers, NSError *error);

@end

@implementation HerokuDataStore

- (void)registerBumpAtTime:(time_t)bumpTime andGetCloseUsers:(void (^)(NSDictionary *closeUsers, NSError *error))completionHandler
{
    _bumpTime = bumpTime;
    _completionHandler = completionHandler;
    
    [FBRequestConnection startWithGraphPath:@"me?fields=id,name" completionHandler:^(FBRequestConnection *connection, id result, NSError *error) {
        if (error) {
            UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Error!"
                                                                message:error.localizedDescription
                                                               delegate:nil
                                                      cancelButtonTitle:@"OK :("
                                                      otherButtonTitles: nil];
            [alertView show];
        } else {
            _myId = result[@"id"];
            _myName = result[@"name"];
            NSLog(@"\nFacebook ID: %@\nName: %@", _myId, _myName);
            _locationManager = [[CLLocationManager alloc] init];
            [_locationManager setDelegate:self];
            [_locationManager setDesiredAccuracy:kCLLocationAccuracyBest];
            [_locationManager startUpdatingLocation];
        }
    }];
    
}

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations
{
    [_locationManager stopUpdatingLocation];
    CLLocation *location = [locations firstObject];
    CLLocationCoordinate2D coordinate = [location coordinate];
    NSLog(@"\nLatitude: %f\nLongitude: %f", coordinate.latitude, coordinate.longitude);
    NSString *safeName = [_myName stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    
    NSString *herokuURLString = [NSString stringWithFormat:
                                 @"http://hack38.herokuapp.com/?fbid=%@&name=%@&geo=%f,%f&timestamp=%f",
                                 _myId,
                                 safeName,
                                 coordinate.longitude,
                                 coordinate.latitude,
                                 _bumpTime];
    
    NSLog(@"\n%@", herokuURLString);
    
    NSURL *herokuURL = [NSURL URLWithString:herokuURLString];
    NSURLRequest *request = [NSURLRequest requestWithURL:herokuURL];
    
    [NSURLConnection sendAsynchronousRequest:request
                                       queue:[NSOperationQueue mainQueue]
                           completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError) {
                               if (connectionError) {
                                   NSLog(@"error: %@", connectionError.localizedDescription);
                               } else {
                                   NSError *jsonError;
                                   NSDictionary *resultDict = [NSJSONSerialization JSONObjectWithData:data
                                                                                              options:NSJSONReadingMutableContainers
                                                                                                error:&jsonError];
                                   NSLog(@"%@", resultDict);
                               }
                           }];
}

@end
