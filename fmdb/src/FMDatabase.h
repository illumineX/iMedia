#import <Foundation/Foundation.h>
#import "sqlite3.h"
#import "FMResultSet.h"

@interface FMDatabase : NSObject 
{
	sqlite3*    db;
	NSString*   databasePath;
    BOOL        logsErrors;
    BOOL        crashOnErrors;
    BOOL        inUse;
    BOOL        inTransaction;
    BOOL        traceExecution;
    BOOL        checkedOut;
    int         busyRetryTimeout;
    BOOL        shouldCacheStatements;
    NSMutableDictionary *cachedStatements;
}


+ (instancetype)databaseWithPath:(NSString*)inPath;
- (instancetype)initWithPath:(NSString*)inPath NS_DESIGNATED_INITIALIZER;

@property (NS_NONATOMIC_IOSONLY, readonly) BOOL open;
#if SQLITE_VERSION_NUMBER >= 3005000
- (BOOL) openWithFlags:(int)flags;
#endif
- (void) close;
@property (NS_NONATOMIC_IOSONLY, readonly) BOOL goodConnection;
- (void) clearCachedStatements;

// encryption methods.  You need to have purchased the sqlite encryption extensions for these to work.
- (BOOL) setKey:(NSString*)key;
- (BOOL) rekey:(NSString*)key;


@property (NS_NONATOMIC_IOSONLY, readonly, copy) NSString *databasePath;

@property (NS_NONATOMIC_IOSONLY, readonly, copy) NSString *lastErrorMessage;

@property (NS_NONATOMIC_IOSONLY, readonly) int lastErrorCode;
@property (NS_NONATOMIC_IOSONLY, readonly) BOOL hadError;
@property (NS_NONATOMIC_IOSONLY, readonly) sqlite_int64 lastInsertRowId;

@property (NS_NONATOMIC_IOSONLY, readonly) sqlite3 *sqliteHandle;

- (BOOL) executeUpdate:(NSString*)sql, ...;
- (BOOL) executeUpdate:(NSString*)sql withArgumentsInArray:(NSArray *)arguments;
- (id) executeQuery:(NSString *)sql withArgumentsInArray:(NSArray*)arrayArgs orVAList:(va_list)args; // you shouldn't ever need to call this.  use the previous two instead.

- (id) executeQuery:(NSString*)sql, ...;
- (id) executeQuery:(NSString *)sql withArgumentsInArray:(NSArray *)arguments;
- (BOOL) executeUpdate:(NSString*)sql withArgumentsInArray:(NSArray*)arrayArgs orVAList:(va_list)args; // you shouldn't ever need to call this.  use the previous two instead.

@property (NS_NONATOMIC_IOSONLY, readonly) BOOL rollback;
@property (NS_NONATOMIC_IOSONLY, readonly) BOOL commit;
@property (NS_NONATOMIC_IOSONLY, readonly) BOOL beginTransaction;
@property (NS_NONATOMIC_IOSONLY, readonly) BOOL beginDeferredTransaction;

@property (NS_NONATOMIC_IOSONLY) BOOL logsErrors;

@property (NS_NONATOMIC_IOSONLY) BOOL crashOnErrors;

@property (NS_NONATOMIC_IOSONLY) BOOL inUse;

@property (NS_NONATOMIC_IOSONLY) BOOL inTransaction;

@property (NS_NONATOMIC_IOSONLY) BOOL traceExecution;

@property (NS_NONATOMIC_IOSONLY) BOOL checkedOut;

@property (NS_NONATOMIC_IOSONLY) int busyRetryTimeout;

@property (NS_NONATOMIC_IOSONLY) BOOL shouldCacheStatements;

@property (NS_NONATOMIC_IOSONLY, copy) NSMutableDictionary *cachedStatements;


+ (NSString*) sqliteLibVersion;


@property (NS_NONATOMIC_IOSONLY, readonly) int changes;

@end

@interface FMStatement : NSObject {
    sqlite3_stmt *statement;
    NSString *query;
    long useCount;
}


- (void) close;
- (void) reset;

@property (NS_NONATOMIC_IOSONLY) sqlite3_stmt *statement;

@property (NS_NONATOMIC_IOSONLY, copy) NSString *query;

@property (NS_NONATOMIC_IOSONLY) long useCount;


@end

