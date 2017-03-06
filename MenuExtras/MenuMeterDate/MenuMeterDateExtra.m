//
//  MenuMeterMemExtra.m
//
//	Menu Extra implementation
//
//	Copyright (c) 2002-2014 Alex Harper
//
// 	This file is part of MenuMeters.
//
// 	MenuMeters is free software; you can redistribute it and/or modify
// 	it under the terms of the GNU General Public License version 2 as
//  published by the Free Software Foundation.
//
// 	MenuMeters is distributed in the hope that it will be useful,
// 	but WITHOUT ANY WARRANTY; without even the implied warranty of
// 	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// 	GNU General Public License for more details.
//
// 	You should have received a copy of the GNU General Public License
// 	along with MenuMeters; if not, write to the Free Software
// 	Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
//

#import "MenuMeterDateExtra.h"


///////////////////////////////////////////////////////////////
//
//	Private methods
//
///////////////////////////////////////////////////////////////

@interface MenuMeterDateExtra (PrivateMethods)

// Menu generation
- (void)updateMenuContent;

// Image renderers
- (void)renderPieIntoImage:(NSImage *)image forProcessor:(float)offset;
- (void)renderNumbersIntoImage:(NSImage *)image forProcessor:(float)offset;
- (void)renderBarIntoImage:(NSImage *)image forProcessor:(float)offset;
- (void)renderMemHistoryIntoImage:(NSImage *)image forProcessor:(float)offset;
- (void)renderPageIndicatorIntoImage:(NSImage *)image forProcessor:(float)offset;

// Timer callbacks
- (void)updateMemDisplay:(NSTimer *)timer;
- (void)updateMenuWhenDown;

- (void)openDateTimePrefs:(id)sender;

// Prefs
- (void)configFromPrefs:(NSNotification *)notification;

@end

///////////////////////////////////////////////////////////////
//
//	Localized strings
//
///////////////////////////////////////////////////////////////

///////////////////////////////////////////////////////////////
//
//	init/unload/dealloc
//
///////////////////////////////////////////////////////////////

@implementation MenuMeterDateExtra

- initWithBundle:(NSBundle *)bundle {

	self = [super initWithBundle:bundle];
	if (!self) {
		return nil;
	}

    isPantherOrLater = OSIsPantherOrLater();
    isLeopardOrLater = OSIsLeopardOrLater();

	// Load our pref bundle, we do this as a bundle because we are a plugin
	// to SystemUIServer and as a result cannot have the same class loaded
	// from every meter. Using a shared bundle each loads fixes this.
	NSString *prefBundlePath = [[[bundle bundlePath] stringByDeletingLastPathComponent]
									stringByAppendingPathComponent:kPrefBundleName];
	ourPrefs = [[[[NSBundle bundleWithPath:prefBundlePath] principalClass] alloc] init];
	if (!ourPrefs) {
		NSLog(@"MenuMeterMem unable to connect to preferences. Abort.");
		[self release];
		return nil;
	}
    
    dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"yyyy MMM d  HH:mm"];
    dayFormatter = [[NSDateFormatter alloc] init];
    [dayFormatter setDateFormat:@"yyyy/MM/dd"];

	// Setup our menu
	extraMenu = [[NSMenu alloc] initWithTitle:@""];
	if (!extraMenu) {
		[self release];
		return nil;
	}
	// Disable menu autoenabling
	[extraMenu setAutoenablesItems:NO];

	// Setup menu content
	NSMenuItem *menuItem = nil;

    NSDate *cur = [NSDate date];

    date = [[MenuMeterDateView alloc] initWithFrame: NSMakeRect(0, 0, 150, 150)];
    [date setAutoresizingMask: NSViewMinXMargin | NSViewMaxXMargin | NSViewMinYMargin | NSViewMaxYMargin];
    [date setDatePickerStyle: NSClockAndCalendarDatePickerStyle];
    [date setDatePickerElements: NSYearMonthDayDatePickerElementFlag];
    [date setDateValue:cur];
    dateLast = [cur copy];

	// Add memory usage menu items and placeholder
	menuItem = (NSMenuItem *)[extraMenu addItemWithTitle:@"" action:nil keyEquivalent:@""];
    [menuItem setView: date];
    [menuItem setEnabled:YES];
    
    [extraMenu addItem:[NSMenuItem separatorItem]];
    menuItem = (NSMenuItem *)[extraMenu addItemWithTitle:@"Open Date & Time Preferences..." action:@selector(openDateTimePrefs:) keyEquivalent:@""];
    [menuItem setTarget: self];
    [menuItem setEnabled:YES];
    
	// Register for pref changes
	[[NSDistributedNotificationCenter defaultCenter] addObserver:self
														selector:@selector(configFromPrefs:)
															name:kMemMenuBundleID
														  object:kPrefChangeNotification];
	// Register for 10.10 theme changes
	[[NSDistributedNotificationCenter defaultCenter] addObserver:self
														selector:@selector(configFromPrefs:)
															name:kAppleInterfaceThemeChangedNotification
														  object:nil];

	// And configure directly from prefs on first load
	[self configFromPrefs:nil];

	// Fake a timer call to config initial values
	[self updateMemDisplay:nil];

    // And hand ourself back to SystemUIServer
	NSLog(@"MenuMeterDate loaded.");
    return self;

} // initWithBundle

- (void)willUnload {

	// Stop the timer
	[updateTimer invalidate];  // Released by the runloop
	updateTimer = nil;

	// Unregister pref change notifications
	[[NSDistributedNotificationCenter defaultCenter] removeObserver:self
															   name:nil
															 object:nil];

	// Let the pref panel know we have been removed
	[[NSDistributedNotificationCenter defaultCenter] postNotificationName:kMemMenuBundleID
																   object:kMemMenuUnloadNotification];

	// Let super do the rest
    [super willUnload];

} // willUnload

- (void)dealloc {

    [extraMenu release];
	[updateTimer invalidate];  // Released by the runloop
	[ourPrefs release];
	[fgMenuThemeColor release];
	[super dealloc];

} // dealloc

///////////////////////////////////////////////////////////////
//
//	NSMenuExtra view callbacks
//
///////////////////////////////////////////////////////////////

- (NSMenu *)menu {

	// Since we want the menu and view to match data we update the data now
	// (menu is called before image for view)

	// Update the menu content
	[self updateMenuContent];

	// Send the menu back to SystemUIServer
	return extraMenu;

} // menu

///////////////////////////////////////////////////////////////
//
//	Menu generation
//
///////////////////////////////////////////////////////////////

// This code is split out (unlike all the other meters) to deal
// with the special case. The memory meter is set to update slowly
// so we have its menu method pull new data when rendering. This prevents
// the menu from having obviously stale data when the update interval is
// long. However, by doing it this way we would pull data twice per
// timer update with the menu down if the updateMenuWhenDown method
// called the menu method directly.

- (void)updateMenuContent {

} // updateMenuContent

///////////////////////////////////////////////////////////////
//
//	Timer callbacks
//
///////////////////////////////////////////////////////////////

- (void)updateMemDisplay:(NSTimer *)timer {

    NSDate *cur = [NSDate date];
    
    NSString *formattedDateString = [dateFormatter stringFromDate: cur];
    [extraMenu setTitle: formattedDateString];
    
    NSString *d1 = [dayFormatter stringFromDate:dateLast];
    NSString *d2 = [dayFormatter stringFromDate:cur];
    
    if (![d1 isEqual: d2]) {
        date.dateValue = cur;
        dateLast = [cur copy];
    }

    // If the menu is down, update it
	if ([self isMenuDown] || ([self respondsToSelector:@selector(isMenuDownForAX)] && [self isMenuDownForAX])) {
		[self updateMenuWhenDown];
    }

} // updateMemDisplay

- (void)updateMenuWhenDown {

	// Update the menu content
	[self updateMenuContent];

	// Force the menu to redraw
	LiveUpdateMenu(extraMenu);

} // updateMenuWhenDown

///////////////////////////////////////////////////////////////
//
//	Prefs
//
///////////////////////////////////////////////////////////////

- (void)configFromPrefs:(NSNotification *)notification {
#if MAC_OS_X_VERSION_MIN_REQUIRED >= MAC_OS_X_VERSION_10_11
    [super configDisplay:kDateMenuBundleID fromPrefs:ourPrefs withTimerInterval:[ourPrefs cpuInterval]];
#endif

	// Update prefs
	[ourPrefs syncWithDisk];

	// Handle menubar theme changes
	[fgMenuThemeColor release];
	fgMenuThemeColor = [MenuItemTextColor() retain];
	
	// Restart the timer
	[updateTimer invalidate];  // Runloop releases and retains the next one
	updateTimer = [NSTimer scheduledTimerWithTimeInterval:[ourPrefs cpuInterval]
												   target:self
												 selector:@selector(updateMemDisplay:)
												 userInfo:nil
												  repeats:YES];
	// On newer OS versions we need to put the timer into EventTracking to update while the menus are down
	if (isPantherOrLater) {
		[[NSRunLoop currentRunLoop] addTimer:updateTimer
									 forMode:NSEventTrackingRunLoopMode];
	}

} // configFromPrefs

- (void)openDateTimePrefs:(id)sender {
    
    if (![[NSWorkspace sharedWorkspace] openFile:@"/System/Library/PreferencePanes/DateAndTime.prefPane"]) {
        NSLog(@"MenuMeterDate unable to launch the Time Preferences.");
    }
    
} // openNetworkPrefs

@end
