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


//----------------------------------------------------------------------------------------------------------------------


// Author: Jörg Jacobsen


//----------------------------------------------------------------------------------------------------------------------


#pragma mark HEADERS


#import <iMedia/iMedia.h>
#import "IMBTestTextView.h"
#import "IMBTestAppDelegate.h"
#import "NSPasteboard+iMedia.h"


//----------------------------------------------------------------------------------------------------------------------


@implementation IMBTestTextView

-(BOOL)performDragOperation:(id<NSDraggingInfo>)inSender
{
	NSPasteboard* pasteboard = [inSender draggingPasteboard];
	NSArray* objects = [pasteboard imb_IMBObjects];
    
    __block BOOL isPerformDragHandled = NO;
    NSError *lastError = nil;
	
    for (IMBObject *object in objects)
    {
        NSError *error = nil;
        void (^insertResourceIntoTextView)(NSImage *) = ^void(NSImage *resource) {
            // Insert image into view
            
            NSTextAttachmentCell *attachmentCell = [[NSTextAttachmentCell alloc] initImageCell:resource];
            NSTextAttachment *attachment = [[NSTextAttachment alloc] init];
            [attachment setAttachmentCell: attachmentCell ];
            NSAttributedString *attributedString = [NSAttributedString  attributedStringWithAttachment: attachment];
            [[self textStorage] insertAttributedString:attributedString atIndex:self.selectedRange.location];
            
            [self setNeedsDisplay:YES];
            isPerformDragHandled = YES;
        };
        
        if (object.location && ![object.location isFileURL]) {
            // Coming here you will presumably load a resource from the internet (Facebook, Flickr and the like)
            
            // This only works if localtion URL denotes an NSImage-compatible location (hey, it's only a test app after all)
            insertResourceIntoTextView([[NSImage alloc] initWithContentsOfURL:object.location]);
        } else {
            // You won't have direct access to a file URL that does not point to the standard asset locations. Better unconditionally resolve corresponding bookmark!
            
            // Also note that object.location and object.locationBookmark point to different locations for an IMBLightroomObject:
            // - object.location: file URL denoting original master file
            // - object.locationBookmark: file URL denoting a temporary file generated on the fly to reflect the current user changes to the image
            //   (this file will also most likely have a lower resolution than the master file if the user made changes to the image)
            
            // As an alternative, you can use the asynchronous variant of -requestBookmarkWithError method if you anticipate the user dragging thousands of resources at once (requesting a bookmark does add some overhead) and if your completion block code is thread-safe:
            //            [object requestBookmarkWithQueue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH,0)
            //                             completionBlock:^(NSError *error) {
            //                                 // Your dragging code here
            //                             }];
            
            // Will have side-effect of setting bookmark on object if not already set
            if ([object requestBookmarkWithError:&error])
            {
                NSURL *URL = [object URLByResolvingBookmark];
                
                if (object.accessibility == kIMBResourceIsAccessibleSecurityScoped) [URL startAccessingSecurityScopedResource];
                
                // This only works if URL denotes an NSImage-compatible location (hey, it's only a test app after all)
                insertResourceIntoTextView([[NSImage alloc] initWithContentsOfURL:URL]);
                
                if (object.accessibility == kIMBResourceIsAccessibleSecurityScoped) [URL stopAccessingSecurityScopedResource];
                
            } else {
                lastError = error;
            }
        }
    }
    if (isPerformDragHandled)
    {
        if (lastError) [NSApp presentError:lastError];
        return YES;
    } else {
        return [super performDragOperation:inSender];
    }
}


- (void) concludeDragOperation:(id<NSDraggingInfo>)inSender
{
	NSPasteboard* pasteboard = [inSender draggingPasteboard];
	NSArray* objects = [pasteboard imb_IMBObjects];
	
	// Tell the app delegate that it can update its badge cache with these objects...
    [(IMBTestAppDelegate*) draggingDelegate concludeDragOperationForObjects:objects];
}


//----------------------------------------------------------------------------------------------------------------------


@end
