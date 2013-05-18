//
//  ResultLine.h
//  EJLookup
//
//  Created by Ivan Podogov on 27.10.11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface ResultLine : NSObject {
}

- (void)initWithText:(NSString *)text dictName:(NSString *)dict;

@property (nonatomic, retain) NSAttributedString *data;
@property (nonatomic, retain) NSString *group;
@property (nonatomic, assign) int height;

@end
