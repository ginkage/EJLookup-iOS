//
//  DictionarySearch.h
//  EJLookup
//
//  Created by Ivan Podogov on 31.10.11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface DictionarySearch : NSOperation {
    int maxres;
}

@property(retain) id creator;
@property(retain) NSString *request;

- (id)initWithText:(NSString *)text delegate:(id)target;

@end
