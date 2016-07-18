//
//  MLMediaGroup+iMedia.m
//  iMedia
//
//  Created by Jörg Jacobsen on 18.04.15.
//
//

#import "MLMediaGroup+iMedia.h"

@implementation MLMediaGroup (iMedia)

/**
 */
- (NSArray *)imb_childGroupsUptoMaxCount:(NSUInteger)maxCount
{
    NSArray *childGroups = self.childGroups;
    
    if (childGroups.count <= maxCount) {
        return childGroups;
    } else {
        return [childGroups subarrayWithRange:NSMakeRange(0, maxCount)];
    }
}

/**
 @return The number of mediaObjects of the receiver
 */
- (NSNumber *)imb_mediaObjectCount
{
    return self.attributes[@"PhotoCount"];
//    NSUInteger count = 0;
//    NSNumber *countNumber = self.attributes[@"PhotoCount"];
//    if (countNumber != nil) {
//        count = [countNumber unsignedIntegerValue];
//    }
//    return count;
}

@end
