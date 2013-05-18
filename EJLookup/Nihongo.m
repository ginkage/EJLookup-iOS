//
//  Nihongo.m
//  EJLookup
//
//  Created by Ivan Podogov on 28.10.11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "Nihongo.h"


@implementation Nihongo

static NSMutableArray *kana;
static NSMutableArray *roma;
static unichar hashtab[65536];

static bool Jaiueoy(unichar c)
{
	return (c >= 0x3041 && c <= 0x304A) || (c >= 0x30A1 && c <= 0x30AA) ||
    (c >= 0x3083 && c <= 0x3088) || (c >= 0x30E3 && c <= 0x30E8);
}

+ (NSString *)romanateText:(unichar *)text from:(int)begin to:(int)end
{
    NSString *out = @"";
    int pkana, pk, pi, ps, pb;
    bool tsu = false;

    for (pb = begin; pb <= end; pb++) {
        if ((text[pb] >= 0x3041 && text[pb] <= 0x3094) || (text[pb] >= 0x30A1 && text[pb] <= 0x30FC)) {
            if (text[pb] == 0x3063 || text[pb] == 0x30C3) {
                if (pb+1 <= end && ((text[pb+1] >= 0x3041 && text[pb+1] <= 0x3094) ||
                                    (text[pb+1] >= 0x30A1 && text[pb+1] <= 0x30FC)))
                    tsu = true;
                else
                    out = [out stringByAppendingString:@"ltsu"];
                continue;
            }

            for (pkana = [kana count] - 1; pkana >= 0; pkana--) {
                NSString *skana = [kana objectAtIndex:pkana];

                for (pk = 0, pi = pb; pi <= end && pk < [skana length] && [skana characterAtIndex:pk] != '='; pk++, pi++)
                    if ([skana characterAtIndex:pk] != text[pi] && [skana characterAtIndex:pk] != (text[pi]-0x60)) break;

                if ([skana characterAtIndex:pk] == '=') {
                    ps = pk + 1;

                    if (tsu) {
                        unichar c = [skana characterAtIndex:ps];
                        out = [out stringByAppendingString:[NSString stringWithCharacters:&c length:1]];
                        tsu = false;
                    }

                    out = [out stringByAppendingString:[skana substringWithRange:NSMakeRange(ps, [skana length] - ps)]];
                    if (text[pb] == 0x3093 && pb+1 <= end && Jaiueoy(text[pb+1]))
                        out = [out stringByAppendingString:@"\'"];

                    pb = pi-1;
                    break;
                }
            }

            if (pkana < 0)
                out = [out stringByAppendingString:[NSString stringWithCharacters:&text[pb] length:1]];
        }
        else
            out = [out stringByAppendingString:[NSString stringWithCharacters:&text[pb] length:1]];
    }

    return out;
}

static unichar jtolower(unichar c)
{
    if ((c >= 'A' && c <= 'Z') || (c >= 0x0410 && c <= 0x042F))
        return (unichar) (c + 0x20);
    return c;
}

static int findsub(unichar *str, int length, int offset)
{
    int a=0, b=[roma count]-1, cur;
    int psub, pstr;
    
    while (b-a > 1)
    {
        cur = (a+b)/2;
        psub = 0;
        pstr = offset;

        NSString *sroma = [roma objectAtIndex:cur];

        while (pstr < length && [sroma characterAtIndex:psub] != '=')
        {
            if (jtolower(str[pstr]) < [sroma characterAtIndex:psub])
            {	b = cur;	break;	}
            else if (jtolower(str[pstr]) > [sroma characterAtIndex:psub])
            {	a = cur;	break;	}
            pstr++;	psub++;
        }

        if ([sroma characterAtIndex:psub++] == '=') return cur;
        else if (pstr >= length) return -1;
    }
    
    psub = 0;
    pstr = offset;
    NSString *aroma = [roma objectAtIndex:a];
    while (pstr < length && [aroma characterAtIndex:psub] != '=')
    {
        if (jtolower(str[pstr]) != [aroma characterAtIndex:psub]) break;
        pstr++;	psub++;
    }
    if ([aroma characterAtIndex:psub++] == '=') return a;
    else if (pstr >= length) return -1;
    
    if (a != b)
    {
        psub = 0;
        pstr = offset;
        NSString *broma = [roma objectAtIndex:b];
        while (pstr <= length && [broma characterAtIndex:psub] != '=')
        {
            if (jtolower(str[pstr]) != [broma characterAtIndex:psub]) break;
            pstr++;	psub++;
        }
        if ([broma characterAtIndex:psub++] == '=') return b;
    }
    
    return -1;
}

static bool aiueo(unichar c)
{
	return c == 'a' || c == 'i' || c == 'u' || c == 'e' || c == 'o';
}

+ (NSString *)kanateText:(unichar *)text ofLength:(int)length
{
    int pb, pk = 0, pls, prs, r;
    NSString *out = @"";
    unichar kanabuf[1024];
    bool tsu;
    unichar c;

    for (pb = 0; pb < length; pb++)
    {
        tsu = false;
        if (pb+1 < length && jtolower(text[pb]) == jtolower(text[pb+1]) && !aiueo(jtolower(text[pb])))
        {
            if (pb+2 < length && jtolower(text[pb]) == 'n' && jtolower(text[pb+1]) == 'n' && jtolower(text[pb+2]) == 'n')
            {
                c = 0x3093;
                out = [out stringByAppendingString:[NSString stringWithCharacters:&c length:1]];
                pb++;
                continue;
            }
            
            tsu = true;
            pb++;
        }
        
        if (pb < length && ((pls = findsub(text, length, pb)) >= 0))
        {
            NSString *sroma = [roma objectAtIndex:pls];

            if (tsu)
            {
                if (jtolower(text[pb-1]) == 'n') kanabuf[pk++] = 0x3093;
                else kanabuf[pk++] = 0x3063;
            }
            
            r = 0;
            while ([sroma characterAtIndex:r++] != '=') pb++;
            pb--;
            
            prs = pk;
            while (r < [sroma length]) kanabuf[prs++] = [sroma characterAtIndex:r++];
            pk = prs;
        }
        else if (jtolower(text[pb]) == 'n' || jtolower(text[pb]) == 'm')
            kanabuf[pk++] = 0x3093;
        else
        {
            unichar tmp[4];
            pls = -1;

            if (pb+1 < length && jtolower(text[pb]) == 't' && jtolower(text[pb+1]) == 's')
            {
                tmp[0] = 't'; tmp[1] = 's'; tmp[2] = 'u'; tmp[3] = '\0';
                pls = findsub(tmp, length, 0);
            }

            if (pb+1 < length && jtolower(text[pb]) == 's' && jtolower(text[pb+1]) == 'h')
            {
                tmp[0] = 's'; tmp[1] = 'h'; tmp[2] = 'i'; tmp[3] = '\0';
                pls = findsub(tmp, length, 0);
            }

            if (pls >= 0)
            {
                NSString *sroma = [roma objectAtIndex:pls];

                r = 0;
                pb++;
                while ([sroma characterAtIndex:r++] != '=') ;
                prs = pk;
                while (r < [sroma length]) kanabuf[prs++] = [sroma characterAtIndex:r++];
                pk = prs;
            }
            else
            {
                if (tsu)
                    out = [out stringByAppendingString:[NSString stringWithCharacters:&text[pb-1] length:1]];
                out = [out stringByAppendingString:[NSString stringWithCharacters:&text[pb] length:1]];
            }
        }
        
        if (pk != 0)
        {
            out = [out stringByAppendingString:[NSString stringWithCharacters:kanabuf length:pk]];
            pk = 0;
        }
    }
    
    return out;
}

+ (bool)letter:(unichar)c
{
    return ((c >= '0' && c <= '9') ||
			(c >= 'A' && c <= 'Z') ||
			(c >= 'a' && c <= 'z') ||
			(c >= 0x00C0 && c <= 0x02A8) ||
			(c >= 0x0401 && c <= 0x0451) ||
			c == 0x3005 ||
			(c >= 0x3041 && c <= 0x30FA) ||
			(c >= 0x4E00 && c <= 0xFA2D) ||
			(c >= 0xFF10 && c <= 0xFF19) ||
			(c >= 0xFF21 && c <= 0xFF3A) ||
			(c >= 0xFF41 && c <= 0xFF5A) ||
			(c >= 0xFF66 && c <= 0xFF9F));
}

+ (int)normalizeText:(unichar *)buffer ofLength:(int)length
{
    int p, unibuf;

    for (unibuf = p = 0; p < length && buffer[p] != 0; p++)
    {
        if (buffer[p] >= 0xFF61 && buffer[p] <= 0xFF9F)
        {
            switch (buffer[p])
            {
				case 0xFF61:	buffer[p] = 0x3002;	break;
				case 0xFF62:	buffer[p] = 0x300C;	break;
				case 0xFF63:	buffer[p] = 0x300D;	break;
				case 0xFF64:	buffer[p] = 0x3001;	break;
				case 0xFF65:	buffer[p] = 0x30FB;	break;
				case 0xFF66:	buffer[p] = 0x30F2;	break;
                    
				case 0xFF67: case 0xFF68: case 0xFF69: case 0xFF6A: case 0xFF6B:
					buffer[p] = (unichar) ((buffer[p] - 0xFF67)*2 + 0x30A1);	break;
                    
				case 0xFF6C: case 0xFF6D: case 0xFF6E:
					buffer[p] = (unichar) ((buffer[p] - 0xFF6C)*2 + 0x30E3); break;
                    
				case 0xFF6F:	buffer[p] = 0x30C3;	break;
				case 0xFF70:	buffer[p] = 0x30FC;	break;
                    
				case 0xFF71: case 0xFF72: case 0xFF73: case 0xFF74: case 0xFF75:
					buffer[p] = (unichar) ((buffer[p] - 0xFF71)*2 + 0x30A2); break;
                    
				case 0xFF76: case 0xFF77: case 0xFF78: case 0xFF79: case 0xFF7A:
				case 0xFF7B: case 0xFF7C: case 0xFF7D: case 0xFF7E: case 0xFF7F:
				case 0xFF80: case 0xFF81:
					buffer[p] = (unichar) ((buffer[p] - 0xFF76)*2 + 0x30AB); break;
                    
				case 0xFF82: case 0xFF83: case 0xFF84:
					buffer[p] = (unichar) ((buffer[p] - 0xFF82)*2 + 0x30C4); break;
                    
				case 0xFF85: case 0xFF86: case 0xFF87: case 0xFF88: case 0xFF89:
					buffer[p] = (unichar) ((buffer[p] - 0xFF85) + 0x30CA); break;
                    
				case 0xFF8A: case 0xFF8B: case 0xFF8C: case 0xFF8D: case 0xFF8E:
					buffer[p] = (unichar) ((buffer[p] - 0xFF8A)*3 + 0x30CF); break;
                    
				case 0xFF8F: case 0xFF90: case 0xFF91: case 0xFF92: case 0xFF93:
					buffer[p] = (unichar) ((buffer[p] - 0xFF8F) + 0x30DE); break;
                    
				case 0xFF94: case 0xFF95: case 0xFF96:
					buffer[p] = (unichar) ((buffer[p] - 0xFF94)*2 + 0x30E4); break;
                    
				case 0xFF97: case 0xFF98: case 0xFF99: case 0xFF9A: case 0xFF9B:
					buffer[p] = (unichar) ((buffer[p] - 0xFF97) + 0x30E9); break;
                    
				case 0xFF9C:	buffer[p] = 0x30EF;	break;
				case 0xFF9D:	buffer[p] = 0x30F3;	break;
                    
				case 0xFF9E:	if (unibuf > 0) buffer[unibuf-1] += 1;	break;
				case 0xFF9F:	if (unibuf > 0) buffer[unibuf-1] += 2;	break;
            }
        }

        if (buffer[p] != 0xFF9E && buffer[p] != 0xFF9F && buffer[p] != 0x0301)
            buffer[unibuf++] = hashtab[buffer[p]];
    }
    return unibuf;
}

+ (void)initTables
{
    kana = [[NSMutableArray alloc] init];
    NSString *filePath = [[NSBundle mainBundle] pathForResource:@"kanatab" ofType:@"txt"];  
    NSString *fh = [NSString stringWithContentsOfFile:filePath encoding:NSUTF8StringEncoding error:NULL];
    for (NSString *line in [fh componentsSeparatedByString:@"\n"])
        if ([line length] > 0)
            [kana addObject:line];

    roma = [[NSMutableArray alloc] init];
    filePath = [[NSBundle mainBundle] pathForResource:@"romatab" ofType:@"txt"];  
    fh = [NSString stringWithContentsOfFile:filePath encoding:NSUTF8StringEncoding error:NULL];
    for (NSString *line in [fh componentsSeparatedByString:@"\n"])
        if ([line length] > 0)
            [roma addObject:line];

    for (int i=0; i<65536; i++)
        if ((i >= 'A' && i <= 'Z') ||
            (i >= 0x0410 && i <= 0x042F))
            hashtab[i] = (unichar) (i + 0x20);
        else if (i == 0x0451 || i == 0x0401)
            hashtab[i] = 0x0435;
        else if (i == 0x040E || i == 0x045E)
            hashtab[i] = 0x0443;
        else if (i == 0x3000)
            hashtab[i] = 0x0020;
        else if (i >= 0x30A1 && i <= 0x30F4)
            hashtab[i] = (unichar) (i - 0x60);
        else if (i >= 0xFF01 && i <= 0xFF20)
            hashtab[i] = (unichar) (i - 0xFEE0);
        else if (i >= 0xFF21 && i <= 0xFF3A)
            hashtab[i] = (unichar) (i - 0xFEC0);
        else if (i >= 0xFF3B && i <= 0xFF5E)
            hashtab[i] = (unichar) (i - 0xFEE0);
        else
            hashtab[i] = (unichar) i;
}

+ (void)freeTables
{
    [kana dealloc];
    [roma dealloc];
}

@end
