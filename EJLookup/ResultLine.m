//
//  ResultLine.m
//  EJLookup
//
//  Created by Ivan Podogov on 27.10.11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "ResultLine.h"
#import <CoreText/CoreText.h>
#import "Nihongo.h"


@implementation ResultLine

@synthesize data = _data;
@synthesize group = _group;
@synthesize height = _height;

NSString *getSubstr(unichar *text, int begin, int len)
{
    int i, end = -1;
    for (i = begin; i < len && text[i] != 0; i++)
        end = i;
    if (end < 0) return @"";
    return [NSString stringWithCharacters:text+begin length:end-begin+1];
}

int mystrchr(unichar *text, int begin, unichar c, int len)
{
    int i;
    for (i = begin; i < len && text[i] != 0; i++)
        if (text[i] == c)
            return i;
    return -1;
}

- (void)initWithText:(NSString *)ntext dictName:(NSString *)ndict;
{
    NSString *result = @"";
    int i, i0 = -1, i1 = -1, i2 = -1, i3 = -1, i4 = -1, i5 = -1;
    int dict = -1, kanji = -1, kana = -1, trans = -1, roshi = -1, p;
    NSString *sdict = @"Default", *skanji = @"", *skana = @"", *strans = @"";
    bool kd = false, exact = false, partial = false;

    int len = [ntext length];
    unichar *text = calloc(len, sizeof(unichar));
    [ntext getCharacters:text];

    for (i = 0; i < len; i++)
        if (i0 < 0 && text[i] == ')')
            i0 = i;
        else if (i1 < 0 && i3 < 0 && text[i] == '[')
            i1 = i;
        else if (i2 < 0 && i3 < 0 && text[i] == ']')
            i2 = i;
        else if (i4 < 0 && i3 < 0 && text[i] == '{')
            i4 = i;
        else if (i5 < 0 && i3 < 0 && text[i] == '}')
            i5 = i;
        else if (i3 < 0 && text[i] == '/' && (i == 0 || text[i-1] != '<'))
            i3 = i;
    
    if (ndict == nil) {
        if (i0 >= 0) {
            for (i = i0; i > 0; i--)
                if (text[i] == '.') {
                    text[i] = '\0';
                    break;
                }
            text[i0] = '\0';
            dict = 2;
            
            if (text[0] == 'F' && !exact)
                exact = true;
            
            if (text[0] == 'P' && !partial)
                partial = true;
        }
        
        if (dict >= 0 && text[dict] != 0) {
            sdict = getSubstr(text, dict, len);
            if (partial)
                sdict = [sdict stringByAppendingString:@" (partial)"];

            _group = sdict;
        }
    }
    else {
        i0 = -1;
        sdict = ndict;
        _group = ndict;
    }

    if ([sdict hasPrefix:@"kanjidic"]) {
        kanji = i0 + 1;
        while (kanji < len && text[kanji] == ' ') kanji++;
        p = mystrchr(text, kanji, ' ', len);
        if (p >= 0) {
            text[p] = '\0';
            kana = p + 1;
            for (p = kana; p < len && text[p] != 0; p++)
                if (text[p] > 127) {
                    kana = p;
                    break;
                }
            
            p = mystrchr(text, kana, '{', len);
            if (p >= 0) {
                text[p-1] = '\0';
                trans = p;
            }
        }
        kd = true;
    }
    else {
        trans = i0 + 1;
        if (i1 >= 0 && i2 >= 0 && i1 < i2) {
            text[i1] = '\0';
            text[i2] = '\0';
            kana = i1 + 1;
            trans = i2 + 1;
            if ((ndict != nil || i0 >= 0) && i0 < i1) {
                kanji = i0 + 1;
                while (kanji < len && text[kanji] == ' ')
                    kanji++;
            }
        }
        
        if (i3 >= 0 && i3 > i0 && i3 > i1 && i3 > i2 && i3 > i4 && i3 > i5) {
            if (kana < 0) kana = trans;
            text[i3] = '\0';
            trans = i3 + 1;
        }
        
        if (i4 >= 0 && i5 >= 0 && i4 < i5) {
            text[i4] = '\0';
            text[i5] = '\0';
            roshi = i4 + 1;
        }
    }
    
    if (kanji >= 0) {
        int end = kanji;
        while (end < len && text[end] != 0) end++;
        if (end > kanji) {
            end--;
            while (end > kanji && text[end] == ' ')
                text[end--] = '\0';
        }
        skanji = getSubstr(text, kanji, len);
    }

    if (kana >= 0) {
        for (p = kana; p < len && text[p] != 0; ) {
            while (p < len && (text[p] == ' ' || text[p] == ',')) p++;
            if (p < len && text[p] != 0) {
                int begin = p, end = p - 1;
                while (p < len && text[p] != 0 && text[p] != ' ' && text[p] != ',') { end = p; p++; }
                if (end >= begin) {
                    if ([skana length] > 0)
                        skana = [skana stringByAppendingString:@"\n"];
                    skana = [skana stringByAppendingString:@"["];
                    skana = [skana stringByAppendingString:[NSString stringWithCharacters:text+begin length:end-begin+1]];
                    if (text[begin] > 127) {
                        skana = [skana stringByAppendingString:(kd ? @" / " : @"]\n[")];
                        skana = [skana stringByAppendingString:[Nihongo romanateText:text from:begin to:end]];
                    }
                    skana = [skana stringByAppendingString:@"]"];
                }
            }
        }
    }
    
    if (roshi >= 0) {
        for (p = roshi; p < len && text[p] != 0; ) {
            while (p < len && (text[p] == ' ' || text[p] == ',')) p++;
            if (p < len && text[p] != 0) {
                int begin = p, end = p - 1;
                while (p < len && text[p] != 0 && text[p] != ' ' && text[p] != ',') { end = p; p++; }
                if (end >= begin) {
                    if ([skana length] > 0)
                        skana = [skana stringByAppendingString:@"\n"];
                    skana = [skana stringByAppendingString:@"["];
                    skana = [skana stringByAppendingString:[NSString stringWithCharacters:text+begin length:end-begin+1]];
                    skana = [skana stringByAppendingString:@"]"];
                }
            }
        }
    }
    
    if (trans >= 0) {
        if (kd) {
            for (p = trans; p < len && text[p] != 0; ) {
                while (p < len && (text[p] == '{' || text[p] == '}')) p++;
                if (p < len && text[p] != 0) {
                    while (p < len && text[p] == ' ') p++;
                    int begin = p, end = p - 1;
                    while (p < len && text[p] != 0 && text[p] != '{' && text[p] != '}') { end = p; p++; }
                    if (end >= begin) {
                        if ([strans length] > 0)
                            strans = [strans stringByAppendingString:@"\n"];
                        strans = [strans stringByAppendingString:[NSString stringWithCharacters:text+begin length:end-begin+1]];
                    }
                }
            }
        }
        else {
            for (p = trans; p < len && text[p] != 0; p++) {
                if (text[p] == '/' && (p == trans || text[p-1] != '<')) {
                    text[p] = '\0';
                    p++;
                    while (trans < len && text[trans] == ' ') trans++;
                    if (trans < len && text[trans] != 0) {
                        if ([strans length] > 0)
                            strans = [strans stringByAppendingString:@"\n"];
                        strans = [strans stringByAppendingString:getSubstr(text, trans, len)];
                    }
                    trans = p;
                }
            }
            if (trans >= 0) {
                while (trans < len && text[trans] == ' ') trans++;
                if (trans < len && text[trans] != 0) {
                    if ([strans length] > 0)
                        strans = [strans stringByAppendingString:@"\n"];
                    strans = [strans stringByAppendingString:getSubstr(text, trans, len)];
                }
            }
        }
    }
    
    int kanjistart = -1, kanjiend = -1, kanastart = -1, kanaend = -1, transstart = -1;
    if ([skanji length] > 0) {
        if ([result length] > 0)
            result = [result stringByAppendingString:@"\n"];
        kanjistart = [result length];
        result = [result stringByAppendingString:skanji];
    }
    kanjiend = [result length];
    if ([skana length] > 0) {
        if ([result length] > 0)
            result = [result stringByAppendingString:@"\n"];
        kanastart = [result length];
        result = [result stringByAppendingString:skana];
    }
    kanaend = [result length];

    NSMutableArray *italic = [[NSMutableArray alloc] init];
    
    if ([strans length] > 0) {
        if ([result length] > 0)
            result = [result stringByAppendingString:@"\n"];
        transstart = [result length];
        
        int begin, end;
        while ((begin = [strans rangeOfString:@"<i>"].location) != NSNotFound) {
            result = [result stringByAppendingString:[strans substringWithRange:NSMakeRange(0, begin)]];
            end = [strans rangeOfString:@"</i>" options:0 range:NSMakeRange(begin+1, [strans length]-begin-1)].location;
            int is = [result length];
            if (end == NSNotFound) {
                result = [result stringByAppendingString:[strans substringFromIndex:begin+3]];
                strans = @"";
            }
            else {
                result = [result stringByAppendingString:[strans substringWithRange:NSMakeRange(begin+3, end-begin-3)]];
                strans = [strans substringFromIndex:end+4];
            }
            [italic addObject:[NSValue valueWithRange:NSMakeRange(is, [result length] - is)]];
        }
        
        result = [result stringByAppendingString:strans];
    }

    NSMutableAttributedString *res = [[NSMutableAttributedString alloc] initWithString:result];
    [res beginEditing];
/*
    String fsize = EJLookupActivity.preferences.getString("fontSize", "0");
    if (fsize.equals("1"))
        res.setSpan(new RelativeSizeSpan(1.5f), 0, res.length(), 0);
    else if (fsize.equals("2"))
        res.setSpan(new RelativeSizeSpan(2), 0, res.length(), 0);
*/
    UIFont *systemFont = [UIFont systemFontOfSize:15];
    CTFontRef font = CTFontCreateWithName((CFStringRef)systemFont.fontName, systemFont.pointSize, NULL);

    UIFont *systemBigFont = [UIFont systemFontOfSize:20];
    CTFontRef bigFont = CTFontCreateWithName((CFStringRef)systemBigFont.fontName, systemBigFont.pointSize, NULL);

    UIFont *italicSystemFont = [UIFont italicSystemFontOfSize:15];
    CTFontRef italicFont = CTFontCreateWithName((CFStringRef)italicSystemFont.fontName, italicSystemFont.pointSize, NULL);

    if (font && bigFont && italicFont) {
        if (kanjistart >= 0) {
            NSRange range = NSMakeRange(kanjistart, kanjiend - kanjistart);// + 1);
            [res addAttribute:(NSString *)kCTFontAttributeName value:(id)bigFont range:range];
            [res addAttribute:(id)kCTForegroundColorAttributeName
                        value:(id)[UIColor colorWithRed:0.5 green:0.25 blue:0.125 alpha:1].CGColor
                        range:range];
        }

        if (kanastart >= 0) {
            NSRange range = NSMakeRange(kanastart, kanaend - kanastart);// + 1);
            [res addAttribute:(NSString *)kCTFontAttributeName value:(id)font range:range];
            [res addAttribute:(id)kCTForegroundColorAttributeName
                        value:(id)[UIColor colorWithRed:0.125 green:0.25 blue:0.25 alpha:1].CGColor
                        range:range];
        }

        if (transstart >= 0) {
            [res addAttribute:(NSString *)kCTFontAttributeName value:(id)font range:NSMakeRange(transstart, [result length] - transstart)];
            for (NSValue *it in italic) {
                NSRange range = [it rangeValue];
                [res addAttribute:(NSString *)kCTFontAttributeName value:(id)italicFont range:range];
            }
        }
    }

    if (font)
        CFRelease(font);
    if (bigFont)
        CFRelease(bigFont);
    if (italicFont)
        CFRelease(italicFont);

    [res endEditing];

    CTFramesetterRef framesetter = CTFramesetterCreateWithAttributedString((CFAttributedStringRef)res);
    CFRange fitCFRange = CFRangeMake(0,0);
    CGSize sz = CTFramesetterSuggestFrameSizeWithConstraints(framesetter, CFRangeMake(0,0), NULL, CGSizeMake(300.0f, CGFLOAT_MAX), &fitCFRange);

    CGFloat height = 0;
    CGMutablePathRef path = CGPathCreateMutable();
    CGPathAddRect(path, NULL, CGRectMake(0, 0, 300, CGFLOAT_MAX));
    CTFrameRef frame = CTFramesetterCreateFrame(framesetter, fitCFRange, path, NULL);
    CFArrayRef lines = CTFrameGetLines(frame);
    NSUInteger numberOfLines = CFArrayGetCount(lines);
    for (NSUInteger lineIndex = 0; lineIndex < numberOfLines; lineIndex++) {
        CTLineRef line = CFArrayGetValueAtIndex(lines, lineIndex);
        CFRange range = CTLineGetStringRange(line), longestEffective;
        CTFontRef font = (CTFontRef)CFAttributedStringGetAttribute((CFAttributedStringRef)res, range.location, kCTFontAttributeName, &longestEffective);
        CGFloat size = CTFontGetSize((CTFontRef)font);
        height += floor(size*1.4 + 0.5);
        if (!lineIndex) height += floor(size*0.2 + 0.5);
    }
    CFRelease(frame);
    CFRelease(path);
    sz.height = height;

    if (framesetter) CFRelease(framesetter);
    _height = MAX(ceilf(sz.height + 6.0f), 44.0f);

    _data = res;
    [italic release];
    free(text);
}

- (void)dealloc
{
    [_group release];
    [_data release];
    [super dealloc];
}

@end
