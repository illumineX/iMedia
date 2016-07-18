//
//  IMBNavigationController.m
//  iMedia
//
//  Created by Jörg Jacobsen on 29.04.15.
//
//

#import "IMBNavigationController.h"

@interface IMBNavigationController ()

@property (nonatomic, strong) NSMutableArray *navigationStack;
@property (nonatomic) NSInteger currentIndex;
@property (nonatomic) id<IMBNavigationLocation> currentLocation;

@end

@implementation IMBNavigationController

#pragma mark - Accessors

@synthesize navigationStack = _navigationStack;
@synthesize currentIndex = _currentIndex;
@synthesize locationProvider = _locationProvider;
@synthesize delegate = _delegate;
@synthesize goingBackOrForward = _goingBackOrForward;

- (id<IMBNavigationLocation>)currentLocation
{
    return [self validIndex:self.currentIndex] ? self.navigationStack[self.currentIndex] : nil;
}

- (void)setCurrentLocation:(id<IMBNavigationLocation>)currentLocation
{
    if ([self validIndex:self.currentIndex]) {
        self.navigationStack[self.currentIndex] = currentLocation;
    }
}

#pragma mark - Object Lifecycle

- (instancetype)init
{
    return [self initWithLocationProvider:nil];
}

/**
 Designated Initializer.
 */
- (instancetype)initWithLocationProvider:(id<IMBNavigable>)locationProvider
{
    self = [super init];
    if (self) {
        self.locationProvider = locationProvider;
        self.navigationStack = [NSMutableArray array];
        [self reset];
    }
    return self;
}

- (void)awakeFromNib
{
    NSAssert(self.locationProvider != nil, @"%@: location provider must not be nil", self);
}

#pragma mark - Validation

- (void)validateLocations
{
    NSUInteger locationIndex = 0;
    while (locationIndex < (self.navigationStack).count) {
        if (![self.locationProvider isValidLocation:self.navigationStack[locationIndex]]) {
            [self.navigationStack removeObjectAtIndex:locationIndex];
            self.currentIndex = self.currentIndex - 1;
        } else {
            locationIndex++;
        }
    }
    if ([self.delegate respondsToSelector:@selector(didChangeNavigationController:)]) {
        [self.delegate didChangeNavigationController:self];
    };
    DebugLog(@"%@", self);
}

#pragma mark - Navigation

/**
 Re-fetch current location from location provider and set on receiver.
 @discussion Calling this method ensures that current location of receiver and location provider are in sync.
 */
- (void)synchronizeCurrentLocation
{
    self.currentLocation = [self.locationProvider currentLocation];
}

/**
 Replaces the current location with the location provided.
 @discussion This can be useful if the state of the location changed since it was put onto the navigation stack. If the navigation stack is empty pushes location onto stack instead.
 */
- (void)updateCurrentLocationWithLocation:(id<IMBNavigationLocation>)location
{
    if (self.currentIndex >= 0) {
        self.currentLocation = location;
    } else {
        [self pushLocation:location];
    }
}

- (void)pushLocation:(id<IMBNavigationLocation>)location
{
    // If current index is not top of stack we must pop locations above
    // But never pop any location when going backward or forward
    
    if (!self.goingBackOrForward) {
        [self.navigationStack removeObjectsInRange:[self rangeToTopOfNavigation]];
    }
    
    [self.navigationStack addObject:location];
    self.currentIndex = (self.navigationStack).count - 1;   // Always point to last object after push

    if (self.currentIndex >= 0 && [self.delegate respondsToSelector:@selector(didGoForwardToLatestLocation)]) {
        [self.delegate didGoForwardToLatestLocation];
    };
    if ([self.delegate respondsToSelector:@selector(didChangeNavigationController:)]) {
        [self.delegate didChangeNavigationController:self];
    };
    DebugLog(@"%@", self);
}

- (void)goBackward
{
    [self _goStepsBackward:1];

    if (self.currentIndex == 0 && [self.delegate respondsToSelector:@selector(didGoBackToOldestLocation)]) {
        [self.delegate didGoBackToOldestLocation];
    } else if ( [self.delegate respondsToSelector:@selector(didGotoIntermediateLocation)]) {
        [self.delegate didGotoIntermediateLocation];
    }
    if ([self.delegate respondsToSelector:@selector(didChangeNavigationController:)]) {
        [self.delegate didChangeNavigationController:self];
    };
    DebugLog(@"%@", self);
}

- (void)_goStepsBackward:(NSUInteger)numberOfSteps
{
    self.goingBackOrForward = YES;
    
    [self synchronizeCurrentLocation];
    
    NSInteger proposedIndex = self.currentIndex - numberOfSteps;
    if ([self validIndex:proposedIndex]) {
        id location = self.navigationStack[proposedIndex];
        
        if (location && [self.locationProvider gotoLocation:location]) {
            self.currentIndex = proposedIndex;
        } else {
            [self.navigationStack removeObjectAtIndex:proposedIndex];
            self.currentIndex = self.currentIndex - 1;
            [self _goStepsBackward:numberOfSteps];
        }
    }
    self.goingBackOrForward = NO;
}

- (void)goForward
{
    [self _goStepsForward:1];
    
    if ([self atTopOfNavigation] && [self.delegate respondsToSelector:@selector(didGoForwardToLatestLocation)]) {
        [self.delegate didGoForwardToLatestLocation];
    } else if ( [self.delegate respondsToSelector:@selector(didGotoIntermediateLocation)]) {
        [self.delegate didGotoIntermediateLocation];
    }
    if ([self.delegate respondsToSelector:@selector(didChangeNavigationController:)]) {
        [self.delegate didChangeNavigationController:self];
    };
    DebugLog(@"%@", self);
}

- (void)_goStepsForward:(NSUInteger)numberOfSteps
{
    self.goingBackOrForward = YES;
    
    [self synchronizeCurrentLocation];
    
    NSInteger proposedIndex = self.currentIndex + numberOfSteps;
    if ([self validIndex:proposedIndex]) {
        id location = self.navigationStack[proposedIndex];
        
        if (location && [self.locationProvider gotoLocation:location]) {
            self.currentIndex = proposedIndex;
        } else {
            [self.navigationStack removeObjectAtIndex:proposedIndex];
            [self _goStepsForward:numberOfSteps];
        }
    }
    self.goingBackOrForward = NO;
}

#pragma mark - Query State

- (BOOL)canGoBackward
{
    return self.currentIndex > 0;
}

- (BOOL)canGoForward
{
    return self.currentIndex < ((self.navigationStack).count - 1);
}

#pragma mark - Buttons

/**
 Sets appropriate target and action on back button and makes it known to delegate.
 */
- (void)setupBackButton:(NSControl *)button
{
    button.target = self;
    button.action = @selector(goBackward:);
    
    if ([self.delegate respondsToSelector:@selector(didSetupBackButton:)]) {
        [self.delegate didSetupBackButton:button];
    }
}

/**
 Sets appropriate target and action on forward button and makes it known to delegate.
 */
- (void)setupForwardButton:(NSControl *)button
{
    button.target = self;
    button.action = @selector(goForward:);
    
    if ([self.delegate respondsToSelector:@selector(didSetupForwardButton:)]) {
        [self.delegate didSetupForwardButton:button];
    }
}

#pragma mark - Actions

- (IBAction)goBackward:(id)sender
{
    [self goBackward];
}

- (IBAction)goForward:(id)sender
{
    [self goForward];
}

#pragma mark - Helper

- (BOOL)validIndex:(NSInteger)index
{
    return index < (self.navigationStack).count && index >= 0;
}

- (NSRange)rangeToTopOfNavigation
{
    NSInteger loc = self.currentIndex+1;
    
    if (loc > 0) {
        NSInteger len = (self.navigationStack).count - loc;
        return NSMakeRange(loc, len);
    }
    return NSMakeRange(0, 0);
}

- (BOOL)atTopOfNavigation
{
    return (self.currentIndex == (self.navigationStack).count - 1);
}

- (void)reset
{
    [self.navigationStack removeAllObjects];
    self.currentIndex = -1;
    self.goingBackOrForward = NO;
}

#pragma mark - Description

- (NSString *)description
{
    NSString *description = @"\n";
    
    for (NSInteger index = self.currentIndex; index < (self.navigationStack).count; index++) {
        NSString *rowPrefix = nil;
        if (index == self.currentIndex) {
            rowPrefix = @"-->";
        } else {
            rowPrefix = @"   ";
        }
        description = [NSString stringWithFormat:@"%@%@ %@\n", description, rowPrefix, [self.navigationStack[index] description]];
    }
    return description;
}
@end
