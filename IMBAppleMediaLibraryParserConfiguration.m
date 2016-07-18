//
//  IMBAppleMediaLibraryParserConfiguration.m
//  iMedia
//
//  Created by Jörg Jacobsen on 06.03.15.
//
//

#import "IMBAppleMediaLibraryParserConfiguration.h"
#import "IMBAppleMediaLibraryPropertySynchronizer.h"
#import "NSImage+iMedia.h"
#import "MLMediaGroup+iMedia.h"
#import "IMBAppleMediaLibraryParserMessenger.h"

@implementation IMBAppleMediaLibraryParserConfiguration

/**
 Designated initiliazer.
 */
- (instancetype)initWithMediaSourceIdentifier:(NSString *)mediaSourceIdentifier
                   AppleMediaLibraryMediaType:(MLMediaType)mediaType
            identifiersOfNonUserCreatedGroups:(NSSet *)identifiersOfNonUserCreatedGroups
{
    if ((self = [super init])) {
        _mediaSourceIdentifier = mediaSourceIdentifier;
        _mediaType = mediaType;
        _identifiersOfNonUserCreatedGroups = identifiersOfNonUserCreatedGroups;
    }
    return self;
}

@synthesize mediaSourceIdentifier = _mediaSourceIdentifier;
@synthesize mediaSource = _mediaSource;
@synthesize mediaType = _mediaType;
@synthesize identifiersOfNonUserCreatedGroups = _identifiersOfNonUserCreatedGroups;

/**
 Returns the mediaSourceIdentifier of the receiver as the bundle identifier of the library's source app.
 */
- (NSString *)sourceAppBundleIdentifier
{
    return self.mediaSourceIdentifier;
}

/**
 Returns whether group (aka node) is populated with child group objects rather than real media objects.
 @discussion This default implementation returns NO.
 */
- (BOOL)shouldUseChildGroupsAsMediaObjectsForMediaGroup:(MLMediaGroup *)mediaGroup
{
    return NO;
}

/**
 @return Type of media group provided unified across all possible media sources.
 @discussion Default return value is kIMBMLMediaGroupTypeAlbum.
 */
- (IMBMLMediaGroupType *)typeForMediaGroup:(MLMediaGroup *)mediaGroup
{
    return kIMBMLMediaGroupTypeAlbum;
}

/**
 */
- (NSImage *)thumbnailForMediaObject:(MLMediaObject *)mediaObject
{
    NSURL *url = mediaObject.thumbnailURL;
    
    [url startAccessingSecurityScopedResource];
    
    NSImage *thumbnail = [[NSImage alloc] initWithContentsOfURL:url];
    
    [url stopAccessingSecurityScopedResource];
    
    return thumbnail;
}

/**
 */
- (NSDictionary *)metadataForMediaObject:(MLMediaObject *)mediaObject
{
    // Map metadata information from media library representation to iMedia representation
    
    NSMutableDictionary* externalMetadata = [NSMutableDictionary dictionaryWithDictionary:mediaObject.attributes];
    
    if (mediaObject.URL) {
        [mediaObject.URL startAccessingSecurityScopedResource];
        [externalMetadata addEntriesFromDictionary:[NSImage imb_metadataFromImageAtURL:mediaObject.URL checkSpotlightComments:NO]];
        [mediaObject.URL stopAccessingSecurityScopedResource];
    }
    
    return [NSDictionary dictionaryWithDictionary:externalMetadata];
}

/**
 */
- (NSString *)countFormatForGroup: (MLMediaGroup *)mediaGroup plural:(BOOL)plural
{
    NSString *localizationKey = nil;
    
    // Must deal with 3 dimensions:
    // - media type:  image, film, songs
    // - object type: non-leaf / leaf node
    // - cardinality: singular / plural
    
    static NSString *nonLeaf = @"NonLeaf";
    static NSString *leaf = @"Leaf";
    static NSDictionary *countFormatMap;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        countFormatMap = @{
                           @(MLMediaTypeImage) :
                               @{
                                   nonLeaf : @"IMBSkimmableObjectViewController.countFormat",
                                   leaf    : @"IMBImageViewController.countFormat"
                                   },
                           @(MLMediaTypeMovie) :
                               @{
                                   nonLeaf : @"IMBSkimmableObjectViewController.countFormat",
                                   leaf    : @"IMBMovieViewController.countFormat"
                                   },
                           @(MLMediaTypeAudio) :
                               @{
                                   nonLeaf : @"IMBSkimmableObjectViewController.countFormat",
                                   leaf    : @"IMBAudioViewController.countFormat"
                                   }
                           };
    });
    NSNumber *mediaType = @(self.mediaType);
    NSString *objectType = [self shouldUseChildGroupsAsMediaObjectsForMediaGroup:mediaGroup] ? nonLeaf : leaf;
    NSString *cardinality = plural ? @"Plural" : @"Singular";
    
    localizationKey = countFormatMap[mediaType][objectType];
    if (!localizationKey) {
        localizationKey = @"IMBSkimmableObjectViewController.countFormat";      // n objects
    }
    localizationKey = [localizationKey stringByAppendingString:cardinality];
    return NSLocalizedStringWithDefaultValue(localizationKey,
                                             nil, IMBBundle(), nil,
                                             @"Format string for object count");
}

/**
 */
- (NSDictionary *)metadataForMediaGroup:(MLMediaGroup *)mediaGroup
{
    // Map metadata information from media library representation to iMedia representation
    
    NSMutableDictionary* metadata = [NSMutableDictionary dictionary];
    NSInteger objectCount = NSNotFound;
    if ([self shouldUseChildGroupsAsMediaObjectsForMediaGroup:mediaGroup]) {
        objectCount = mediaGroup.childGroups.count;
    } else {
        // Objects displayed in group are leafs (images and the like)
        
        // At this point we cannot decide on how many objects we are dealing with
        // since this would require actually populating the media group (node)
        // where media type filters would be applied. This is too expensive.
//        objectCount = [[mediaGroup imb_mediaObjectCount] integerValue];
    }
    
    if (objectCount != NSNotFound) {
        NSString *objectCountFormat = [self countFormatForGroup:mediaGroup plural:objectCount != 1];
        
        if (objectCountFormat) {
            metadata[kIMBMetadataObjectCountDescriptionKey] = [NSString stringWithFormat:objectCountFormat, objectCount];
        }
    }
    return [NSDictionary dictionaryWithDictionary:metadata];
}

/**
 @return Last object in media object list of the receiver.
 */
- (MLMediaObject *)keyMediaObjectForMediaGroup:(MLMediaGroup *)mediaGroup
{
        NSArray *mediaObjects = [IMBAppleMediaLibraryPropertySynchronizer mediaObjectsForMediaGroup:mediaGroup];
        MLMediaObject *mediaObject = mediaObjects.lastObject;
    return mediaObject;
}

@end
