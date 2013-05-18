//
//  EJLViewController.m
//  EJLookup
//
//  Created by Ivan Podogov on 25.10.11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "EJLViewController.h"
#import "TTTAttributedLabel.h"
#import "ResultLine.h"
#import "DictionarySearch.h"
#import "Nihongo.h"
#import "Suggest.h"
#import "MBProgressHUD.h"


@implementation EJLViewController

@synthesize autoCompletedata;
@synthesize apiData;
@synthesize sectionData;
@synthesize sectionList;
@synthesize searchBar;
@synthesize isAutocomplete;
@synthesize aboutView;

typedef struct {
    NSString *name;
    int sectionID;
    int itemOffset;
    int itemCount;
} sectionInfo;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
	self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
	if (self) {
	}
	return self;
}

- (void)dealloc
{
    [aboutView release];
	[super dealloc];
}

- (void)didReceiveMemoryWarning
{
	// Releases the view if it doesn't have a superview.
	[super didReceiveMemoryWarning];

	// Release any cached data, images, etc that aren't in use.
}

#pragma mark - View lifecycle

- (void)viewDidLoad
{
	[super viewDidLoad];
	// Do any additional setup after loading the view from its nib.
	NSString *appDomain = [[NSBundle mainBundle] bundleIdentifier];
	[[NSUserDefaults standardUserDefaults] removePersistentDomainForName:appDomain];
    queue = [[NSOperationQueue alloc] init];

    [aboutView addObserver:self forKeyPath:@"contentSize" options:(NSKeyValueObservingOptionNew) context:NULL];
    [aboutView setText:@"EJLookup\n\nверсия 1.0.2, by GinKage\n(ginkage@yandex.ru)\n\nПри создании использовались данные MONASH и проекта Warodai,\nhttp://warodai.ru"];

    detailView = nil;
}

- (void)viewDidUnload
{
    [self setAboutView:nil];
	[super viewDidUnload];
	// Release any retained subviews of the main view.
	// e.g. self.myOutlet = nil;
    [queue cancelAllOperations];
    [queue dealloc], queue = nil;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
	// Return YES for supported orientations
	return YES;//(interfaceOrientation == UIInterfaceOrientationPortrait);
}

- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    CGFloat topCorrect = ([aboutView bounds].size.height - [aboutView contentSize].height * [aboutView zoomScale]) / 3;
    topCorrect = (topCorrect < 0 ? 0 : topCorrect);
    aboutView.contentOffset = (CGPoint){ .x = 0, .y = -topCorrect };    
}

- (NSInteger)tableView:(UITableView *)aTableView numberOfRowsInSection:(NSInteger)section
{
    if (self.isAutocomplete)
        return [autoCompletedata count];

    sectionInfo info;
    NSValue *sectinfo = [sectionData objectAtIndex:section];
    [sectinfo getValue:&info];
    return info.itemCount;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    if (self.isAutocomplete)
        return nil;

    sectionInfo info;
    NSValue *sectinfo = [sectionData objectAtIndex:section];
    [sectinfo getValue:&info];
    return info.name;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (!self.isAutocomplete) {
        sectionInfo info;
        NSValue *sectinfo = [sectionData objectAtIndex:indexPath.section];
        [sectinfo getValue:&info];
        ResultLine *resline = [apiData objectAtIndex:(info.itemOffset + indexPath.row)];

        return resline.height;
    }
    return 44;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath 
{
	NSString *CellIdentifier = (self.isAutocomplete ? @"CellSuggest" : @"CellResult");

	// Dequeue or create a cell of the appropriate type.
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];

    if (self.isAutocomplete) {
        if (cell == nil)
            cell = [[[UITableViewCell alloc]
                     initWithStyle:UITableViewCellStyleDefault
                     reuseIdentifier:CellIdentifier] autorelease];

        cell.textLabel.text = [autoCompletedata objectAtIndex:indexPath.row];
        cell.detailTextLabel.text = @"";
        cell.accessoryType = UITableViewCellAccessoryNone;
    }
    else {
        if (cell == nil)
            cell = [[[UITableViewCell alloc]
                     initWithStyle:UITableViewCellStyleDefault
                     reuseIdentifier:CellIdentifier] autorelease];

        sectionInfo info;
        NSValue *sectinfo = [sectionData objectAtIndex:indexPath.section];
        [sectinfo getValue:&info];
        ResultLine *resline = [apiData objectAtIndex:(info.itemOffset + indexPath.row)];

        CGRect bounds = CGRectMake(10, 0, 300, resline.height);
        TTTAttributedLabel *textView = (TTTAttributedLabel *)[cell.contentView viewWithTag:999];
        if (textView == nil) {
            textView = [[TTTAttributedLabel alloc] initWithFrame:bounds];
            textView.tag = 999;
            textView.font = [UIFont systemFontOfSize:15];
            textView.textAlignment = UITextAlignmentLeft;
            textView.textColor = [UIColor blackColor];
            textView.lineBreakMode = UILineBreakModeWordWrap;
            textView.numberOfLines = 0;
            [cell.contentView addSubview:textView];
            [textView release];
        }

        textView.frame = bounds;
        textView.text = resline.data;
    }
	
	return cell;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    if (!self.isAutocomplete)
        return [sectionList count];
    return 1;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (self.isAutocomplete) {
        self.searchBar.text = [autoCompletedata objectAtIndex:indexPath.row];

        // hide table data
        tableView.hidden = YES;

        [self performSearch:self.searchBar.text];
        [self.searchBar resignFirstResponder];
    }
    else {
        // load detail view
/*        if (detailView != nil) {
            [detailView removeFromSuperview];
            [detailView dealloc];
            detailView = nil;
        }

        CGRect frame = [tableView rectForRowAtIndexPath:indexPath];
        UITextView *view = [[UITextView alloc] initWithFrame:frame];

        sectionInfo info;
        NSValue *sectinfo = [sectionData objectAtIndex:indexPath.section];
        [sectinfo getValue:&info];
        ResultLine *resline = [apiData objectAtIndex:(info.itemOffset + indexPath.row)];

        [view setFont:[UIFont systemFontOfSize:15]];
        [view setText:[resline.data string]];
        [view setEditable:NO];
        [tableView addSubview:view];

        detailView = view;*/
    }
}

- (void)tableView:(UITableView *)tableView didDeselectRowAtIndexPath:(NSIndexPath *)indexPath
{
/*    if (detailView != nil) {
        [detailView removeFromSuperview];
        [detailView dealloc];
        detailView = nil;
    }*/
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)_searchBar
{
	[self performSearch:_searchBar.text];
}

- (void)searchDone:(NSMutableArray *)result
{
	NSMutableArray *myDataArray = [[NSMutableArray alloc] init];
    [myDataArray setArray:result];

    NSMutableDictionary *mySections = [[NSMutableDictionary alloc] init];
    NSMutableArray *mySectData = [[NSMutableArray alloc] init];

	// data in the table  are search results
	self.isAutocomplete = NO;
	self.apiData = myDataArray;

    sectionInfo info;
    int total = 0;

    for (ResultLine *it in myDataArray) {
        int nsect = 0;

        NSNumber *section = [mySections objectForKey:it.group];
        if (section == nil) {
            nsect = [mySections count];
            [mySections setObject:[NSNumber numberWithInt:nsect] forKey:it.group];

            info.name = it.group;
            info.itemOffset = total;
            info.itemCount = 0;
            info.sectionID = nsect;
            [mySectData addObject:[NSValue value:&info withObjCType:@encode(sectionInfo)]];
        }
        else
            nsect = [section intValue];

        NSValue *sectinfo = [mySectData objectAtIndex:nsect];
        [sectinfo getValue:&info];
        info.itemCount++;
        [mySectData replaceObjectAtIndex:nsect withObject:[NSValue value:&info withObjCType:@encode(sectionInfo)]];

        total++;
    }

    self.sectionList = mySections;
    self.sectionData = mySectData;

	if (self.searchDisplayController.searchResultsTableView.hidden == YES)
		self.searchDisplayController.searchResultsTableView.hidden = NO;

	[self.searchDisplayController.searchResultsTableView reloadData];

	[MBProgressHUD hideHUDForView:self.view animated:YES];

	[myDataArray release];
    [mySections release];
    [mySectData release];
}

- (void)performSearch:(NSString *)searchText
{
	MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    hud.labelText = @"Поиск...";

    [queue cancelAllOperations];
    DictionarySearch *search = [[DictionarySearch alloc] initWithText:searchText delegate:self];
    [queue addOperation:search];
    [search release];
}

- (void)suggestDone:(NSMutableArray *)result
{
	NSMutableArray *myDataArray = [[NSMutableArray alloc] init];
    [myDataArray setArray:result];

    self.isAutocomplete = YES;
    self.autoCompletedata = myDataArray;

    [self.searchDisplayController.searchResultsTableView reloadData];
    [myDataArray release];
}

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText
{
    [queue cancelAllOperations];
    Suggest *search = [[Suggest alloc] initWithText:searchText delegate:self];
    [queue addOperation:search];
    [search release];
}

@end
