//  RSSDB.h
//  Updated for ARC by Bill Weinman on 2012-08-11.
//  Updated for iOS 7 by Bill Weinman on 2013-09-20
//  Copyright (c) 2010-2013 Bill Weinman. All rights reserved.
//

#import "BWDB.h"
#import "BWUtilities.h"

static NSString * const kRSSDBVersion = @"2.1.0";
static NSUInteger const kDefaultMaxItemsPerFeed = 50;

@interface RSSDB : BWDB {
	NSMutableArray * idList;
}

@property (nonatomic, strong) NSMutableArray * idList;

- (RSSDB *) initWithRSSDBFilename: (NSString *) fn;
- (NSString *) getVersion;
- (NSArray *) getFeedIDs;
- (void) setDefaults;
- (NSNumber *) getMaxItemsPerFeed;
- (void) addNewIndex;

// Feed methods
- (NSDictionary *) getFeedRow: (NSNumber *) rowid;
- (void) deleteFeedRow: (NSNumber *) rowid;
- (NSNumber *) addFeedRow: (NSDictionary *) feed;
- (void) updateFeed: (NSDictionary *) feed forRowID: (NSNumber *) rowid;

// Item methods
- (NSDictionary *) getItemRow: (NSNumber *) rowid;
- (void) deleteItemRow: (NSNumber *) rowid;
- (void) deleteOldItems:(NSNumber *)feedID;
- (NSArray *) getItemIDs:(NSNumber *)feedID;
- (NSNumber *) addItemRow: (NSDictionary *) item;
- (NSNumber *) countItems:(NSNumber *)feedID;

@end
