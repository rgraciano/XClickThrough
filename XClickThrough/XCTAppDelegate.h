//
//  XCTAppDelegate.h
//  XClickThrough
//
//  Created by Ryan Graciano on 9/22/13.
//  Copyright (c) 2013 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface XCTAppDelegate : NSObject <NSApplicationDelegate>

@property (assign) IBOutlet NSWindow *window;

CGEventRef mouseTapCallback(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void* ref);

@end
