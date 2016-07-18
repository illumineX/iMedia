#import <Foundation/Foundation.h>
#import "sqlite3.h"

@class FMDatabase;
@class FMStatement;

@interface FMResultSet : NSObject {
    FMDatabase *parentDB;
    FMStatement *statement;
    
    NSString *query;
    NSMutableDictionary *columnNameToIndexMap;
    BOOL columnNamesSetup;
}


+ (instancetype) resultSetWithStatement:(FMStatement *)statement usingParentDatabase:(FMDatabase*)aDB;

- (void) close;

@property (NS_NONATOMIC_IOSONLY, copy) NSString *query;

@property (NS_NONATOMIC_IOSONLY, strong) FMStatement *statement;

- (void)setParentDB:(FMDatabase *)newDb;

@property (NS_NONATOMIC_IOSONLY, readonly) BOOL next;
@property (NS_NONATOMIC_IOSONLY, readonly) BOOL hasAnotherRow;

- (BOOL) hasColumnWithName:(NSString*)columnName;
- (int) columnIndexForName:(NSString*)columnName;
- (NSString*) columnNameForIndex:(int)columnIdx;

- (int) intForColumn:(NSString*)columnName;
- (int) intForColumnIndex:(int)columnIdx;

- (long) longForColumn:(NSString*)columnName;
- (long) longForColumnIndex:(int)columnIdx;

- (long long int) longLongIntForColumn:(NSString*)columnName;
- (long long int) longLongIntForColumnIndex:(int)columnIdx;

- (BOOL) boolForColumn:(NSString*)columnName;
- (BOOL) boolForColumnIndex:(int)columnIdx;

- (double) doubleForColumn:(NSString*)columnName;
- (double) doubleForColumnIndex:(int)columnIdx;

- (NSString*) stringForColumn:(NSString*)columnName;
- (NSString*) stringForColumnIndex:(int)columnIdx;

- (NSDate*) dateForColumn:(NSString*)columnName;
- (NSDate*) dateForColumnIndex:(int)columnIdx;

- (NSData*) dataForColumn:(NSString*)columnName;
- (NSData*) dataForColumnIndex:(int)columnIdx;

- (const unsigned char *) UTF8StringForColumnIndex:(int)columnIdx NS_RETURNS_INNER_POINTER;
- (const unsigned char *) UTF8StringForColumnName:(NSString*)columnName NS_RETURNS_INNER_POINTER;

/*
If you are going to use this data after you iterate over the next row, or after you close the
result set, make sure to make a copy of the data first (or just use dataForColumn:/dataForColumnIndex:)
If you don't, you're going to be in a world of hurt when you try and use the data.
*/
- (NSData*) dataNoCopyForColumn:(NSString*)columnName;
- (NSData*) dataNoCopyForColumnIndex:(int)columnIdx;

- (BOOL) columnIndexIsNull:(int)columnIdx;
- (BOOL) columnIsNull:(NSString*)columnName;

- (void) kvcMagic:(id)object;

@end
