//
//  Suggest.m
//  EJLookup
//
//  Created by Ivan Podogov on 31.10.11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "Suggest.h"
#import "Nihongo.h"


@implementation Suggest

@synthesize creator;
@synthesize query;

- (id)initWithText:(NSString *)text delegate:(id)target
{
    if (![super init]) return nil;
    [self setQuery:text];
    [self setCreator:target];
    return self;
}

- (void)dealloc
{
    [query release], query = nil;
    [super dealloc];
}

typedef struct {
    unsigned int pos : 31;
    unsigned int last : 1;
} file_ptr;

- (bool)doTraverse:(NSString *)word index:(NSFileHandle *)fidx from:(long)pos catstr:(NSString *)str output:(NSMutableDictionary *)suglist
{
    if ([self isCancelled]) return false;
    [fidx seekToFileOffset:pos];
    
    NSData *data = [fidx readDataOfLength:6];
    unsigned char const *pdata = data.bytes;
    int tlen = pdata[0];
    int c = pdata[1];
    int freq = *((int32_t *)(pdata + 2));
    bool children = ((c & 1) != 0), unicode = ((c & 8) != 0), exact = ([word length] > 0);
    int match = 0, nlen = 0, wlen = [word length];
    bool res = false;
    file_ptr p;

    if (pos > 0) {
        NSString *nword = @"";
        if (tlen > 0) {
            if (unicode) {
                NSData *data = [fidx readDataOfLength:(2*tlen)];
                unichar const *wbuf = data.bytes;
                nword = [NSString stringWithCharacters:wbuf length:tlen];
            }
            else {
                NSData *data = [fidx readDataOfLength:tlen];
                char const *pdata = data.bytes;
                char wbuf[tlen + 1];
                memcpy(wbuf, pdata, tlen);
                wbuf[tlen] = '\0';
                nword = [NSString stringWithUTF8String:wbuf];
            }
        }
            
        nlen = [nword length];
        str = [str stringByAppendingString:nword];
        
        if (exact) {
            word = [word substringFromIndex:1];
            wlen--;

            while (match < wlen && match < nlen) {
                if ([word characterAtIndex:match] != [nword characterAtIndex:match])
                    break;
                match++;
            }
        }
    }

    if (match == nlen || match == wlen) {
        NSMutableDictionary *cpos = [[NSMutableDictionary alloc] init];
        exact = exact && (match == nlen);

        if (children) // One way or the other, we'll need a full children list
            do { // Read it from this location once, save for later
                NSData *data = [fidx readDataOfLength:6];
                unsigned char const *pdata = data.bytes;
                unichar ch = *((unichar *)(pdata));
                p = *((file_ptr *)(pdata + 2));
                if (match < wlen) { // (match == nlen), Traverse children
                    if (ch == [word characterAtIndex:match]) {
                        NSString *newWord = [word substringFromIndex:match];
                        [cpos dealloc];
                        return [self doTraverse:newWord
                                          index:fidx
                                           from:p.pos
                                         catstr:[str stringByAppendingString:[NSString stringWithCharacters:&ch length:1]]
                                         output:suglist]; // Traverse children
                    }
                }
                else
                    [cpos setObject:[NSNumber numberWithInt:ch] forKey:[NSNumber numberWithInt:p.pos]];
            } while (!p.last);
        
        if (match == wlen) {
            // Our search was successful, word ends here. We'll need all file positions and relatives
            if (freq > 0 && !exact) {
                NSNumber *v = [suglist objectForKey:str];
                if (v == nil)
                    v = [NSNumber numberWithInt:0];
                v = [NSNumber numberWithInt:([v intValue] + freq)];
                [suglist setObject:v forKey:str];
            }
            
            for (NSNumber *it in [[cpos allKeys] sortedArrayUsingComparator:^(id obj1, id obj2) {
                NSNumber *v1 = obj1, *v2 = obj2;
                return (NSComparisonResult)[v1 compare:v2];
            }]) {
                NSNumber *nch = [cpos objectForKey:it];
                unichar ch = [nch intValue];
                [self doTraverse:@""
                           index:fidx
                            from:[it intValue]
                          catstr:[str stringByAppendingString:[NSString stringWithCharacters:&ch length:1]]
                          output:suglist];
            }

            res = true;
        }
        
        [cpos dealloc];
    }
    
    return res;
}

- (int)Tokenize:(unichar *)text length:(int)len index:(NSFileHandle *)fileIdx output:(NSMutableDictionary *)suggest
{
    int p, last = -1;

    for (p = 0; p < len; p++)
        if ([Nihongo letter:text[p]] || (text[p] == '\'' && p > 0 && p+1 < len && [Nihongo letter:text[p-1]] && [Nihongo letter:text[p+1]])) {
            if (last < 0)
                last = p;
        }
        else if (last >= 0)	{
            last = -1;
        }

    if (last >= 0)
        [self doTraverse:[NSString stringWithCharacters:(text+last) length:(p-last)] index:fileIdx from:0 catstr:@"" output:suggest];

    return last;
}

- (bool) isEqual:(unichar *)text of:(int)qlen and:(unichar *)kanatext of:(int)klen
{
    if (qlen != klen)
        return false;
    for (int i=0; i < qlen; ++i)
        if (text[i] != kanatext[i])
            return false;
    return true;
}

- (void)main
{
    int maxsug = 10;
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if (defaults != nil) {
        NSString *str = [defaults stringForKey:@"max_suggest"];
        if (str == nil) {
            [defaults registerDefaults:[NSDictionary dictionaryWithObject:@"10" forKey:@"max_suggest"]];
            [defaults synchronize];
            str = [defaults stringForKey:@"max_suggest"];
        }
        maxsug = [str intValue];
    }

    unichar text[[query length]];
    [query getCharacters:text];
    
    NSString *kanareq = [Nihongo kanateText:text ofLength:[query length]];
    unichar kanatext[[kanareq length]];
    [kanareq getCharacters:kanatext];
    
    int qlen = [Nihongo normalizeText:text ofLength:[query length]];
    int klen = [Nihongo normalizeText:kanatext ofLength:[kanareq length]];
    
    NSMutableDictionary *suggest = [[NSMutableDictionary alloc] init];

    int last = -1;
    
    NSString *idxPath = [[NSBundle mainBundle] pathForResource:@"suggest" ofType:@"dat"];
    NSFileHandle *fileIdx = [NSFileHandle fileHandleForReadingAtPath:idxPath];
    if (fileIdx != nil) {
        last = [self Tokenize:text length:qlen index:fileIdx output:suggest];
        if (![self isEqual:text of:qlen and:kanatext of:klen])
            [self Tokenize:kanatext length:klen index:fileIdx output:suggest];
        [fileIdx closeFile];
    }

    bool romanize = true;
    if (defaults != nil) {
        NSString *str = [defaults stringForKey:@"romaji_suggest"];
        if (str == nil) {
            [defaults registerDefaults:[NSDictionary dictionaryWithObject:@"YES" forKey:@"romaji_suggest"]];
            [defaults synchronize];
            str = [defaults stringForKey:@"romaji_suggest"];
        }
        romanize = [str boolValue];
    }

    NSMutableArray *result = [[NSMutableArray alloc] init];
    
    if ([suggest count] > 0 && ![self isCancelled]) {
        NSMutableSet *duplicate = [[NSMutableSet alloc] init];
        NSString *begin = nil;
        if (last >= 0)
            begin = [query substringToIndex:last];

        for (NSString *str in [[suggest allKeys] sortedArrayUsingComparator:^(id obj1, id obj2) {
            NSString *s1 = obj1, *s2 = obj2;
            NSNumber *v1 = [suggest objectForKey:s1];
            NSNumber *v2 = [suggest objectForKey:s2];
            NSComparisonResult res = (NSComparisonResult)[v2 compare:v1];
            return ((res == NSOrderedSame) ? (NSComparisonResult)[s1 compare:s2] : res);
        }]) {
            if ([result count] >= maxsug) break;
            NSString *k = str;

            if (romanize) {
                bool convert = true;
                for (int i = 0; i < [str length]; ++i)
                    if ([str characterAtIndex:i] >= 0x3200) {
                        convert = false;
                        break;
                    }
                
                if (convert) {
                    unichar txt[[str length]];
                    [str getCharacters:txt];
                    k = [Nihongo romanateText:txt from:0 to:([str length]-1)];
                }
            }

            if (![duplicate containsObject:k]) {
                if (begin != nil)
                    [result addObject:[begin stringByAppendingString:k]];
                else
                    [result addObject:k];
                [duplicate addObject:k];
            }
        }
        
        [duplicate dealloc];
    }
    
    if (![self isCancelled])
        [creator performSelectorOnMainThread:@selector(suggestDone:)
                                  withObject:result
                               waitUntilDone:YES];

    [result dealloc];
    [suggest dealloc];
}

@end
