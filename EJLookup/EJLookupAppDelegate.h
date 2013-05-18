//
//  EJLookupAppDelegate.h
//  EJLookup
//
//  Created by Ivan Podogov on 24.10.11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "EJLViewController.h"

@interface EJLookupAppDelegate : NSObject <UIApplicationDelegate> {
}

@property (nonatomic, retain) IBOutlet UIWindow *window;
@property (nonatomic, retain) IBOutlet EJLViewController *ejlViewController;

@end
