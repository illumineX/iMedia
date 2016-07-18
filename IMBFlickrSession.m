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

//  iMedia
#import "IMBFlickrNode.h"
#import "IMBFlickrObject.h"
#import "IMBFlickrParserMessenger.h"
#import "IMBFlickrSession.h"



//#define VERBOSE

//	We need this to make the Flickr request don't use the run loop and block on the current thread. As discussed with Lukhnos D. Liu (author of Objective Flickr).
@interface OFFlickrAPIRequest (private)
- (void) setShouldWaitUntilDone: (BOOL) wait;
@end

@implementation OFFlickrAPIRequest (private)

- (void) setShouldWaitUntilDone: (BOOL) wait {
	HTTPRequest.shouldWaitUntilDone = wait;
}

@end

#pragma mark -

@interface IMBFlickrSession ()
//	Flickr Response Handling:
- (NSString*) flickrSizeFromFlickrSizeSpecifier: (IMBFlickrSizeSpecifier) flickrSizeSpecifier;
- (NSURL*) imageURLForDesiredSize: (IMBFlickrSizeSpecifier) size fromPhotoDict: (NSDictionary*) photoDict context: (OFFlickrAPIContext*) context;
@end

#pragma mark -

@implementation IMBFlickrSession

#pragma mark 
#pragma mark Construction & Destruction

- (id) initWithFlickrContext: (OFFlickrAPIContext*) context {
	if ((self = [super init])) {
        _flickrContextWeakRef = context;
        NSAssert (context, @"Invalid Flickr context.");
	}
	
	return self;
}


- (void) dealloc {
    [_request cancel];
    _flickrContextWeakRef = nil;

	IMBRelease (_error);
	IMBRelease (_request);
    IMBRelease (_response);
	[super dealloc];
}


#pragma mark
#pragma mark Flickr Request Handling

///	Make the properties of the receiver into a dictionary with keys and values that can be directly passed to the Flick method call. Have a look at http://www.flickr.com/services/api/flickr.photos.search.html for details and arguments of a search query.
- (NSDictionary*) argumentsForNode: (IMBFlickrNode*) node {
	NSMutableDictionary* arguments = [NSMutableDictionary dictionary];
	
	//	build query arguments based on method...
	if (node.query) {
		if (node.method == IMBFlickrNodeMethod_TagSearch) {
			arguments[@"tags"] = node.query;
			arguments[@"tag_mode"] = @"all";
		} else if (node.method == IMBFlickrNodeMethod_TextSearch) {
			arguments[@"text"] = node.query;
		}
	}
	
	//	translate our user kinds into Flickr license kind ids...
	if (node.license == IMBFlickrNodeLicense_CreativeCommons) {
		arguments[@"license"] = [NSString stringWithFormat:@"%lu", (unsigned long)IMBFlickrNodeFlickrLicenseID_Attribution];
	} else if (node.license == IMBFlickrNodeLicense_DerivativeWorks) {
		arguments[@"license"] = [NSString stringWithFormat:@"%lu", (unsigned long)node.license];
	} else if (node.license == IMBFlickrNodeLicense_CommercialUse) {
		arguments[@"license"] = [NSString stringWithFormat:@"%lu", (unsigned long)IMBFlickrNodeFlickrLicenseID_NoKnownCopyrightRestrictions];
	}
	
	//	determine sort order...
	NSString* sortOrder = nil;
	if (node.sortOrder == IMBFlickrNodeSortOrder_DatePostedDesc) {
		sortOrder = @"date-posted-desc";
	} else if (node.sortOrder == IMBFlickrNodeSortOrder_DatePostedAsc) {
		sortOrder = @"date-posted-asc";		
	} else if (node.sortOrder == IMBFlickrNodeSortOrder_DateTakenAsc) {
		sortOrder = @"date-taken-asc";		
	} else if (node.sortOrder == IMBFlickrNodeSortOrder_DateTakenDesc) {
		sortOrder = @"date-taken-desc";		
	} else if (node.sortOrder == IMBFlickrNodeSortOrder_InterestingnessDesc) {
		sortOrder = @"interestingness-desc";		
	} else if (node.sortOrder == IMBFlickrNodeSortOrder_InterestingnessAsc) {
		sortOrder = @"interestingness-asc";		
	} else if (node.sortOrder == IMBFlickrNodeSortOrder_Relevance) {
		sortOrder = @"relevance";		
	}
	if (sortOrder) {
		arguments[@"sort"] = sortOrder;
	}
	
	//	limit the search to a specific number of items...
	arguments[@"per_page"] = @"30";
	
	// We are only doing photos.  Maybe later we want to do videos?
	arguments[@"media"] = @"photos";
	
	// Extra metadata needed
	// http://www.flickr.com/services/api/flickr.photos.search.html
	arguments[@"extras"] = @"description,license,owner_name,original_format,geo,tags,o_dims,url_o,url_l,url_m,url_s,usage";
	// Useful keys we can get from this:
	// description -> array with ... description
	// original_format -> originalformat, orignalsecret
	// url_o,l, m, s ... URL to get the various sizes.  (url_l is not really documented, but works if needed.)
	// usage: can_download (& others)
	// Example of a photo that can't be downloaded: THE DECEIVING title.
	
	//	load the specified page...
	NSString* page = [NSString stringWithFormat:@"%ld", (long)node.page + 1];
	arguments[@"page"] = page;
	
	return arguments;
}


- (void) executeFlickRequestForNode: (IMBFlickrNode*) node {
    if (!node) return;
    
    //  cancel a possibly already running request...
    if (_request) {
        [_request cancel];
        IMBRelease (_request);
    }

    //	create a new Flickr request...
    _request = [[OFFlickrAPIRequest alloc] initWithAPIContext:_flickrContextWeakRef];
    _request.delegate = self;
    _request.requestTimeoutInterval = 60.0f;
    
    //  CAUTION: Make this request a sync call!
    [_request setShouldWaitUntilDone:YES];

    //	determine request contents...
    NSString* method = [self.class flickrMethodForMethodCode:node.method];
    NSDictionary* arguments = [self argumentsForNode:node];
    #ifdef VERBOSE
        NSLog (@"Flickr request created for method '%@' and arguments: %@", method, arguments);
    #endif
    
    //  start HTTP request...
    [_request callAPIMethodWithGET:method arguments:arguments];
}


- (void) flickrAPIRequest: (OFFlickrAPIRequest*) inRequest 
  didCompleteWithResponse: (NSDictionary*) inResponseDictionary {
	
    #ifdef VERBOSE
        NSLog (@"Flickr request completed for request '%@'.", inRequest);
    #endif
    
	//	save Flickr response in our iMB node for later population of the browser...
	self.response = (inResponseDictionary) ? inResponseDictionary : @{};
}


- (void) flickrAPIRequest: (OFFlickrAPIRequest*) inRequest 
		 didFailWithError: (NSError*) inError {
	
	NSLog (@"Flickr API request did fail with error: %@", inError);
    self.error = inError;
}


+ (NSString*) flickrMethodForMethodCode: (NSInteger) code {
	if (code == IMBFlickrNodeMethod_TagSearch || code == IMBFlickrNodeMethod_TextSearch) {
		return @"flickr.photos.search";
	} else if (code == IMBFlickrNodeMethod_Recent) {
		return @"flickr.photos.getRecent";
	} else if (code == IMBFlickrNodeMethod_MostInteresting) {
		return @"flickr.interestingness.getList";
	} else if (code == IMBFlickrNodeMethod_GetInfo) {
		return @"flickr.photos.getInfo";
	}
	NSLog (@"Can't find Flickr method for method code.");
	return nil;
}


#pragma mark
#pragma mark Flickr Response Handling

#if 0
///	Processes the 'flickrResponse' dictionary to fill the node with actual images.
- (void) processResponseForContext: (OFFlickrAPIContext*) context {	
	if (!self.hasFlickrResponse) return;
	
	//	TODO: Instead of inserting the "load more" object at the end of the array, we should probably associate a sort descriptor with the image view.
	NSMutableArray* oldImages = [self.objects mutableCopy];
	IMBLoadMoreObject* loadMoreObject = nil;
	for (id object in oldImages) {
		if ([object isKindOfClass:[IMBLoadMoreObject class]]) {
			loadMoreObject = object;
			break;
		}
	}
	if (loadMoreObject) {		
		[oldImages removeObject:loadMoreObject];
	}
	
	NSMutableArray* newImages = [[self extractPhotosFromFlickrResponse:[self flickrResponse] context:context] mutableCopy];
	[newImages removeObjectsInArray:oldImages]; //	ensure that we have no doubles
	
    if ( [oldImages count] ) {
        [newImages insertObjects:oldImages atIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, oldImages.count)]];
    }
	
	//	add 'load more' button...
	IMBLoadMoreObject* loadMoreButton = ((IMBFlickrParserMessenger*) self.parserMessenger).loadMoreButton;
	loadMoreButton.nodeIdentifier = self.identifier;
	[newImages addObject:loadMoreButton];
    
	self.objects = newImages;
	
	[newImages release];
	[oldImages release];
}
#endif


- (NSArray*) extractPhotosFromFlickrResponseForParserMessenger: (IMBFlickrParserMessenger*) parserMessenger {
    NSDictionary* response = self.response;
    if (!response) {
        return [NSArray array];
    }
    
	NSArray* photos = [response valueForKeyPath:@"photos.photo"];
	NSMutableArray* objects = [NSMutableArray arrayWithCapacity:photos.count];
    //	self.displayedObjectCount = 0;
	
	for (NSDictionary* photoDict in photos) {
        
		IMBFlickrObject* obj = [[IMBFlickrObject alloc] init];
		
		// Only store a location if we are allowed to download
		BOOL canDownload = [photoDict[@"can_download"] boolValue];
		if (canDownload) {
			obj.location = [self imageURLForDesiredSize:parserMessenger.desiredSize fromPhotoDict:photoDict context:_flickrContextWeakRef];
		}
		obj.shouldDisableTitle = !canDownload;
        
		obj.name = photoDict[@"title"];
		
		// A lot of the metadata comes from the "extras" key we request
		NSMutableDictionary* metadata = [NSMutableDictionary dictionary];
		[metadata addEntriesFromDictionary:photoDict];		// give metaData the whole thing!
		NSURL* webPageURL = [_flickrContextWeakRef photoWebPageURLFromDictionary:photoDict];
		metadata[@"webPageURL"] = webPageURL;
		
		NSURL* quickLookURL = [self imageURLForDesiredSize:kIMBFlickrSizeSpecifierMedium fromPhotoDict:photoDict context:_flickrContextWeakRef];
		metadata[@"quickLookURL"] = quickLookURL;
        
		// But give it a better 'description' without the nested item
		NSString* descHTML = photoDict[@"description"][@"_text"];
		if (descHTML) {
			NSData* HTMLData = [descHTML dataUsingEncoding:NSUTF8StringEncoding];
			NSDictionary* options = @{NSCharacterEncodingDocumentOption: [NSNumber numberWithInt:NSUTF8StringEncoding]};
			NSAttributedString* descAttributed = [[[NSAttributedString alloc] initWithHTML:HTMLData options:options documentAttributes:nil] autorelease];
			if (descAttributed) {
				NSString* desc = descAttributed.string;
				if (nil != desc) metadata[@"comment"] = desc;
			}
            #ifdef VERBOSE
                else NSLog (@"Unable to make attributed string out of %@", descHTML);
            #endif
		}
        
		id width = metadata[@"width_o"];
		if (width == nil) width = metadata[@"width_l"];
		if (width == nil) width = metadata[@"width_m"];
		if (width == nil) width = metadata[@"width_s"];
        
		id height = metadata[@"height_o"];
		if (height == nil) height = metadata[@"height_l"];
		if (height == nil) height = metadata[@"height_m"];
		if (height == nil) height = metadata[@"height_s"];
		
		NSString* can_download = photoDict[@"can_download"];
		NSString* license = photoDict[@"license"];
		NSString* ownerName = photoDict[@"ownername"];
		NSString* photoID = photoDict[@"id"];
        
		if (nil != can_download)	metadata[@"can_download"] = can_download;
		if (nil != license)			metadata[@"license"] = license;
		if (nil != ownerName)		metadata[@"ownername"] = ownerName;
		if (nil != photoID)			metadata[@"id"] = photoID;
		if (nil != width)			metadata[@"width"] = width;
		if (nil != height)			metadata[@"height"] = height;
        
		obj.preliminaryMetadata = [NSDictionary dictionaryWithDictionary:metadata];
        
		obj.parserMessenger = parserMessenger;
		
		NSURL* thumbnailURL = [_flickrContextWeakRef photoSourceURLFromDictionary:photoDict size:OFFlickrThumbnailSize];
		obj.imageLocation = thumbnailURL;
		obj.imageRepresentationType = IKImageBrowserCGImageRepresentationType;
		obj.imageRepresentation = nil;	// Build lazily when needed
		
		[objects addObject:obj];
		[obj release];
        
        //		self.displayedObjectCount++;
	}
	
	return objects;
}


- (NSString*) flickrSizeFromFlickrSizeSpecifier: (IMBFlickrSizeSpecifier) flickrSizeSpecifier {
	NSAssert (flickrSizeSpecifier >= kIMBFlickrSizeSpecifierOriginal && flickrSizeSpecifier <= kIMBFlickrSizeSpecifierLarge, @"Illegal size for flickr");
	NSString* sizeLookup[] = { @"o", OFFlickrSmallSize, OFFlickrMediumSize, OFFlickrLargeSize };
    // Note: medium is nil, so we can't put in a dictionary.  Original not specified in objective-flickr
	return sizeLookup[flickrSizeSpecifier];
}


- (NSURL*) imageURLForDesiredSize: (IMBFlickrSizeSpecifier) size
                    fromPhotoDict: (NSDictionary*) photoDict 
                          context: (OFFlickrAPIContext*) context {
    
	NSURL* imageURL = nil;
	
    if (!imageURL && kIMBFlickrSizeSpecifierOriginal == size) {
		if (photoDict[@"url_o"]) {
			imageURL = [NSURL URLWithString:photoDict[@"url_o"]];
		} else {
			size = kIMBFlickrSizeSpecifierLarge;    // downgrade to requesting large if no original
		}
	}
    
	if (!imageURL && kIMBFlickrSizeSpecifierLarge == size) {
		if (photoDict[@"url_l"]) {
			imageURL = [NSURL URLWithString:photoDict[@"url_l"]];
		} else {
			size = kIMBFlickrSizeSpecifierMedium;   // downgrade to requesting medium if no large
		}
	}
	
	if (!imageURL && kIMBFlickrSizeSpecifierMedium == size)	{
		if (photoDict[@"url_m"]) {
			imageURL = [NSURL URLWithString:photoDict[@"url_m"]];
		} else {
			size = kIMBFlickrSizeSpecifierSmall;    // downgrade to requesting small if no medium
		}
	}
	
	if (!imageURL && kIMBFlickrSizeSpecifierSmall == size) {
		if (photoDict[@"url_s"]) {
			imageURL = [NSURL URLWithString:photoDict[@"url_s"]];
		}
	}
	
	//  Fallback. Really we should have it by now! But search for Edward & Bella Icon has no medium size!
	if (!imageURL) {
		//  build up URL programatically...
		NSString* flickrSize = [self flickrSizeFromFlickrSizeSpecifier:size];
		imageURL = [context photoSourceURLFromDictionary:photoDict size:flickrSize];
	}
    
	return imageURL;	
}


#pragma mark 
#pragma mark Properties

@synthesize error = _error;
@synthesize response = _response;

@end
