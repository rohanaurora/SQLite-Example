//
//  ViewController.m
//  TestBed
//
//  Created by Rohan Aurora on 4/18/15.
//  Copyright (c) 2015 Rohan Aurora. All rights reserved.
//

#import "ViewController.h"
#import "BWDB.h"
#import "BWUtilities.h"
#import "RSSDB.h"

static NSString *const kTestBedVersion = @"1.1.1";

@interface ViewController ()
@property (weak, nonatomic) IBOutlet UITextView *textViewBed;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    messageTextView = self.textViewBed ;
    self.textViewBed.font = [UIFont systemFontOfSize:12.0];
    [self testDatabase];
}

- (void) testbed {
    message(@"%@ version %@", @"Sandbox", kBWDBVersion);
    [self testDatabase];
}

-(void) dispRow:(NSDictionary *) row {
    message(@"row %@ [%@]", row [@"title"], row [@"url"]);
}

-(void) testDatabase {
    RSSDB *db;
    NSString * dbfn = @"bwrss.db";
    
    db = [[RSSDB alloc] initWithRSSDBFilename:dbfn];
    message(@"RSSDB version %@", [db getVersion]);
    
    for (NSNumber *n in [db getFeedIDs]) {
        NSDictionary *feed = [db getFeedRow:n];
        [self dispRow:feed];
    }
}


@end
