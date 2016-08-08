/*
 iMedia Browser Framework <https://karelia.com/imedia/>
 
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

//	iMedia
#import "IMBFlickrNode.h"
#import "IMBFlickrObject.h"
#import "IMBFlickrParser.h"
#import "IMBFlickrParserMessenger.h"
#import "IMBFlickrSession.h"
#import "IMBLibraryController.h"
#import "IMBLoadMoreObject.h"
#import "NSString+iMedia.h"
#import "IMBNodeViewController.h"
#import "IMBFlickrHeaderViewController.h"



@interface IMBFlickrNode ()
//	Utilities:
+ (NSString*) identifierWithMethod: (NSInteger) method query: (NSString*) query;
@end

#pragma mark -

@implementation IMBFlickrNode

NSString* const IMBFlickrNodeProperty_License = @"license";
NSString* const IMBFlickrNodeProperty_Method = @"method";
NSString* const IMBFlickrNodeProperty_Query = @"query";
NSString* const IMBFlickrNodeProperty_SortOrder = @"sortOrder";
NSString* const IMBFlickrNodeProperty_UUID = @"uuid";


#pragma mark
#pragma mark Construction

- (instancetype) init {
	if ((self = [super init])) {
		self.license = IMBFlickrNodeLicense_Undefined;
		self.method = IMBFlickrNodeMethod_TextSearch;
		self.sortOrder = IMBFlickrNodeSortOrder_InterestingnessDesc;		
	}
	return self;
}


- (instancetype) initWithCoder: (NSCoder*) inCoder {
	if ((self = [super initWithCoder:inCoder])) {
        self.customNode = [inCoder decodeBoolForKey:@"customNode"];
        self.license = [inCoder decodeIntegerForKey:@"license"];
        self.method = [inCoder decodeIntegerForKey:@"method"];
        self.page = [inCoder decodeIntegerForKey:@"page"];
        self.query = [inCoder decodeObjectForKey:@"query"];
        self.sortOrder = [inCoder decodeIntegerForKey:@"sortOrder"];
	}
	
	return self;
}


- (id) copyWithZone: (NSZone*) inZone {
	IMBFlickrNode* copy = [super copyWithZone:inZone];
	copy.customNode = self.customNode;
	copy.license = self.license;
	copy.method = self.method;
	copy.page = self.page;
	copy.query = self.query;
	copy.sortOrder = self.sortOrder;
	return copy;
}


- (void) encodeWithCoder: (NSCoder*) inCoder {
	[super encodeWithCoder:inCoder];

	[inCoder encodeBool:self.customNode forKey:@"customNode"];
	[inCoder encodeInteger:self.license forKey:@"license"];
	[inCoder encodeInteger:self.method forKey:@"method"];
	[inCoder encodeInteger:self.page forKey:@"page"];
	[inCoder encodeObject:self.query forKey:@"query"];
	[inCoder encodeInteger:self.sortOrder forKey:@"sortOrder"];
}


+ (IMBFlickrNode*) genericFlickrNodeForRoot: (IMBFlickrNode*) root
									 parser: (IMBParser*) parser {
	
	IMBFlickrNode* node = [[[IMBFlickrNode alloc] init] autorelease];
	node.attributes = [NSMutableDictionary dictionary];
	node.isLeafNode = YES;
	node.parserMessenger = root.parserMessenger;
	
	//	Leaving subNodes and objects nil, will trigger a populateNode:options:error: as soon as the root node is opened.
	//node.subnodes = nil;
	//node.objects = nil;
	
	node.badgeTypeNormal = kIMBBadgeTypeReload;
	node.badgeTarget = self;
	node.badgeSelector = @selector (reloadNode:);
	
	return node;
}


+ (IMBFlickrNode*) flickrNodeForInterestingPhotosForRoot: (IMBFlickrNode*) root
												  parser: (IMBParser*) parser {
	
	IMBFlickrNode* node = [self genericFlickrNodeForRoot:root parser:parser];
	node.icon = [NSImage imageNamed:NSImageNameFolderSmart];
	(node.icon).size = NSMakeSize(16.0, 16.0);
	node.identifier = [self identifierWithMethod:IMBFlickrNodeMethod_MostInteresting query:@"30"];
	//node.mediaSource = node.identifier;
	node.method = IMBFlickrNodeMethod_MostInteresting;
	node.name = NSLocalizedStringWithDefaultValue(@"IMBFlickrParser.node.mostinteresting",nil,IMBBundle(),@"Most Interesting",@"Flickr parser standard node name.");	
	node.sortOrder = IMBFlickrNodeSortOrder_DatePostedDesc;
	return node;
}


+ (IMBFlickrNode*) flickrNodeForRecentPhotosForRoot: (IMBFlickrNode*) root
											 parser: (IMBParser*) parser {
	
	IMBFlickrNode* node = [self genericFlickrNodeForRoot:root parser:parser];
	node.icon = [NSImage imageNamed:NSImageNameFolderSmart];
	(node.icon).size = NSMakeSize(16.0, 16.0);
	node.identifier = [self identifierWithMethod:IMBFlickrNodeMethod_Recent query:@"30"];
	//node.mediaSource = node.identifier;
	node.method = IMBFlickrNodeMethod_Recent;	
	node.name = NSLocalizedStringWithDefaultValue(@"IMBFlickrParser.node.recent",nil,IMBBundle(),@"Recent",@"Flickr parser standard node name.");
	node.sortOrder = IMBFlickrNodeSortOrder_DatePostedDesc;
	return node;
}


+ (IMBFlickrNode*) flickrNodeForRoot: (IMBFlickrNode*) root
							  parser: (IMBParser*) parser {

	//	iMB general...
	IMBFlickrNode* node = [[[IMBFlickrNode alloc] init] autorelease];
	node.parserMessenger = root.parserMessenger;
	node.isLeafNode = YES;	
	node.attributes = [NSMutableDictionary dictionary];
	
	//	Leaving subNodes and objects nil, will trigger a populateNode:options:error: 
	//	as soon as the root node is opened.
	//node.subNodes = nil;
	//node.objects = nil;
	
	node.badgeTypeNormal = kIMBBadgeTypeReload;
	node.badgeTarget = self;
	node.badgeSelector = @selector (reloadNode:);
	
	return node;
}


+ (IMBFlickrNode*) flickrNodeFromDictionary: (NSDictionary*) dictionary 
								   rootNode: (IMBFlickrNode*) root
									 parser: (IMBParser*) parser {
	
	IMBFlickrNode* node = [IMBFlickrNode flickrNodeForRoot:root parser:parser];
	[node readPropertiesFromDictionary:dictionary];
	return node;
}


+ (void) sendSelectNodeNotificationForDict:(NSDictionary*) dict {	
	if (dict) {
		NSString* identifier = [IMBFlickrNode identifierWithQueryParams:dict];
		[IMBNodeViewController selectNodeWithIdentifier:identifier];
	}
}


- (void) dealloc {
	IMBRelease (_query);
	[super dealloc];
}


#pragma mark
#pragma mark Properties

@synthesize customNode = _customNode;
@synthesize license = _license;
@synthesize method = _method;
@synthesize page = _page;
@synthesize query = _query;
@synthesize sortOrder = _sortOrder;


#pragma mark
#pragma mark Utilities

/// From https://gist.github.com/101674
+ (NSString*) base58EncodedValue: (long long) num {
	NSString* alphabet = @"123456789abcdefghijkmnopqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ";
	NSInteger baseCount = alphabet.length;
	NSString* encoded = @"";
	while (num >= baseCount) {
		double div = num/baseCount;
		long long mod = (num - (baseCount * (long long)div));
		NSString* alphabetChar = [alphabet substringWithRange: NSMakeRange(mod, 1)];
		encoded = [NSString stringWithFormat: @"%@%@", alphabetChar, encoded];
		num = (long long)div;
	}
	
	if (num) {
		encoded = [NSString stringWithFormat: @"%@%@", [alphabet substringWithRange: NSMakeRange(num, 1)], encoded];
	}
	return encoded;
}


+ (NSString*) descriptionOfLicense: (NSInteger) aLicenseNumber {
	NSString* result = nil;
	switch (aLicenseNumber)
	{
		case IMBFlickrNodeFlickrLicenseID_AttributionNonCommercialShareAlike:
			result = @"Attribution-NonCommercial-ShareAlike License";
			break;
		case IMBFlickrNodeFlickrLicenseID_AttributionNonCommercial:
			result = @"Attribution-NonCommercial License";
			break;
		case IMBFlickrNodeFlickrLicenseID_AttributionNonCommercialNoDerivs:
			result = @"Attribution-NonCommercial-NoDerivs License";
			break;
		case IMBFlickrNodeFlickrLicenseID_Attribution:
			result = @"Attribution License";
			break;
		case IMBFlickrNodeFlickrLicenseID_AttributionShareAlike:
			result = @"Attribution-ShareAlike License";
			break;
		case IMBFlickrNodeFlickrLicenseID_AttributionNoDerivs:
			result = @"Attribution-NoDerivs License";
			break;
	}
	if (result)
	{
		result = [@"Creative Commons: " stringByAppendingString:result];
	}
	return result;
}


///	We construct here something like: 
///	  IMBFlickrParser://flickr.photos.search/tag/macintosh,apple
///
///	TOOD: Maybe it's a better idea to just go with
///	  [NSString uuid]
///	and create something like:
///	  IMBFlickrParser://12345678-12345-12345-12345678
+ (NSString*) identifierWithMethod: (NSInteger) method query: (NSString*) query {
#if 0
	//	EXPERIMENTAL...
	NSString* parserClassName = NSStringFromClass ([IMBFlickrParser class]);
	return [NSString stringWithFormat:@"%@:/%@", parserClassName, [NSString uuid]];
	//	...EXPERIMENTAL
#else
	NSString* flickrMethod = [IMBFlickrSession flickrMethodForMethodCode:method];
	if (method == IMBFlickrNodeMethod_TagSearch) {
		flickrMethod = [flickrMethod stringByAppendingString:@"/tag"];
	} else if (method == IMBFlickrNodeMethod_TextSearch) {
		flickrMethod = [flickrMethod stringByAppendingString:@"/text"];
	} else if (method == IMBFlickrNodeMethod_Recent) {
		flickrMethod = [flickrMethod stringByAppendingString:@"/recent"];
	} else if (method == IMBFlickrNodeMethod_MostInteresting) {
		flickrMethod = [flickrMethod stringByAppendingString:@"/interesting"];
	}
	NSString* albumPath = [NSString stringWithFormat:@"/%@/%@", flickrMethod, query];
	NSString* parserClassName = NSStringFromClass ([IMBFlickrParser class]);
	return [NSString stringWithFormat:@"%@:/%@", parserClassName, albumPath];
#endif
}


+ (NSString*) identifierWithQueryParams: (NSDictionary*) inQueryParams {
	NSString* parserClassName = NSStringFromClass ([IMBFlickrParser class]);
	NSString* uuid = inQueryParams[IMBFlickrNodeProperty_UUID];
	if (uuid == nil) uuid = inQueryParams[IMBFlickrNodeProperty_Query];
	return [NSString stringWithFormat:@"%@:/%@",parserClassName,uuid];
}


- (void) readPropertiesFromDictionary: (NSDictionary*) dictionary {
	if (!dictionary) return;
	
	//	extract node data from preferences dictionary...
	NSInteger method = [dictionary[IMBFlickrNodeProperty_Method] intValue];
	NSString* query = dictionary[IMBFlickrNodeProperty_Query];
	NSString* title = query;
	
	if (!query || !title) {
		NSLog (@"Invalid Flickr parser user node dictionary.");
		return;
	}
	
	//	Flickr stuff...
	self.customNode = YES;
	self.icon = [NSImage imageNamed:NSImageNameFolderSmart];
	(self.icon).size = NSMakeSize(16.0, 16.0);
	self.identifier = [IMBFlickrNode identifierWithQueryParams:dictionary];
	self.license = [dictionary[IMBFlickrNodeProperty_License] intValue];
	//self.mediaSource = self.identifier;
	self.method = method;
	self.name = title;
	self.query = query;
	self.sortOrder = [dictionary[IMBFlickrNodeProperty_SortOrder] intValue];
}

@end
