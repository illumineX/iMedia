/* =============================================================================
	FILE:		UKFNSubscribeFileWatcher.m
	PROJECT:	Filie
    
    COPYRIGHT:  (c) 2005 M. Uli Kusterer, all rights reserved.
    
	AUTHORS:	M. Uli Kusterer - UK
    
    LICENSES:   MIT License

	REVISIONS:
		2006-03-13	UK	Commented, added singleton, added notifications.
		2005-03-02	UK	Created.
   ========================================================================== */

// -----------------------------------------------------------------------------
//  Headers:
// -----------------------------------------------------------------------------

#import "UKFNSubscribeFileWatcher.h"
#import <Carbon/Carbon.h>

// -----------------------------------------------------------------------------
//  Private stuff:
// -----------------------------------------------------------------------------

@interface UKFNSubscribeFileWatcher (UKPrivateMethods)

-(void) sendDelegateMessage: (FNMessage)message forSubscription: (FNSubscriptionRef)subscription;

@end

// -----------------------------------------------------------------------------
//  Prototypes:
// -----------------------------------------------------------------------------

void    UKFileSubscriptionProc(FNMessage message, OptionBits flags, void *refcon, FNSubscriptionRef subscription);

@implementation UKFNSubscribeFileWatcher

// -----------------------------------------------------------------------------
//  sharedFileWatcher:
//		Singleton accessor.
// -----------------------------------------------------------------------------

+(id) sharedFileWatcher
{
	static UKFNSubscribeFileWatcher* sSharedFileWatcher = nil;
	
	@synchronized( self )
	{
		if( !sSharedFileWatcher )
			sSharedFileWatcher = [[UKFNSubscribeFileWatcher alloc] init];	// This is a singleton, and thus an intentional "leak".
    }
	
    return sSharedFileWatcher;
}

// -----------------------------------------------------------------------------
//  * CONSTRUCTOR:
// -----------------------------------------------------------------------------

-(id)   init
{
    self = [super init];
    if( !self ) 
        return nil;
    
    subscribedPaths = [[NSMutableArray alloc] init];
    subscribedObjects = [[NSMutableArray alloc] init];
    
    return self;
}

// -----------------------------------------------------------------------------
//  * DESTRUCTOR:
// -----------------------------------------------------------------------------

-(void) dealloc
{
    [self removeAllPaths];
    
    [subscribedPaths release];
	subscribedPaths = nil;
    [subscribedObjects release];
	subscribedObjects = nil;
	
    [super dealloc];
}

-(void) finalize
{
    [self removeAllPaths];

    [super finalize];
}

// -----------------------------------------------------------------------------
//  addPath:
//		Start watching the object at the specified path. This only sends write
//		notifications for all changes, as FNSubscribe doesn't tell what actually
//		changed about our folder.
// -----------------------------------------------------------------------------

-(void) addPath: (NSString*)path
{
	@synchronized( self )
	{
		OSStatus                    err = noErr;
		static FNSubscriptionUPP    subscriptionUPP = NULL;
		FNSubscriptionRef           subscription = NULL;
		
		if( !subscriptionUPP )
			subscriptionUPP = NewFNSubscriptionUPP( UKFileSubscriptionProc );
		
		err = FNSubscribeByPath( (UInt8*) path.fileSystemRepresentation, subscriptionUPP, (void*)self,
									kNilOptions, &subscription );
		if( err != noErr )
		{
			NSLog( @"UKFNSubscribeFileWatcher addPath: %@ failed due to error ID=%d.", path, (int)err );
			return;
		}
		
		[subscribedPaths addObject: path];
		[subscribedObjects addObject: [NSValue valueWithPointer: subscription]];
	}
}

// -----------------------------------------------------------------------------
//  removePath:
//		Stop watching the object at the specified path.
// -----------------------------------------------------------------------------

-(void) removePath: (NSString*)path
{
    NSValue*            subValue = nil;
    @synchronized( self )
    {
		NSInteger		idx = [subscribedPaths indexOfObject: path];
		if( idx != NSNotFound )
		{
			subValue = [[subscribedObjects[idx] retain] autorelease];
			[subscribedPaths removeObjectAtIndex: idx];
			[subscribedObjects removeObjectAtIndex: idx];
		}
   }
    
	if( subValue )
	{
		FNSubscriptionRef   subscription = subValue.pointerValue;
		
		FNUnsubscribe( subscription );
	}
}

// -----------------------------------------------------------------------------
//  delegate:
//		Accessor for file watcher delegate.
// -----------------------------------------------------------------------------

-(id)   delegate
{
    return delegate;
}

// -----------------------------------------------------------------------------
//  setDelegate:
//		Mutator for file watcher delegate.
// -----------------------------------------------------------------------------

-(void) setDelegate: (id)newDelegate
{
    delegate = newDelegate;
}

-(void)	removeAllPaths
{
    @synchronized( self )
    {
		NSEnumerator*	enny = [subscribedObjects objectEnumerator];
		NSValue*        subValue = nil;
	
        while(( subValue = [enny nextObject] ))
		{
			FNSubscriptionRef   subscription = subValue.pointerValue;
			FNUnsubscribe( subscription );
		}
		
		[subscribedPaths removeAllObjects];
 		[subscribedObjects removeAllObjects];
   }
}

@end

@implementation UKFNSubscribeFileWatcher (UKPrivateMethods)

// -----------------------------------------------------------------------------
//  sendDelegateMessage:forSubscription:
//		Bottleneck for change notifications. This is called by our callback
//		function to actually inform the delegate and send out notifications.
//
//		This *only* sends out write notifications, as FNSubscribe doesn't tell
//		what changed about our folder.
// -----------------------------------------------------------------------------

-(void) sendDelegateMessage: (FNMessage)message forSubscription: (FNSubscriptionRef)subscription
{
    NSValue*                    subValue = [NSValue valueWithPointer: subscription];
	NSInteger							idx = [subscribedObjects indexOfObject: subValue];
	if( idx == NSNotFound )
	{
		NSLog( @"Notification for unknown subscription." );
		return;
	}
    NSString*                   path = subscribedPaths[idx];
    
	[[NSWorkspace sharedWorkspace].notificationCenter postNotificationName: UKFileWatcherWriteNotification
															object: self
															userInfo: @{@"path": path}];
	
    [delegate watcher: self receivedNotification: UKFileWatcherWriteNotification forPath: path];
    //NSLog( @"UKFNSubscribeFileWatcher noticed change to %@", path );	// DEBUG ONLY!
}

@end

// -----------------------------------------------------------------------------
//  UKFileSubscriptionProc:
//		Callback function we hand to Carbon so it can tell us when something
//		changed about our watched folders. We set the refcon to a pointer to
//		our object. This simply extracts the object and hands the info off to
//		sendDelegateMessage:forSubscription: which does the actual work.
// -----------------------------------------------------------------------------

void    UKFileSubscriptionProc( FNMessage message, OptionBits flags, void *refcon, FNSubscriptionRef subscription )
{
    UKFNSubscribeFileWatcher*   obj = (UKFNSubscribeFileWatcher*) refcon;
    
    if( message == kFNDirectoryModifiedMessage )    // No others exist as of 10.4
        [obj sendDelegateMessage: message forSubscription: subscription];
    else
        NSLog( @"UKFileSubscriptionProc: Unknown message %d", (int)message );
}
