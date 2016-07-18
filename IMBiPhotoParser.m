/*
 iMedia Browser Framework <http://karelia.com/imedia/>
 
 Copyright (c) 2005-2012 by Karelia Software et al.
 
 iMedia Browser is based on code originally developed by Jason Terhorst,
 further developed for Sandvox by Greg Hulands, Dan Wood, and Terrence Talbot.
 The new architecture for version 2.0 was developed by Peter Baumgartner.
 Contributions have also been made by Matt Gough, Martin Wennerberg and others
 as indicated in source files.
 
 The iMedia Browser Framework is licensed under the following terms:
 
 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in all or substantial portions of the Software without restriction, including
 without limitation the rights to use, copy, modify, merge, publish,
 distribute, sublicense, and/or sell copies of the Software, and to permit
 persons to whom the Software is furnished to do so, subject to the following
 conditions:
 
	Redistributions of source code must retain the original terms stated here,
	including this list of conditions, the disclaimer noted below, and the
	following copyright notice: Copyright (c) 2005-2012 by Karelia Software et al.

	Redistributions in binary form must include, in an end-user-visible manner,
	e.g., About window, Acknowledgments window, or similar, either a) the original
	terms stated here, including this list of conditions, the disclaimer noted
	below, and the aforementioned copyright notice, or b) the aforementioned
	copyright notice and a link to karelia.com/imedia.

	Neither the name of Karelia Software, nor Sandvox, nor the names of
	contributors to iMedia Browser may be used to endorse or promote products
	derived from the Software without prior and express written permission from
	Karelia Software or individual contributors, as appropriate.
 
 Disclaimer: THE SOFTWARE IS PROVIDED BY THE COPYRIGHT OWNER AND CONTRIBUTORS
 "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT
 LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE,
 AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
 LIABLE FOR ANY CLAIM, DAMAGES, OR OTHER LIABILITY, WHETHER IN AN ACTION OF
 CONTRACT, TORT, OR OTHERWISE, ARISING FROM, OUT OF, OR IN CONNECTION WITH, THE
 SOFTWARE OR THE USE OF, OR OTHER DEALINGS IN, THE SOFTWARE.
 */


// Author: Jörg Jacobsen, Peter Baumgartner


//----------------------------------------------------------------------------------------------------------------------


#pragma mark HEADERS

#import "IMBAppleMediaParser+iMediaPrivate.h"
#import "IMBiPhotoParser.h"
#import "IMBNode.h"
#import "IMBiPhotoEventNodeObject.h"
#import "NSWorkspace+iMedia.h"
#import "NSFileManager+iMedia.h"
#import "NSString+iMedia.h"
#import "IMBIconCache.h"


//----------------------------------------------------------------------------------------------------------------------


#pragma mark

@interface IMBiPhotoParser ()

- (NSString*) typeForAlbum:(NSDictionary*)album;

@end


#pragma mark

@implementation IMBiPhotoParser

@synthesize dateFormatter = _dateFormatter;


//----------------------------------------------------------------------------------------------------------------------

// Returns name of library

+ (NSString *)libraryName
{
    return @"iPhoto";
}


- (id) init
{
	if ((self = [super init]))
	{
		_fakeAlbumID = 0;
		
		NSDateFormatter* formatter = [[NSDateFormatter alloc] init];
		formatter.dateStyle = NSDateFormatterShortStyle;
		self.dateFormatter = formatter;
		[formatter release];
	}
	
	return self;
}


- (void) dealloc
{
	IMBRelease(_appPath);
	IMBRelease(_dateFormatter);
	[super dealloc];
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

- (BOOL) populateNode:(IMBNode*)inNode error:(NSError**)outError
{
	NSDictionary* plist = self.plist;
	NSDictionary* images = plist[@"Master Image List"];
	NSArray* albums = plist[@"List of Albums"];
	
	// Population of events, faces, photo stream and regular album node fundamentally different
	
	if ([self isEventsNode:inNode])
	{
		NSArray* events = plist[@"List of Rolls"];
		[self populateEventsNode:inNode withEvents:events images:images];
	} 
	else if ([self isFacesNode:inNode])
	{
		NSDictionary* faces = plist[@"List of Faces"];
		[self populateFacesNode:inNode withFaces:faces images:images];
	} 
	else if ([self isPhotoStreamNode:inNode])
	{
		[self populatePhotoStreamNode:inNode images:images];
	} 
	else
	{
		[self addSubNodesToNode:inNode albums:albums images:images]; 
		[self populateAlbumNode:inNode images:images]; 
	}

	// If we are populating the root nodes, then also populate the "Photos" node and mirror its objects array 
	// into the objects array of the root node. Please note that this is non-standard parser behavior, which is 
	// implemented here, to achieve the desired "feel" in the browser...
	
	// Will find Photos node at same index in subnodes as in album list
	// which offset was it found, in "List of Albums" Array

    BOOL result = YES;
	NSUInteger photosNodeIndex = [self indexOfAllPhotosAlbumInAlbumList:albums];
	if (inNode.isTopLevelNode && photosNodeIndex != NSNotFound)
	{
		NSArray* subnodes = inNode.subnodes;
		if (photosNodeIndex < subnodes.count)	// Karelia case 136310, make sure offset exists
		{
			IMBNode* photosNode = subnodes[photosNodeIndex];	// assumes subnodes exists same as albums!
			result = [self populateNode:photosNode error:outError];
			inNode.objects = photosNode.objects;
		}
	}
	
	return result;
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 
#pragma mark Helper Methods


//----------------------------------------------------------------------------------------------------------------------

- (Class) objectClass
{
	return [IMBObject class];
}


// Returns the events node that should be subnode of our root node.
// Returns nil if there is none.

- (IMBNode*) eventsNodeInNode:(IMBNode*)inNode
{	
	IMBNode* eventsNode = nil;
	
	if (inNode.isTopLevelNode && (inNode.subnodes).count>0)
	{
		// We should find the events node at index 0 but this logic is more bullet proof.
		
		for (IMBNode* node in inNode.subnodes)
		{			
			if ([self isEventsNode:node])
			{
				eventsNode = node;
				break;
			}
		}
	}
	
	return eventsNode;
}


//----------------------------------------------------------------------------------------------------------------------


// This media type is specific to iPhoto and is not to be confused with kIMBMediaTypeImage...

- (NSString*) iPhotoMediaType
{
	return @"Image";
}


//----------------------------------------------------------------------------------------------------------------------


// Returns the identifier of the root node.

- (NSString*) rootNodeIdentifier
{
    return [self identifierForPath:@"/"];
}


// Create an identifier from the AlbumID that is stored in the XML file. An example is "IMBiPhotoParser://AlbumId/17"...

- (NSString*) identifierForId:(NSNumber*)inId inSpace:(NSString*)inIdSpace
{
	NSString* albumPath = [NSString stringWithFormat:@"/%@/%@",inIdSpace,inId];
	return [self identifierForPath:albumPath];
}


//----------------------------------------------------------------------------------------------------------------------


// iPhoto supports Photo Stream through AlbumData.xml since version 9.2.1
// ...but revokes support with version 9.4 (key "PhotoStreamAssetId" removed from image dictionaries)

- (BOOL) supportsPhotoStreamFeatureInVersion:(NSString*)inVersion
{
    if (inVersion && inVersion.length > 0)
    {
        NSComparisonResult shouldBeDescendingOrSame = [inVersion localizedStandardCompare:@"9.2.1"];
        NSComparisonResult shouldBeAscending = [inVersion localizedStandardCompare:@"9.4"];
        return ((shouldBeDescendingOrSame == NSOrderedDescending || shouldBeDescendingOrSame == NSOrderedSame) &&
                shouldBeAscending == NSOrderedAscending);
    }
    return NO;
}


//----------------------------------------------------------------------------------------------------------------------


// Exclude some album types...

- (BOOL) shouldUseAlbumType:(NSString*)inAlbumType
{
	if (inAlbumType == nil) return YES;
	if ([inAlbumType isEqualToString:@"Slideshow"]) return NO;
	if ([inAlbumType isEqualToString:@"Book"]) return NO;
	return YES;
}


// Check if the supplied album contains media files of correct media type. If we find a single one, then the 
// album qualifies as a new node. If however we do not find any media files of the desired type, then the 
// album will not show up as a node...

- (BOOL) shouldUseAlbum:(NSDictionary*)inAlbumDict images:(NSDictionary*)inImages
{
	// Usage of Events or Faces or Photo Stream album is not determined here
	
	NSUInteger albumId = [inAlbumDict[@"AlbumId"] unsignedIntegerValue];
	if (albumId == EVENTS_NODE_ID || albumId == FACES_NODE_ID || albumId == PHOTO_STREAM_NODE_ID)
	{
		return YES;
	}
	
	// Usage of other albums is determined by media type of key list images
	
	NSArray* imageKeys = inAlbumDict[@"KeyList"];
	
	for (NSString* key in imageKeys)
	{
		NSDictionary* imageDict = inImages[key];
		
		if ([self shouldUseObject:imageDict])
		{
			return YES;
		}
	}
	
	return NO;
}


// Check if a media file qualifies for this parser...

- (BOOL) shouldUseObject:(NSDictionary*)inObjectDict
{
	NSString* iPhotoMediaType = [self iPhotoMediaType];
	
	if (inObjectDict)
	{
		NSString* mediaType = inObjectDict[@"MediaType"];
		if (mediaType == nil) mediaType = @"Image";
		
		if ([mediaType isEqualToString:iPhotoMediaType])
		{
			return YES;
		}
	}
	
	return NO;
}


//----------------------------------------------------------------------------------------------------------------------


- (NSImage*) iconForAlbumType:(NSString*)inAlbumType highlight:(BOOL)inHighlight
{
	static const IMBIconTypeMappingEntry kIconTypeMappingEntries[] =
	{
        // Icon Type                Application Icon Name            Fallback Icon Name
        
		// iPhoto 7
		{@"Book",					@"sl-icon-small_book",				@"folder",	nil,				nil},
		{@"Calendar",				@"sl-icon-small_calendar",			@"folder",	nil,				nil},
		{@"Card",					@"sl-icon-small_card",				@"folder",	nil,				nil},
		{@"Event",					@"sl-icon-small_event",             @"folder",	nil,				nil},
		{@"Events",					@"sl-icon-small_events",			@"folder",	nil,				nil},
		{@"Faces",					@"sl-icon-small_people",			@"folder",	nil,				nil},
		{@"Flagged",				@"sl-icon-small_flag",				@"folder",	nil,				nil},
		{@"Folder",					@"sl-icon-small_folder",			@"folder",	nil,				nil},
		{@"Photo Stream",			@"sl-icon-small_photostream",		@"folder",	nil,				nil},
		{@"Photocasts",				@"sl-icon-small_subscriptions",     @"folder",	nil,				nil},
		{@"Photos",					@"sl-icon-small_library",			@"folder",	nil,				nil},
		{@"Published",				@"sl-icon-small_publishedAlbum",	nil,		@"dotMacLogo.icns",	@"/System/Library/CoreServices/CoreTypes.bundle"},
		{@"Regular",				@"sl-icon-small_album",             @"folder",	nil,				nil},
		{@"Roll",					@"sl-icon-small_roll",				@"folder",	nil,				nil},
		{@"Selected Event Album",	@"sl-icon-small_event",             @"folder",	nil,				nil},
		{@"Shelf",					@"sl-icon_flag",					@"folder",	nil,				nil},
		{@"Slideshow",				@"sl-icon-small_slideshow",         @"folder",	nil,				nil},
		{@"Smart",					@"sl-icon-small_smartAlbum",		@"folder",	nil,				nil},
		{@"Special Month",			@"sl-icon-small_cal",				@"folder",	nil,				nil},
		{@"Last Import",			@"sl-icon_lastImport",				@"folder",	nil,				nil},
		{@"Subscribed",				@"sl-icon-small_subscribedAlbum",	@"folder",	nil,				nil},
		{@"Wildcard",				@"sl-icon-small_album",             @"folder",	nil,				nil}	// fallback image
	};
	
	static const IMBIconTypeMapping kIconTypeMapping =
	{
		sizeof(kIconTypeMappingEntries) / sizeof(kIconTypeMappingEntries[0]),
		kIconTypeMappingEntries,
        @"-sel"
	};
	
    
    
	NSString* type = inAlbumType;
	if (type == nil) type = @"Photos";
	return [[IMBIconCache sharedIconCache] iconForType:type
                                          fromBundleID:@"com.apple.iPhoto"
                                      withMappingTable:&kIconTypeMapping
                                             highlight:inHighlight];
}


//----------------------------------------------------------------------------------------------------------------------


- (BOOL) isAllPhotosAlbum:(NSDictionary*)inAlbumDict
{
	return ((NSNumber *)inAlbumDict[@"Master"]).unsignedIntegerValue == 1;
}


//----------------------------------------------------------------------------------------------------------------------
// Returns whether inAlbumDict is the "Events" album.

- (BOOL) isEventsAlbum:(NSDictionary*)inAlbumDict
{
	return [inAlbumDict[@"Album Type"] isEqualToString:@"Events"];
}


//----------------------------------------------------------------------------------------------------------------------
// Returns whether inAlbumDict is an "Event" album.

- (BOOL) isEventAlbum:(NSDictionary*)inAlbumDict
{
	return [inAlbumDict[@"Album Type"] isEqualToString:@"Event"];
}


//----------------------------------------------------------------------------------------------------------------------


- (BOOL) isFlaggedAlbum:(NSDictionary*)inAlbumDict
{
    NSString *albumType = inAlbumDict[@"Album Type"];
    
	return ([albumType isEqualTo:@"Shelf"] ||        // iPhoto 8
            [albumType isEqualTo:@"Flagged"]);       // iPhoto 9
}


//----------------------------------------------------------------------------------------------------------------------
// NOTE: This method is neither being used to add events sub nodes nor to add faces sub nodes.
//       This is done in their respective populate methods.

- (void) addSubNodesToNode:(IMBNode*)inParentNode albums:(NSArray*)inAlbums images:(NSDictionary*)inImages
{
	// Create the subNodes array on demand - even if turns out to be empty after exiting this method, 
	// because without creating an array we would cause an endless loop...
	
	NSMutableArray* subnodes = [inParentNode mutableArrayForPopulatingSubnodes];
	
	// Now parse the iPhoto XML plist and look for albums whose parent matches our parent node. We are 
	// only going to add subnodes that are direct children of inParentNode...
	
	for (NSDictionary* albumDict in inAlbums)
	{
		NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
		
		NSString* albumType = [self typeForAlbum:albumDict];
		NSString* albumName = albumDict[@"AlbumName"];
		NSNumber* parentId = albumDict[@"Parent"];
        
		NSString* albumIdSpace = [self idSpaceForAlbumType:albumType];
        
		// parent always from same id space for non top-level albums
		NSString* parentIdentifier = parentId ? [self identifierForId:parentId inSpace:albumIdSpace] : [self rootNodeIdentifier];
		
		if (![self isEventAlbum:albumDict] &&
            [self shouldUseAlbumType:albumType] &&
			[inParentNode.identifier isEqualToString:parentIdentifier] && 
			[self shouldUseAlbum:albumDict images:inImages])
		{
			// Create node for this album...
			
			IMBNode* albumNode = [[[IMBNode alloc] initWithParser:self topLevel:NO] autorelease];
			
			albumNode.isLeafNode = [self isLeafAlbumType:albumType];
			albumNode.icon = [self iconForAlbumType:albumType highlight:NO];
			albumNode.highlightIcon = [self iconForAlbumType:albumType highlight:YES];
			albumNode.name = [self localizedNameForAlbumName:albumName];
			albumNode.watchedPath = inParentNode.watchedPath;	// These two lines are important to make file watching work for nested
			albumNode.watcherType = kIMBWatcherTypeNone;        // subfolders. See IMBLibraryController _reloadNodesWithWatchedPath:
			
			// Set the node's identifier. This is needed later to link it to the correct parent node. Please note 
			// that older versions of iPhoto didn't have AlbumId, so we are generating fake AlbumIds in this case
			// for backwards compatibility...
			
			NSNumber* albumId = albumDict[@"AlbumId"];
			if (albumId == nil) albumId = @(_fakeAlbumID++); 
			albumNode.identifier = [self identifierForId:albumId inSpace:albumIdSpace];
			
			// Keep a ref to the album dictionary for later use when we populate this node
			// so we don't have to loop through the whole album list again to find it.
			
			albumNode.attributes = @{@"nodeSource": albumDict,
                                    @"nodeType": [self nodeTypeForNode:albumNode]};
			
			// Add the new album node to its parent (inRootNode)...
			
			[subnodes addObject:albumNode];
		}
		
		[pool drain];
	}
}


//----------------------------------------------------------------------------------------------------------------------


// Returns the path to a thumbnail containing the wanted clipped face in the image provided.
//
// There are reports (see issue 252) that ./Data occasionally is not a symbolic link
// to ./Data.noindex and faces we are looking for are not found in ./Data but ./Data.noindex.
// To account for this we return the image path including ./Data.noindex if necessary.

- (NSString*) imagePathForFaceIndex:(NSNumber*)inFaceIndex inImageWithKey:(NSString*)inImageKey
{
	NSString* imagePath = [super imagePathForFaceIndex:inFaceIndex inImageWithKey:inImageKey];
	
    NSFileManager *fileManager = [NSFileManager defaultManager];
	
	// Image path should currently be pointing to image in subdirectory of ./Data (iPhoto 8) or ./Thumbnails (iPhoto 9).
	
	if (![fileManager fileExistsAtPath:imagePath] ||
        [imagePath rangeOfString:@"missing_thumbnail"].location != NSNotFound) {
		
		// Oops, could not locate face image here. Provide alternate path
		NSLog(@"Could not find face image at %@", imagePath);
		
		NSString* pathPrefix = self.mediaSource.path.stringByDeletingLastPathComponent;
		NSString* replacement = @"/Data.noindex/";
		NSScanner* aScanner =  [[NSScanner alloc] initWithString:imagePath];
		
		if (([aScanner scanString:pathPrefix intoString:nil] && [aScanner scanString:@"/Data/" intoString:nil]) ||
			[aScanner scanString:@"/Thumbnails/" intoString:nil])
		{
			NSString* suffixString = [imagePath substringFromIndex:aScanner.scanLocation];
			imagePath = [NSString stringWithFormat:@"%@%@%@", pathPrefix, replacement, suffixString];
			NSLog(@"Trying %@...", imagePath);
		}
		[aScanner release];
	}
	return imagePath;
}


//---------------------------------------------------------------------------------------------------------------------


// Returns a dictionary that contains the "true" KeyList, KeyPhotoKey and PhotoCount values for the provided node.
// (The values provided by the according dictionary in .plist are mostly wrong because we separate node children by
// media types 'Image' and 'Movie' into different views.)

- (NSDictionary*) childrenInfoForNode:(NSDictionary*)inNodeDict images:(NSDictionary*)inImages
{
	// Determine images relevant to this view.
	// Note that everything regarding 'ImageFaceMetadata' is only relevant
	// when providing a faces node. Otherwise it will be nil'ed.
	
	NSArray* imageKeys = inNodeDict[@"KeyList"];
	NSMutableArray* relevantImageKeys = [NSMutableArray array];
	NSArray* imageFaceMetadataList = inNodeDict[@"ImageFaceMetadataList"];
	NSMutableArray* relevantImageFaceMetadataList = imageFaceMetadataList ? [NSMutableArray array] : nil;
	
	// Loop setup
	NSString* key = nil;
	NSDictionary* imageFaceMetadata = nil;
	NSDictionary* imageDict = nil;
	
	for (NSUInteger i = 0; i < imageKeys.count; i++)
	{
		key = imageKeys[i];
		imageFaceMetadata = imageFaceMetadataList[i];
		
		imageDict = inImages[key];
		
		if ([self shouldUseObject:imageDict])
		{
			[relevantImageKeys addObject:key];
			
			if (imageFaceMetadata) [relevantImageFaceMetadataList addObject:imageFaceMetadata];
		}		
	}
	
	// Ensure that key image for movies is movie related:
	
	NSString* keyPhotoKey = nil;
	NSNumber* keyImageFaceIndex = nil;
	
	if ([[self iPhotoMediaType] isEqualToString:@"Movie"] && relevantImageKeys.count > 0)
	{
		keyPhotoKey = relevantImageKeys[0];
		keyImageFaceIndex = relevantImageFaceMetadataList[0][@"face index"];
	} else {
		keyPhotoKey = inNodeDict[@"KeyPhotoKey"];
	}

    return @{@"KeyList": relevantImageKeys,
			@"PhotoCount": @(relevantImageKeys.count), 
			@"KeyPhotoKey": keyPhotoKey,
			@"ImageFaceMetadataList": relevantImageFaceMetadataList,   // May be nil
			@"key image face index": keyImageFaceIndex};          // May be nil
}


//----------------------------------------------------------------------------------------------------------------------


// Create a subnode for each event and a corresponding visual object

- (void) populateEventsNode:(IMBNode*)inNode withEvents:(NSArray*)inEvents images:(NSDictionary*)inImages
{
	
	// Create the subNodes array on demand - even if turns out to be empty after exiting this method, 
	// because without creating an array we would cause an endless loop...
	
	NSMutableArray* subnodes = [inNode mutableArrayForPopulatingSubnodes];
	
	// Create the objects array on demand  - even if turns out to be empty after exiting this method, because
	// without creating an array we would cause an endless loop...
	
	NSMutableArray* objects = [NSMutableArray array];
	NSUInteger index = 0;
	
	// We saved a reference to the album dictionary when this node was created
	// (ivar 'attributes') and now happily reuse it to save an outer loop (over album list) here.
	
	NSString* subNodeType = @"Event";
	
	// Events node is populated with node objects that represent events
	
	NSString* thumbnailPath = nil;
	IMBiPhotoEventNodeObject* object = nil;
	
	for (id subnodeDict in inEvents)
	{
		NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];

		NSString* subnodeName = subnodeDict[@"RollName"];
		
		if ([self shouldUseAlbumType:subNodeType] && 
			[self shouldUseAlbum:subnodeDict images:inImages])
		{
            // Validate node dictionary and repair if necessary
            // For that we need a mutable version of node dictionary
            
            subnodeDict = [NSMutableDictionary dictionaryWithDictionary:subnodeDict];
            
			// Adjust keys "KeyPhotoKey", "KeyList", and "PhotoCount" in metadata dictionary because movies and
			// images are not jointly displayed in iMedia browser...
			
			[subnodeDict addEntriesFromDictionary:[self childrenInfoForNode:subnodeDict images:inImages]];
            
            if (![self ensureValidKeyPhotoKeyForSkimmableNode:subnodeDict relativeToMasterImageList:inImages]) {
                continue;
            }
            
			// Create subnode for this node...
			
			IMBNode* subnode = [[[IMBNode alloc] initWithParser:self topLevel:NO] autorelease];
			
			subnode.isLeafNode = [self isLeafAlbumType:subNodeType];
			subnode.icon = [self iconForAlbumType:subNodeType highlight:NO];
			subnode.highlightIcon = [self iconForAlbumType:subNodeType highlight:YES];
			subnode.name = subnodeName;
			subnode.isIncludedInPopup = NO;
			subnode.watchedPath = inNode.watchedPath;	// These two lines are important to make file watching work for nested 
			subnode.watcherType = kIMBWatcherTypeNone;  // subfolders. See IMBLibraryController _reloadNodesWithWatchedPath:
			
			// Keep a ref to the subnode dictionary for potential later use
			
			subnode.attributes = @{@"nodeSource": subnodeDict,
                                  @"nodeType": [self nodeTypeForNode:subnode]};
			
			// Set the node's identifier. This is needed later to link it to the correct parent node. Please note 
			// that older versions of iPhoto didn't have AlbumId, so we are generating fake AlbumIds in this case
			// for backwards compatibility...
			
			NSNumber* subnodeId = subnodeDict[@"RollID"];
			if (subnodeId == nil) subnodeId = @(_fakeAlbumID++); 
			subnode.identifier = [self identifierForId:subnodeId inSpace:EVENTS_ID_SPACE];
			
			// Add the new subnode to its parent (inRootNode)...

			[subnodes addObject:subnode];
			
			// Now create the visual object and link it to subnode just created...

			object = [[IMBiPhotoEventNodeObject alloc] init];
			[objects addObject:object];
			[object release];
			
			object.preliminaryMetadata = subnodeDict;           // This metadata from the XML file is available immediately
            [object resetCurrentSkimmingIndex];                 // Must be done *after* preliminaryMetadata is set
			object.metadata = nil;								// Build lazily when needed (takes longer)
			object.metadataDescription = nil;					// Build lazily when needed (takes longer)
            object.name = subnode.name;
			
            object.representedNodeIdentifier = subnode.identifier;
            
            // NOTE: Since events represent multiple resources we do not set their "location" property
            
            object.parserIdentifier = self.identifier;
            object.index = index++;
            
            thumbnailPath = [self thumbnailPathForImageKey:subnodeDict[@"KeyPhotoKey"]];
            object.imageLocation = (id)[NSURL fileURLWithPath:thumbnailPath isDirectory:NO];
            object.imageRepresentationType = IKImageBrowserCGImageRepresentationType;
            object.imageRepresentation = nil;
		}
		[pool drain];
	}
	inNode.objects = objects;
	
}


- (void) populateAlbumNode:(IMBNode*)inNode images:(NSDictionary*)inImages
{

	// Create the objects array on demand  - even if turns out to be empty after exiting this method, because
	// without creating an array we would cause an endless loop...
	
	NSMutableArray* objects = [NSMutableArray array];
	
	// Populate the node with IMBVisualObjects for each image in the album
	
	NSUInteger index = 0;
	Class objectClass = [self objectClass];
	
	// We saved a reference to the album dictionary when this node was created
	// (ivar 'attributes') and now happily reuse it to save an outer loop (over album list) here.
	
	NSDictionary* albumDict = (inNode.attributes)[@"nodeSource"];
	NSArray* imageKeys = albumDict[@"KeyList"];
	
	for (NSString* key in imageKeys)
	{
		NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
		NSDictionary* imageDict = inImages[key];
		
		if ([self shouldUseObject:imageDict])
		{
			NSString* path = imageDict[@"ImagePath"];
			NSString* name = imageDict[@"Caption"];
			if ([name isEqualToString:@""])
			{
				name = path.lastPathComponent.stringByDeletingPathExtension;	// fallback to filename
			}
			
			IMBObject* object = [[objectClass alloc] init];
			[objects addObject:object];
			[object release];
			
			object.location = [NSURL fileURLWithPath:path isDirectory:NO];
            object.accessibility = [self accessibilityForObject:object];
			object.name = name;
            
            NSMutableDictionary *metadata = [imageDict mutableCopy];
            metadata[@"iPhotoKey"] = key;   // so pasteboard-writing code can retrieve it later
			object.preliminaryMetadata = metadata;	// This metadata from the XML file is available immediately
            [metadata release];
            
			object.metadata = nil;					// Build lazily when needed (takes longer)
			object.metadataDescription = nil;		// Build lazily when needed (takes longer)
			object.parserIdentifier = self.identifier;
			object.index = index++;
			
            
			object.imageLocation = (id)[NSURL fileURLWithPath:[self imageLocationForObject:imageDict] isDirectory:NO];
			object.imageRepresentationType = [self requestedImageRepresentationType];
			object.imageRepresentation = nil;
		}
		
		[pool drain];
	}
	
	NSSortDescriptor* dateDescriptor = [[[NSSortDescriptor alloc]
                                         initWithKey:@"preliminaryMetadata.DateAsTimerInterval"
                                         ascending:YES] autorelease];
	NSArray* sortDescriptors = @[dateDescriptor];
    
    inNode.objects = [objects sortedArrayUsingDescriptors:sortDescriptors];
}


//--------------------------------------------------------------------------------------------------
// Returns array of all image dictionaries that belong to the Photo Stream (sorted by date).
// It will also exclude duplicate objects in terms of the image's "PhotoStreamAssetId".

- (NSArray *) photoStreamObjectsFromImages:(NSDictionary*)inImages
{
    NSMutableArray *photoStreamObjectDictionaries = [NSMutableArray array];
    NSDictionary *imageDict = nil;
    NSMutableSet *assetIds = [NSMutableSet set];
	
	for (NSString *imageKey in inImages)
	{
        imageDict = inImages[imageKey];
		
        // Being a member of Photo Stream is determined by having a non-empty Photo Stream asset id.
        // Add objects with the same asset id only once.
        
        NSString *photoStreamAssetId = imageDict[@"PhotoStreamAssetId"];
		if (photoStreamAssetId && photoStreamAssetId.length > 0 &&
            ![assetIds member:photoStreamAssetId] &&
            [self shouldUseObject:imageDict])
		{
            NSMutableDictionary *metadata = [imageDict mutableCopy];
            metadata[@"iPhotoKey"] = imageKey;   // so pasteboard-writing code can retrieve it later
            [assetIds addObject:photoStreamAssetId];
            [photoStreamObjectDictionaries addObject:metadata];
            [metadata release];
        }
    }
    // After collecting all Photo Stream object dictionaries sort them by date
    
	NSSortDescriptor* dateDescriptor = [[NSSortDescriptor alloc] initWithKey:@"DateAsTimerInterval" ascending:YES];
	NSArray* sortDescriptors = @[dateDescriptor];
	[dateDescriptor release];
	
    NSArray *sortedObjectDictionaries = [photoStreamObjectDictionaries sortedArrayUsingDescriptors:sortDescriptors];
    
    return sortedObjectDictionaries;
}


//--------------------------------------------------------------------------------------------------
// Populates the Photo Stream node.

- (void) populatePhotoStreamNode:(IMBNode*)inNode images:(NSDictionary*)inImages
{

    // Pull all Photo Stream objects from the inImages dictionary (should be master image list) sorted by date
    
    NSArray *sortedPhotoStreamObjectDictionaries = [self photoStreamObjectsFromImages:inImages];
    
	// Create the subNodes array on demand - even if turns out to be empty after exiting this method, 
	// because without creating an array we would cause an endless loop...
	
	[inNode mutableArrayForPopulatingSubnodes];
	
	// Create the objects array on demand  - even if turns out to be empty after exiting this method, because
	// without creating an array we would cause an endless loop...
	
	NSMutableArray* objects = [[NSMutableArray alloc] initWithArray:inNode.objects];
	
	// Populate the node with IMBVisualObjects for each image in the album
	
	NSUInteger index = 0;
	Class objectClass = [self objectClass];
	
	for (NSDictionary *imageDict in sortedPhotoStreamObjectDictionaries)
	{
		NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
		
        NSString* path = imageDict[@"ImagePath"];
        NSString* name = imageDict[@"Caption"];
        if ([name isEqualToString:@""])
        {
            name = path.lastPathComponent.stringByDeletingPathExtension;	// fallback to filename
        }
        
        IMBObject* object = [[objectClass alloc] init];
        [objects addObject:object];
        [object release];
        
        object.location = [NSURL fileURLWithPath:path isDirectory:NO];
        object.accessibility = [self accessibilityForObject:object];
        object.name = name;
        object.preliminaryMetadata = imageDict;	// This metadata from the XML file is available immediately
        object.metadata = nil;					// Build lazily when needed (takes longer)
        object.metadataDescription = nil;		// Build lazily when needed (takes longer)
        object.parserIdentifier = self.identifier;
        object.index = index++;
        
        object.imageLocation = (id)[NSURL fileURLWithPath:[self imageLocationForObject:imageDict] isDirectory:NO];
        object.imageRepresentationType = [self requestedImageRepresentationType];
        object.imageRepresentation = nil;
		
		[pool drain];
	}
	
    inNode.objects = objects;
    [objects release];

}


//----------------------------------------------------------------------------------------------------------------------

#pragma mark - Library version specifics


// Get album type

- (NSString*) typeForAlbum:(NSDictionary*)album
{
    NSString* albumType = [album valueForKey:@"Album Type"];
    
    // Photos
    
    if ([albumType isEqualToString:@"99"] ||                                                        // Vers. 9.4
        (albumType == nil && [[album valueForKey:@"GUID"] isEqualToString:@"allPhotosAlbum"]) ||    // Vers. 9.3
        (albumType == nil && [[album valueForKey:@"AlbumId"] unsignedIntegerValue] == 2))           // Vers. 8.1.2
    {
        return @"Photos";
    }
    return [super typeForAlbum:album];
}

@end
