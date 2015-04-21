//  RSSDB.m
//  Updated for ARC by Bill Weinman on 2012-08-11.
//  Updated for iOS 7 by Bill Weinman on 2013-09-20
//  Copyright (c) 2010-2013 Bill Weinman. All rights reserved.
//

#import "RSSDB.h"

@implementation RSSDB

@synthesize idList;

static NSString * const kFeedTableName = @"feed";
static NSString * const kItemTableName = @"item";

static NSString * const kDBFeedUrlKey = @"url";
static NSString * const kDBItemUrlKey = @"url";
static NSString * const kDBItemFeedIDKey = @"feed_id";

#pragma mark - Instance methods

- (RSSDB *) initWithRSSDBFilename: (NSString *) fn {
    // NSLog(@"%s %@", __FUNCTION__, fn);
    if ((self = (RSSDB *) [super initWithDBFilename:fn])) {
        idList = [[NSMutableArray alloc] init];
    }
    [self setDefaults];
    return self;
}

- (NSString *) getVersion {
    return kRSSDBVersion;
}

- (void) setDefaults {
    // NSLog(@"%s", __FUNCTION__);
    [self addNewIndex];
}

- (NSNumber *) getMaxItemsPerFeed {
    // NSLog(@"%s", __FUNCTION__);
    NSUserDefaults * defaults = [NSUserDefaults standardUserDefaults];
    NSNumber * maxItemsPerFeed = [defaults objectForKey:@"max_items_per_feed"];
    // the device doesn't initialize standardUserDefaults until the preference pane has been visited once
    if (!maxItemsPerFeed) maxItemsPerFeed = @(kDefaultMaxItemsPerFeed);
    return maxItemsPerFeed;
}

// add index for old version of the DB
- (void) addNewIndex {
    // NSLog(@"%s", __FUNCTION__);
    [self doQuery:@"CREATE UNIQUE INDEX IF NOT EXISTS feedUrl ON feed(url)"];
}

#pragma mark - Feed methods

- (NSArray *) getFeedIDs {
    // NSLog(@"%s", __FUNCTION__);
    NSDictionary * row;
    [idList removeAllObjects];  // reset the array

    // No longer works with Fast Eenumeration
    // for (row in [self getQuery:@"SELECT id FROM feed ORDER BY LOWER(title)"]) {
    //     [idList addObject:row[@"id"]];
    // }

    // Workaround for iOS 7
    [self prepareQuery:@"SELECT id FROM feed ORDER BY LOWER(title)"];
    while ((row = [self getPreparedRow])) {
        [idList addObject:row[@"id"]];
    }

    return idList;
}

- (NSDictionary *) getFeedRow: (NSNumber *) rowid {
    // NSLog(@"%s", __FUNCTION__);
    self->tableName = kFeedTableName;
    return [self getRow:rowid];
}

- (void) deleteFeedRow: (NSNumber *) rowid {
    // NSLog(@"%s", __FUNCTION__);
    [self doQuery:@"DELETE FROM item WHERE feed_id = ?", rowid];
    [self doQuery:@"DELETE FROM feed WHERE id = ?", rowid];
}

- (NSNumber *) addFeedRow: (NSDictionary *) feed {
    // NSLog(@"%s", __FUNCTION__);
    self->tableName = kFeedTableName;
    NSNumber * rowid = [self valueFromQuery:@"SELECT id FROM feed WHERE url = ?", feed[kDBFeedUrlKey]];
    if (rowid) {
        [self updateRow:feed forRowID:rowid];
        return rowid;
    } else {
        [self insertRow:feed];
        return nil;     // indicate that it's a new row
    }
}

- (void) updateFeed: (NSDictionary *) feed forRowID: (NSNumber *) rowid {
    // NSLog(@"%s", __FUNCTION__);
    self->tableName = kFeedTableName;
    NSDictionary * rec = @{@"title": feed[@"title"],
						  @"desc": feed[@"desc"]};
    [self updateRow:rec forRowID:rowid];
}

#pragma mark - Item methods

- (NSDictionary *) getItemRow: (NSNumber *) rowid {
    // NSLog(@"%s", __FUNCTION__);
    self->tableName = kItemTableName;
    return [self getRow:rowid];
}

- (void) deleteItemRow: (NSNumber *) rowid {
    // NSLog(@"%s", __FUNCTION__);
    self->tableName = kItemTableName;
    [self deleteRow:rowid];
}

- (void) deleteOldItems:(NSNumber *)feedID {
    // NSLog(@"%s", __FUNCTION__);
    [self doQuery:@"DELETE FROM item WHERE feed_id = ? AND id NOT IN "
	 @"(SELECT id FROM item WHERE feed_id = ? ORDER BY pubdate DESC LIMIT ?)",
	 feedID, feedID, [self getMaxItemsPerFeed]];
}

- (NSArray *) getItemIDs:(NSNumber *)feedID {
    // NSLog(@"%s", __FUNCTION__);
    NSDictionary * row;
    [idList removeAllObjects];  // reset the array

    // A bug in iOS 7 SDK prevents this from working on ARM
    // for (row in [self getQuery:@"SELECT id FROM item WHERE feed_id = ? ORDER BY pubdate DESC", feedID]) {
    //     [idList addObject:row[@"id"]];
    // }

    // Workaround for iOS 7
    [self prepareQuery:@"SELECT id FROM item WHERE feed_id = ? ORDER BY pubdate DESC", feedID];
    while ((row = [self getPreparedRow])) {
        [idList addObject:row[@"id"]];
    }

    return idList;
}

- (NSNumber *) addItemRow: (NSDictionary *) item {
    // NSLog(@"%s", __FUNCTION__);
    self->tableName = kItemTableName;
    NSNumber * rowid = [self valueFromQuery:@"SELECT id FROM item WHERE url = ? AND feed_id = ?",
                        item[kDBItemUrlKey], item[kDBItemFeedIDKey]];
    if (rowid) {
        [self updateRow:item forRowID:rowid];
        return rowid;
    } else {
        [self insertRow:item];
        return nil;     // indicate that it's a new row
    }
}

- (NSNumber *) countItems:(NSNumber *)feedID {
    // NSLog(@"%s", __FUNCTION__);
    return [self valueFromQuery:@"SELECT COUNT(*) FROM item WHERE feed_id = ?", feedID];
}

@end
