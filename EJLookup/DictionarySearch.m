//
//  DictionarySearch.m
//  EJLookup
//
//  Created by Ivan Podogov on 31.10.11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "DictionarySearch.h"
#import "Nihongo.h"
#import "ResultLine.h"

@implementation DictionarySearch

@synthesize creator;
@synthesize request;

static NSString *fileList[] = {
    @"jr-edict",
    @"warodai",
    @"edict",
    @"kanjidic",
    @"ediclsd4",
    @"classical",
    @"compverb",
    @"compdic",
    @"lingdic",
    @"jddict",
    @"4jword3",
    @"aviation",
    @"buddhdic",
    @"engscidic",
    @"envgloss",
    @"findic",
    @"forsdic_e",
    @"forsdic_s",
    @"geodic",
    @"lawgledt",
    @"manufdic",
    @"mktdic",
    @"pandpdic",
    @"stardict",
    @"concrete"//,
//	@"j_places",
//	@"enamdict",
//	@"ginkage"
};

- (id)initWithText:(NSString *)text delegate:(id)target
{
    if (![super init]) return nil;
    [self setRequest:text];
    [self setCreator:target];
    return self;
}

- (void)dealloc
{
    [request release], request = nil;
    [super dealloc];
}

typedef struct {
    unsigned int pos : 31;
    unsigned int last : 1;
} file_ptr;

- (bool)doTraverse:(NSString *)word index:(NSFileHandle *)fidx at:(long)pos part:(bool)partial deepen:(bool)child output:(NSMutableDictionary *)poslist
{
    if ([self isCancelled]) return false;
    [fidx seekToFileOffset:pos];

    NSData *data = [fidx readDataOfLength:2];
    unsigned char const *pdata = data.bytes;
    int tlen = pdata[0];
    int c = pdata[1];
    bool children = ((c & 1) != 0), filepos = ((c & 2) != 0), parents = ((c & 4) != 0), unicode = ((c & 8) != 0), exact = ([word length] > 0);
    int match = 0, nlen = 0, wlen = [word length];
    bool res = false;
    file_ptr p;

    if (!exact)
        [fidx seekToFileOffset:(pos + 2 + (unicode ? (tlen * 2) : tlen))];
    else if (pos > 0) {
        word = [word substringFromIndex:1];
        wlen--;
        
        if (tlen > 0) {
            NSString *nword = nil;

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
            
            nlen = [nword length];
            
            while (match < wlen && match < nlen) {
                if ([word characterAtIndex:match] != [nword characterAtIndex:match])
                    break;
                match++;
            }
        }
    }

    if (match == nlen || match == wlen) {
        NSMutableArray *cpos = [[NSMutableArray alloc] init];
        
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
                        return [self doTraverse:newWord index:fidx at:p.pos part:partial deepen:true output:poslist]; // Traverse children
                    }
                }
                else if (partial && child)
                    [cpos addObject:[NSNumber numberWithInt:p.pos]];
            } while (!p.last);

        if (match == wlen) {
            // Our search was successful, word ends here. We'll need all file positions and relatives
            exact = exact && (match == nlen);
            if (filepos && (match == nlen || partial)) { // Gather all results from this node
                do {
                    NSData *data = [fidx readDataOfLength:4];
                    p = *((file_ptr *)data.bytes);
                    NSNumber *k = [NSNumber numberWithInt:p.pos];
                    NSNumber *v = [poslist objectForKey:k];
                    if (v == nil || (![v boolValue] && exact))
                        [poslist setObject:[NSNumber numberWithBool:exact] forKey:k];
                } while (!p.last);
            }

            if (partial) {
                NSMutableArray *ppos = [[NSMutableArray alloc] init];

                if (parents) // One way or the other, we'll need a full parents list
                    do { // Read it from this location once, save for later
                        NSData *data = [fidx readDataOfLength:4];
                        p = *((file_ptr *)data.bytes);
                        [ppos addObject:[NSNumber numberWithInt:p.pos]];
                    } while (!p.last);

                if (child)
                    for (NSNumber *it in cpos) // Traverse everything that begins with this word
                        [self doTraverse:@"" index:fidx at:[it intValue] part:partial deepen:true output:poslist];

                for (NSNumber *it in ppos) // Traverse everything that fully has this word in it
                    [self doTraverse:@"" index:fidx at:[it intValue] part:partial deepen:false output:poslist];

                [ppos dealloc];
            }

            res = true;
        }

        [cpos dealloc];
    }

    return res;
}

- (void)doSearch:(NSString *)query words:(int)wnum index:(NSFileHandle *)fileIdx exact:(NSMutableDictionary *)exact partial:(NSMutableDictionary *)partial kanji:(bool)kanji
{
    int mask = 1 << wnum;
    NSMutableDictionary *lines = [[NSMutableDictionary alloc] init];
    [self doTraverse:query index:fileIdx at:0 part:([query length] > 1 || kanji) && (partial != nil) deepen:true output:lines];
    for (NSNumber *k in [lines allKeys]) {
        NSNumber *e = [lines objectForKey:k];
        NSNumber *v = ([e boolValue] ? [exact objectForKey:k] : (partial == nil ? nil : [partial objectForKey:k]));
        if (v == nil)
            v = [NSNumber numberWithInt:0];
        v = [NSNumber numberWithInt:([v intValue] | mask)];
        if ([e boolValue])
            [exact setObject:v forKey:k];
        else if (partial != nil)
            [partial setObject:v forKey:k];
    }
    [lines dealloc];
}

- (int)Tokenize:(unichar *)text of:(int)len index:(NSFileHandle *)fileIdx exact:(NSMutableDictionary *)exact partial:(NSMutableDictionary *)partial
{
    int p, last = -1, wnum = 0;
    bool kanji = false;

    for (p = 0; p < len; p++)
        if ([Nihongo letter:text[p]] || (text[p] == '\'' && p > 0 && p+1 < len && [Nihongo letter:text[p-1]] && [Nihongo letter:text[p+1]])) {
            if (last < 0)
                last = p;
            if (text[p] >= 0x3200)
                kanji = true;
        }
        else if (last >= 0)	{
            [self doSearch:[NSString stringWithCharacters:(text+last) length:(p-last)] words:wnum++ index:fileIdx exact:exact partial:partial kanji:kanji];
            kanji = false;
            last = -1;
        }

    if (last >= 0)
        [self doSearch:[NSString stringWithCharacters:(text+last) length:(p-last)] words:wnum++ index:fileIdx exact:exact partial:partial kanji:kanji];
    
    return wnum;
}

- (NSString *)readLineFrom:(NSFileHandle *)file atOffset:(int)offset
{
    int len;
    char line[8192];
    [file seekToFileOffset:offset];
    NSData *data = [file readDataOfLength:8192];
    char const *pdata = data.bytes;
    for (len = 0; len < data.length; len++) {
        line[len] = pdata[len];
        if (line[len] == '\n' || line[len] == '\r')
            break;
    }
    line[len] = '\0';
    return [NSString stringWithUTF8String:line];
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

- (void)lookupDict:(NSString *)fileName exact:(NSMutableSet *)sexact partial:(NSMutableSet *)spartial roma:(unichar *)text of:(int)qlen kana:(unichar *)kanatext of:(int)klen
{
    if ([self isCancelled]) return;

    NSString *idxPath = [[NSBundle mainBundle] pathForResource:fileName ofType:@"idx"];
    NSString *utfPath = [[NSBundle mainBundle] pathForResource:fileName ofType:@"utf"];
    NSFileHandle *fileIdx = [NSFileHandle fileHandleForReadingAtPath:idxPath];
    NSFileHandle *fileDic = [NSFileHandle fileHandleForReadingAtPath:utfPath];

    if (fileIdx != nil && fileDic != nil) {
        NSMutableDictionary *elines = [[NSMutableDictionary alloc] init];
        NSMutableDictionary *plines = nil;

        if (spartial != nil)
            plines = [[NSMutableDictionary alloc] init];

        int qwnum = [self Tokenize:text of:qlen index:fileIdx exact:elines partial:plines];
        if (![self isEqual:text of:qlen and:kanatext of:klen]) {
            int kwnum = [self Tokenize:kanatext of:klen index:fileIdx exact:elines partial:plines];
            if (qwnum < kwnum) qwnum = kwnum;
        }

        NSMutableSet *spos = [[NSMutableSet alloc] init];

        for (NSNumber *line in [elines allKeys]) {
            NSNumber *mask = [elines objectForKey:line];
            if ([mask intValue] + 1 == 1 << qwnum) {
                [spos addObject:line];
                if (plines != nil)
                    [plines removeObjectForKey:line];
            }
            else if (plines != nil) {
                NSNumber *pmask = [plines objectForKey:line];
                if (pmask != nil && (([mask intValue] | [pmask intValue]) != [pmask intValue]))
                    [plines setObject:[NSNumber numberWithInt:([mask intValue] | [pmask intValue])] forKey:line];
            }
        }

        for (NSNumber *it in [[spos allObjects] sortedArrayUsingComparator:^(id obj1, id obj2) {
            NSNumber *v1 = obj1, *v2 = obj2;
            return (NSComparisonResult)[v1 compare:v2];
        }]) {
            if ([sexact count] >= maxres) break;
            [sexact addObject:[self readLineFrom:fileDic atOffset:[it intValue]]];
        }

        if (plines != nil) {
            [spos removeAllObjects];

            for (NSNumber *line in [plines allKeys]) {
                NSNumber *mask = [plines objectForKey:line];
                if ([mask intValue] + 1 == 1 << qwnum)
                    [spos addObject:line];
            }

            for (NSNumber *it in [[spos allObjects] sortedArrayUsingComparator:^(id obj1, id obj2) {
                NSNumber *v1 = obj1, *v2 = obj2;
                return (NSComparisonResult)[v1 compare:v2];
            }]) {
                if ([sexact count] + [spartial count] >= maxres) break;
                [spartial addObject:[self readLineFrom:fileDic atOffset:[it intValue]]];
            }
        }

        [spos dealloc];
        [elines dealloc];
        if (plines != nil)
            [plines dealloc];
    }

    if (fileIdx != nil)
        [fileIdx closeFile];
    if (fileDic != nil)
        [fileDic closeFile];
}

- (void)main
{
    maxres = 100;
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if (defaults != nil) {
        NSString *str = [defaults stringForKey:@"max_results"];
        if (str == nil) {
            [defaults registerDefaults:[NSDictionary dictionaryWithObject:@"100" forKey:@"max_results"]];
            [defaults synchronize];
            str = [defaults stringForKey:@"max_results"];
        }
        maxres = [str intValue];
    }

    int dictNum = sizeof(fileList) / sizeof(fileList[0]);

    unichar text[[request length]];
    [request getCharacters:text];

    NSString *kanareq = [Nihongo kanateText:text ofLength:[request length]];
    unichar kanatext[[kanareq length]];
    [kanareq getCharacters:kanatext];

    int qlen = [Nihongo normalizeText:text ofLength:[request length]];
    int klen = [Nihongo normalizeText:kanatext ofLength:[kanareq length]];

    NSMutableArray *result = [[NSMutableArray alloc] init];

    NSMutableSet *sexact = [[NSMutableSet alloc] init];
    NSMutableSet *spartial[dictNum];

    int i, etotal = 0, ptotal = 0;
    for (i = 0; i < dictNum && etotal < maxres; i++) {
        spartial[i] = [[NSMutableSet alloc] init];

        [self lookupDict:fileList[i] exact:sexact partial:((etotal + ptotal) < maxres ? spartial[i] : nil) roma:text of:qlen kana:kanatext of:klen];

        ptotal += [spartial[i] count];
        etotal += [sexact count];

        for (NSString *st in [[sexact allObjects] sortedArrayUsingComparator:^(id obj1, id obj2) {
            NSString *v1 = obj1, *v2 = obj2;
            return (NSComparisonResult)[v1 compare:v2];
        }]) {
            if ([result count] >= maxres) break;
            ResultLine *data = [ResultLine alloc];
            [data initWithText:st dictName:fileList[i]];
            [result addObject:data];
        }
        [sexact removeAllObjects];
    }
    [sexact dealloc];

    for (i = 0; i < dictNum && [result count] < maxres; i++) {
        NSString *dictName = [NSString stringWithFormat:@"%@ (partial)", fileList[i]];
        for (NSString *st in [[spartial[i] allObjects] sortedArrayUsingComparator:^(id obj1, id obj2) {
            NSString *v1 = obj1, *v2 = obj2;
            return (NSComparisonResult)[v1 compare:v2];
        }]) {
            if ([result count] >= maxres || [self isCancelled]) break;
            ResultLine *data = [ResultLine alloc];
            [data initWithText:st dictName:dictName];
            [result addObject:data];
        }
        [spartial[i] dealloc];
    }

    if (![self isCancelled])
        [creator performSelectorOnMainThread:@selector(searchDone:)
                                  withObject:result
                               waitUntilDone:YES];

    [result dealloc];
}

@end
