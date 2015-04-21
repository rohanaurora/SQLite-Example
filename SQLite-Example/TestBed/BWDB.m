//  BWDB.m
//  Copyright (c) 2010-2014 Bill Weinman. All rights reserved.
//  Updated for iOS 8 by Bill Weinman on 2014-12-12
//

#import "BWDB.h"

@implementation BWDB {
    NSDictionary __unsafe_unretained * feRow[16];
}

- (NSString *) getVersion {
    return kBWDBVersion;
}

- (BWDB *) initWithDBFilename: (NSString *) fn {
    if ((self = [super init])) {
        databaseFileName = fn;
        tableName = nil;
        [self openDB];
    }
    return self;
}


- (BWDB *) initWithDBFilename: (NSString *) fn andTableName: (NSString *) tn {
    // NSLog(@"%s", __FUNCTION__);
    if ((self = [super init])) {
        databaseFileName = fn;
        tableName = tn;
        [self openDB];
    }
    return self;
}

// Check to see if the file exists in the documents directory
// otherwise try to copy a default file from the resource path
- (void) openDB {
    // NSLog(@"%s", __FUNCTION__);
    if (database) return;
    filemanager = [[NSFileManager alloc] init];
    NSString * dbpath = [self getDBPath];

    if (![filemanager fileExistsAtPath:dbpath]) {
        // try to copy from default, if we have it
        NSString * defaultDBPath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:databaseFileName];
        if ([filemanager fileExistsAtPath:defaultDBPath]) {
            // NSLog(@"copy default DB");
            NSError * e = [[NSError alloc] init];
            BOOL success = [filemanager copyItemAtPath:defaultDBPath toPath:dbpath error:&e];
            if (!success) {
                NSLog(@"NSError: %@", e);
            }
        } else {
            NSLog(@"No bwrss.db file: %@", defaultDBPath);
        }
    }
    if (sqlite3_open([dbpath UTF8String], &database) != SQLITE_OK) {
        NSAssert1(0, @"Error: initializeDatabase: could not open database (%s)", sqlite3_errmsg(database));
    }
    filemanager = nil;
}

- (void) closeDB {
    // NSLog(@"%s", __FUNCTION__);
    if (database) sqlite3_close(database);
    database = NULL;
    filemanager = nil;
}

- (void) dealloc {
    [self closeDB];
}

- (NSString *) getDBPath {
    // NSLog(@"%s", __FUNCTION__);
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = paths[0];
    return [documentsDirectory stringByAppendingPathComponent:databaseFileName];
}

#pragma mark - Fast enumeration support

// iteration in ObjC is called "fast enumeration"
// this is a simple implementation
- (NSUInteger) countByEnumeratingWithState:(NSFastEnumerationState *)state objects:(id __unsafe_unretained *)stackbuf count:(NSUInteger)len {
    if (((*feRow = [self getPreparedRow]))) {
        state->itemsPtr = feRow;
        state->state = 1;   // set to non-zero -- indicates enumeration in progress
        state->mutationsPtr = state->extra;   // not used, required by the FE interface
        return 1;
    } else {
        return 0;
    }
}

#pragma mark - SQL Queries

// doQuery:query,...
// executes a non-select query on the SQLite database
// uses SQLbind to bind the variadic parameters
// Return value is the number of affect rows
- (NSNumber *) doQuery:(NSString *) query, ... {
    // NSLog(@"%s: %@", __FUNCTION__, query);
    va_list args;
    va_start(args, query);
    
    const char *cQuery = [query UTF8String];
    [self bindSQL:cQuery withVargs:args];
    if (statement == NULL) return @0;
    
    va_end(args);
    sqlite3_step(statement);
    if(sqlite3_finalize(statement) == SQLITE_OK) {
        return @(sqlite3_changes(database));
    } else {
        NSLog(@"doQuery: sqlite3_finalize failed (%s)", sqlite3_errmsg(database));
        return @0;
    }
}

// prepareQuery:query,...
// prepares a select query on the SQLite database
// uses SQLbind to bind the variadic parameters
// use getRow or getValue to get results
- (void) prepareQuery:(NSString *) query, ... {
    // NSLog(@"%s: %@", __FUNCTION__, query);
    va_list args;
    va_start(args, query);
    
    const char *cQuery = [query UTF8String];
    [self bindSQL:cQuery withVargs:args];
    va_end(args);
    if (statement == NULL) return;
}

// getQuery:query,...
// executes a select query on the SQLite database
// uses SQLbind to bind the variadic parameters
// Returns self for fast enumeration
- (BWDB *) getQuery:(NSString *) query, ... {
    // NSLog(@"%s: %@", __FUNCTION__, query);
    va_list args;
    va_start(args, query);
    
    const char *cQuery = [query UTF8String];
    [self bindSQL:cQuery withVargs:args];
    va_end(args);
    if (statement == NULL) return nil;
    return self;
}

- (id) valueFromQuery:(NSString *) query, ... {
    // NSLog(@"%s: %@", __FUNCTION__, query);
    va_list args;
    va_start(args, query);
    const char *cQuery = [query UTF8String];
    [self bindSQL:cQuery withVargs:args];
    va_end(args);
    if (statement == NULL) return nil;
    return [self getPreparedValue];
}


// bindSQL:withVargs
// binds variadic arguments to the SQL query.
// create NSArray and call bindSQL:withArray
// see SQLquery for how to call this
- (void) bindSQL:(const char *) cQuery withVargs:(va_list)vargs {
    // NSLog(@"%s: %s", __FUNCTION__, cQuery);

    // determine the number of required parameters
    if (sqlite3_prepare_v2(database, cQuery, -1, &statement, NULL) != SQLITE_OK) {
        NSLog(@"bindSQL: could not prepare statement (%s) %s", sqlite3_errmsg(database), cQuery);
        statement = NULL;
        return;
    }

    NSUInteger param_count = sqlite3_bind_parameter_count(statement);
    NSMutableArray * params = [NSMutableArray arrayWithCapacity:param_count];

    for (NSInteger i = 0; i < param_count; ++i) {
        id o = va_arg(vargs, id);
        if (o == nil) {
            o = [NSNull null];
        }
        [params addObject: o];
    }

    [self bindSQL:cQuery withArray:params];
}

// bindSQL:withArray
// binds NSArray arguments to the SQL query.
// cQuery is a C string, params is an NSArray of objects
// objects are tested for type
// see insertRow or updateRow for how to call this
- (void) bindSQL:(const char *) cQuery withArray:(NSArray *) params {
    // NSLog(@"%s: %s", __FUNCTION__, cQuery);
    NSInteger param_count;
    
    // preparing the query here allows SQLite to determine
    // the number of required parameters
    if (sqlite3_prepare_v2(database, cQuery, -1, &statement, NULL) != SQLITE_OK) {
        NSLog(@"bindSQL:withArray: could not prepare statement (%s) %s", sqlite3_errmsg(database), cQuery);
        statement = NULL;
        return;
    }

    param_count = sqlite3_bind_parameter_count(statement);
    if (param_count != [params count]) {
        NSLog(@"bindSQL:withArray: wrong number of parameters (%s)", cQuery);
        statement = NULL;
        return;
    }
    
    if (param_count) {
        for (int i = 0; i < param_count; i++) {
            id o = params[i];
            
            // determine the type of the parameter
            if ([o isEqual:[NSNull null]]) {
                sqlite3_bind_null(statement, i + 1);
            } else if ([o respondsToSelector:@selector(objCType)]) {
                if (strchr("islqISLBQ", *[o objCType])) { // integer
                    sqlite3_bind_int(statement, i + 1, [o intValue]);
                } else if (strchr("fd", *[o objCType])) {   // double
                    sqlite3_bind_double(statement, i + 1, [o doubleValue]);
                } else {    // unhandled types
                    NSLog(@"bindSQL:withArray: Unhandled objCType: %s query: %s", [o objCType], cQuery);
                    statement = NULL;
                    return;
                }
            } else if ([o isKindOfClass:[NSString class]]) { // string
                sqlite3_bind_text(statement, i + 1, [o UTF8String], -1, SQLITE_TRANSIENT);
            } else {    // unhhandled type
                NSLog(@"bindSQL:withArray: Unhandled parameter type: %@ query: %s", [o class], cQuery);
                statement = NULL;
                return;
            }
        }
    }
    return;
}

#pragma mark - Raw results

- (NSDictionary *) getPreparedRow {
    // NSLog(@"%s", __FUNCTION__);
    int rc = sqlite3_step(statement);
    if (rc == SQLITE_DONE) {
        sqlite3_finalize(statement);
        return nil;
    } else  if (rc == SQLITE_ROW) {
        int col_count = sqlite3_column_count(statement);
        if (col_count >= 1) {
            NSMutableDictionary * dRow = [NSMutableDictionary dictionaryWithCapacity:col_count];
            for(int i = 0; i < col_count; i++) {
                dRow[ @(sqlite3_column_name(statement, i)) ] = [self columnValue:i];
            }
            return dRow;
        }
    } else {    // rc != SQLITE_ROW
        NSLog(@"rowFromPreparedQuery: could not get row: %s", sqlite3_errmsg(database));
        return nil;
    }
    return nil;
}

// returns one value from the first column of the query
- (id) getPreparedValue {
    // NSLog(@"%s", __FUNCTION__);
    int rc = sqlite3_step(statement);
    if (rc == SQLITE_DONE) {
        sqlite3_finalize(statement);
        return nil;
    } else  if (rc == SQLITE_ROW) {
        int col_count = sqlite3_column_count(statement);
        if (col_count < 1) return nil;  // shouldn't really ever happen
        id o = [self columnValue:0];
        sqlite3_finalize(statement);
        return o;
    } else {    // rc == SQLITE_ROW
        NSLog(@"valueFromPreparedQuery: could not get row: %s", sqlite3_errmsg(database));
        return nil;
    }
}

#pragma mark - CRUD Methods

- (NSNumber *) insertRow:(NSDictionary *) record {
    // NSLog(@"%s", __FUNCTION__);
    NSInteger dictSize = [record count];
    NSArray * vArray = [record allValues];
    
    // construct the query
    NSMutableArray * placeHoldersArray = [NSMutableArray arrayWithCapacity:dictSize];
    for (NSInteger i = 0; i < dictSize; ++i)  // array of ? markers for placeholders in query
        [placeHoldersArray addObject: @"?"];
    
    NSString * query = [NSString stringWithFormat:@"insert into %@ (%@) values (%@)",
                        tableName,
                        [[record allKeys] componentsJoinedByString:@","],
                        [placeHoldersArray componentsJoinedByString:@","]];
    
    [self bindSQL:[query UTF8String] withArray:vArray];
    sqlite3_step(statement);
    if(sqlite3_finalize(statement) == SQLITE_OK) {
        return [self lastInsertId];
    } else {
        NSLog(@"insertRow: sqlite3_finalize failed (%s)", sqlite3_errmsg(database));
        return @0;
    }
}

- (void) updateRow:(NSDictionary *) record forRowID:(NSNumber *)rowID {
    // NSLog(@"%s", __FUNCTION__);
    NSInteger dictSize = (int) [record count];

    NSMutableArray * vArray = [NSMutableArray arrayWithCapacity:dictSize + 1];
    [vArray addObjectsFromArray:[record allValues]];
    [vArray addObject:rowID];
    
    NSString * query = [NSString stringWithFormat:@"update %@ set %@ = ? where id = ?",
                        tableName,
                        [[record allKeys] componentsJoinedByString:@" = ?, "]];
    
    [self bindSQL:[query UTF8String] withArray:vArray];
    sqlite3_step(statement);
    if(sqlite3_finalize(statement) != SQLITE_OK) {
        NSLog(@"updateRow: sqlite3_finalize failed (%s)", sqlite3_errmsg(database));
    }
}

- (void) deleteRow:(NSNumber *) rowID {
    // NSLog(@"%s", __FUNCTION__);
    
    NSString * query = [NSString stringWithFormat:@"delete from %@ where id = ?", tableName];
    [self doQuery:query, rowID];
}

- (NSDictionary *) getRow: (NSNumber *) rowID {
    NSString * query = [NSString stringWithFormat:@"select * from %@ where id = ?", tableName];
    [self prepareQuery:query, rowID];
    return [self getPreparedRow];
}

- (NSNumber *) countRows {
    return [self valueFromQuery:[NSString stringWithFormat:@"select count(*) from %@", tableName]];
}

#pragma mark - Keyed Subscripting methods

- (NSDictionary *) objectForKeyedSubscript: (NSNumber *) rowID {
    return [self getRow:rowID];
}

- (void) setObject:(NSDictionary *) record forKeyedSubscript: (NSNumber *) rowID {
    [self updateRow:record forRowID:rowID];
}

#pragma mark - Utility Methods

- (id) columnValue:(int) columnIndex {
    // NSLog(@"%s columnIndex: %d", __FUNCTION__, columnIndex);
    id o = nil;
    switch(sqlite3_column_type(statement, columnIndex)) {
        case SQLITE_INTEGER:
            o = @(sqlite3_column_int(statement, columnIndex));
            break;
        case SQLITE_FLOAT:
            o = [NSNumber numberWithFloat:sqlite3_column_double(statement, columnIndex)];
            break;
        case SQLITE_TEXT:
            o = @((const char *) sqlite3_column_text(statement, columnIndex));
            break;
        case SQLITE_BLOB:
            o = [NSData dataWithBytes:sqlite3_column_blob(statement, columnIndex) length:sqlite3_column_bytes(statement, columnIndex)];
            break;
        case SQLITE_NULL:
            o = [NSNull null];
            break;
    }
    return o;
}

- (NSNumber *) lastInsertId {
    return [NSNumber numberWithLongLong:sqlite3_last_insert_rowid(database)];
}


@end
