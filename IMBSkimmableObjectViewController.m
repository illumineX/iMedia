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


// Author: Jörg Jacobsen	(inspired by Pieter Omvlee (http://pieteromvlee.net/slides/IKImageBrowserView.pdf)
//							and Terrence Talbot (SVDesignChooserViewController))

//----------------------------------------------------------------------------------------------------------------------

#import "IMBImageBrowserView.h"
#import "IMBLibraryController.h"
#import "IMBObjectArrayController.h"
#import "IMBPanelController.h"
#import "IMBNodeViewController.h"
#import	"IMBSkimmableObjectViewController.h"
#import "IMBSkimmableObject.h"
#import "IMBNode.h"
#import "IMBConfig.h"

@interface IMBSkimmableObjectViewController ()

- (void) loadThumbnailForItem:(IMBSkimmableObject *)item;

@end

@implementation IMBSkimmableObjectViewController

//----------------------------------------------------------------------------------------------------------------------

//TODO: Do we really need default prefs for this controller?

+ (void) initialize
{
	NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
	NSMutableDictionary* classDict = [NSMutableDictionary dictionary];
	classDict[@"viewType"] = @(kIMBObjectViewTypeIcon);
	classDict[@"iconSize"] = @0.5;
	[IMBConfig registerDefaultPrefs:classDict forClass:self.class];
	[pool drain];
}


+ (NSString*) mediaType
{
	return kIMBMediaTypeImage;
}


+ (NSString*) nibName
{
	return @"IMBImageObjectViewController";	// Looks like we don't need an extra @"IMBSkimmableObjectViewController.xib"
}

+ (double) iconViewReloadDelay
{
	return 0.00;	// Delay in seconds. Default delay is decreased for proper skimming user exerience.
}


//----------------------------------------------------------------------------------------------------------------------


+ (NSString*) objectCountFormatSingular
{
	return NSLocalizedStringWithDefaultValue(
											 @"IMBSkimmableObjectViewController.countFormatSingular",
											 nil,IMBBundle(),
											 @"%d object",
											 @"Format string for object count in singluar");
}


+ (NSString*) objectCountFormatPlural
{
	return NSLocalizedStringWithDefaultValue(
											 @"IMBSkimmableObjectViewController.countFormatPlural",
											 nil,IMBBundle(),
											 @"%d objects",
											 @"Format string for object count in plural");
}

//----------------------------------------------------------------------------------------------------------------------

// Designated initializer

- (instancetype) initForNode:(IMBNode*)inNode
{
    NSString *nibName = [[self class] nibName];
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    
	if (self = [super initWithNibName:nibName bundle:bundle])
	{
		// Prepare for skimming
		_previousNodeObjectIndex = NSNotFound;
		
		// Found this advice in +[IMBObjectViewController viewControllerForLibaryController:]:
		//
		// Load the view *before* setting the LibraryController, 
		// so that outlets are set before we load the preferences.
		//
		// But we must set the library contoller before accessing the view, because the library controller's
		// delegate might be accessed when the view is loaded (e.g. to provide a custom image browser cell).
		//
		// (NodeViewController will be set later when this controller is used by a NodeViewController -
		// see -[IMBNodeViewController _customObjectViewControllerForNode])
		
		self.libraryController = [IMBLibraryController sharedLibraryControllerWithMediaType:inNode.mediaType];
	}
	
	return self;
}


- (void) awakeFromNib
{
	[super awakeFromNib];
	
	// Prepare for skimming
	[(IMBImageBrowserView*) self.iconView enableSkimming];
	
	ibObjectArrayController.searchableProperties = @[@"name"];
}


- (void) dealloc
{
	IMBRelease(_userInfo);
	
	[super dealloc];
}


#pragma mark Skimming

- (void) mouseEntered:(NSEvent*) inEvent
{
	//NSLog(@"Mouse entered View");
	_previousNodeObjectIndex = NSNotFound;
}

- (void) mouseExited:(NSEvent*) inEvent
{
	_previousNodeObjectIndex = NSNotFound;
	//NSLog(@"Mouse exited View");
}

// Start Skimming on the identified item
- (void) mouseEnteredItemAtIndex:(NSInteger) inIndex
{
	//NSLog(@"Mouse entered item at index %ld", (long) inIndex);
	_previousImageIndex = NSNotFound;
}

// Stop Skimming on the identified item. Restore key image in cell.
- (void) mouseExitedItemAtIndex:(NSInteger) inIndex
{
    NSArray *objects = ibObjectArrayController.arrangedObjects;
    if (inIndex < objects.count)
    {
        IMBSkimmableObject* item = objects[inIndex];
        
        [item resetCurrentSkimmingIndex];
        
        [self loadThumbnailForItem:item];
    }
	//NSLog(@"Mouse exited item at index %ld", (long) inIndex);
}

// Load the next thumbnail if mouse was moved sufficiently
- (void) mouseSkimmedOnItemAtIndex:(NSInteger)inIndex atPoint:(NSPoint)inPoint
{
    NSArray *objects = ibObjectArrayController.arrangedObjects;
    if (inIndex < objects.count)
    {
        IMBSkimmableObject* item = objects[inIndex];
        
        // Derive child object's index in node object from inPoint's relative position in frame
        
        NSRect skimmingFrame;
#if IMB_COMPILING_WITH_SNOW_LEOPARD_OR_NEWER_SDK
        if (IMBRunningOnSnowLeopardOrNewer())
        {
            skimmingFrame = [[self.iconView cellForItemAtIndex:inIndex] frame];	// >= 10.6
        }
        else
#endif
        {
            skimmingFrame = [self.iconView itemFrameAtIndex:inIndex];
        }
        
        CGFloat xOffset = inPoint.x - skimmingFrame.origin.x;
        NSUInteger objectCount = [item imageCount];
        
        if (objectCount > 0)
        {
            CGFloat widthPerObject = skimmingFrame.size.width / objectCount;
            NSUInteger objectIndex = (NSUInteger) xOffset / widthPerObject;
            
            //NSLog(@"Object index: %lu", objectIndex);
            
            if (objectIndex != _previousImageIndex)
            {
                _previousImageIndex = objectIndex;
                
                item.currentSkimmingIndex = objectIndex;
                
                [self loadThumbnailForItem:item];
            }
        }
    }
}

- (void) mouseMoved:(NSEvent *)anEvent
{
	IKImageBrowserView* iconView = self.iconView;
	
	//NSLog( @"Mouse was moved in image browser");
	NSPoint mouse = [iconView convertPoint:anEvent.locationInWindow fromView:nil];
	
	if (!NSPointInRect(mouse, iconView.bounds))
		return;
	
	NSUInteger hoverIndex;
#if IMB_COMPILING_WITH_SNOW_LEOPARD_OR_NEWER_SDK
	if (IMBRunningOnSnowLeopardOrNewer())
	{
		hoverIndex = [(IMBImageBrowserView*) iconView indexOfCellAtPoint:mouse];	// >= 10.6
	}
	else
#endif
	{
		hoverIndex = [iconView indexOfItemAtPoint:mouse];
	}

	//NSLog(@"Current index: %ld, previous index: %ld", (long) hoverIndex, (long) _previousNodeObjectIndex);
	
	if (hoverIndex != _previousNodeObjectIndex)
	{
		if (_previousNodeObjectIndex != NSNotFound)
			[self mouseExitedItemAtIndex:_previousNodeObjectIndex];
		if (hoverIndex != NSNotFound)
			[self mouseEnteredItemAtIndex:hoverIndex];
	}
	else if (hoverIndex != NSNotFound)
	{
		[self mouseSkimmedOnItemAtIndex:hoverIndex atPoint:mouse];
	}
	_previousNodeObjectIndex = hoverIndex;
	
	[super mouseMoved:anEvent];
}

#pragma mark Helper

- (void) loadThumbnailForItem:(IMBSkimmableObject *)item
{
    // Will not load thumbnail if these two flags are not set accordingly
    
    [item setNeedsImageRepresentation:YES];
    [item setIsLoadingThumbnail:NO]; // Avoid race condition

    [item fastLoadThumbnail]; // Background thread or XPC service
    
    [item setNeedsImageRepresentation:NO];
}

@end
