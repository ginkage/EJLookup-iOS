//
//  main.m
//  EJLookup
//
//  Created by Ivan Podogov on 24.10.11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Nihongo.h"

int main(int argc, char *argv[])
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    [Nihongo initTables];
    int retVal = UIApplicationMain(argc, argv, nil, nil);
    [Nihongo freeTables];
    [pool release];
    return retVal;
}
