//
//  Nihongo.h
//  EJLookup
//
//  Created by Ivan Podogov on 28.10.11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface Nihongo : NSObject {
}

+ (void)initTables;
+ (void)freeTables;
+ (NSString *)romanateText:(unichar *)text from:(int)begin to:(int)end;
+ (NSString *)kanateText:(unichar *)text ofLength:(int)length;
+ (int)normalizeText:(unichar *)buffer ofLength:(int)length;
+ (bool)letter:(unichar)c;

@end
