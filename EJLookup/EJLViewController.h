//
//  EJLViewController.h
//  EJLookup
//
//  Created by Ivan Podogov on 25.10.11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>


@interface EJLViewController : UIViewController <UISearchDisplayDelegate, UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate>
{
    NSOperationQueue *queue;
    UITextView *detailView;
}

@property (nonatomic,retain) NSMutableArray *autoCompletedata;
@property (nonatomic,retain) NSMutableArray *apiData;
@property (nonatomic,retain) NSMutableArray *sectionData;
@property (nonatomic,retain) NSMutableDictionary *sectionList;
@property (nonatomic,retain) IBOutlet UISearchBar *searchBar;
@property (nonatomic,assign) BOOL isAutocomplete;
@property (nonatomic, retain) IBOutlet UITextView *aboutView;

- (void)performSearch:(NSString *)searchText;

@end
