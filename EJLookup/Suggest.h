//
//  Suggest.h
//  EJLookup
//
//  Created by Ivan Podogov on 31.10.11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface Suggest : NSOperation {
}

@property(retain) id creator;
@property(retain) NSString *query;

- (id)initWithText:(NSString *)text delegate:(id)target;

@end
