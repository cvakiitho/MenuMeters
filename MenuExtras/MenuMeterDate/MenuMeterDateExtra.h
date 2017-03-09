//
//  MenuMeterMemExtra.h
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

#import <Cocoa/Cocoa.h>
#import <Carbon/Carbon.h>
#import "AppleUndocumented.h"
#import "MenuMeters.h"
#import "MenuMeterDefaults.h"
#import "MenuMeterWorkarounds.h"
#import "MenuMeterDateView.h"

@interface MenuMeterDateExtra : NSMenuExtra  {

    NSDateFormatter *dayFormatter;
    NSDateFormatter *dateFormatter;
    NSDateFormatter *detailFormatter;
    
    BOOL							isPantherOrLater,    isLeopardOrLater;
	// Menu Extra necessities
	NSMenu 							*extraMenu;
	// The timer
	NSTimer							*updateTimer;
	// Pref object
	MenuMeterDefaults				*ourPrefs;
	// Width of the text display
	float							textWidth;
	// Theme support
	NSColor							*fgMenuThemeColor;
    NSDatePicker                    *date;
    NSDate                          *dateLast;

} // MenuMeterMemExtra

@end
