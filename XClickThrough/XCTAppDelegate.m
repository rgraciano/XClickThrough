

#import "XCTAppDelegate.h"

@implementation XCTAppDelegate

@synthesize window = _window;

CGEventTapLocation LOCATION = kCGHIDEventTap;
CGEventType BTN_EVENT = kCGEventLeftMouseDown;

const int SLEEP_LIMIT = 500000; // 0.5s
const int SLEEP_INCREMENT = 10000; // 0.01s

+ (void)checkAssistiveAccess {
    NSString *title = @"Assistive Device Access Required";
    NSString *message = @"XClickThrough needs \"Enable access for assistive devices\" to be enabled in the Universal Access preferences panel.";
    
    while (!AXAPIEnabled()) {
        NSInteger choice = NSRunAlertPanel(title,
                                           message,
                                           @"Open Preferences",
                                           @"Exit XClickThrough",
                                           @"Try Again",
                                           NULL
                                           );
        
        switch (choice) {
            case NSAlertDefaultReturn:
                [[NSWorkspace sharedWorkspace] openFile:@"/System/Library/PreferencePanes/UniversalAccessPref.prefPane"];
                break;
                
            case NSAlertAlternateReturn:
                [NSApp terminate:self];
                
            default:
                continue;
        }        
    }
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    [XCTAppDelegate checkAssistiveAccess];
    
    CFMachPortRef allTap = CGEventTapCreate(LOCATION,
                                            kCGHeadInsertEventTap,
                                            kCGEventTapOptionDefault,
                                            CGEventMaskBit(BTN_EVENT),
                                            mouseTapCallback,
                                            NULL);
    
    CFRunLoopSourceRef runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, allTap, 0);
    
    CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, kCFRunLoopCommonModes);
    CFRelease(runLoopSource);
    
    CGEventTapEnable(allTap, true);
    CFRelease(allTap);
}

CGEventRef mouseTapCallback(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void* ref) {
    
    CGPoint pt = CGEventGetLocation(event);  // Point at which this click happened

    AXUIElementRef sysWideRef = AXUIElementCreateSystemWide(); // Global AX context, used to hit test
    if (sysWideRef == NULL) {
        return event;
    }
    CFBridgingRelease(sysWideRef);
    
    AXUIElementRef hitPoint = NULL; // Reference to the AX element that was hit
    
    // Get the AX element at the hitPoint position
    if (AXUIElementCopyElementAtPosition(sysWideRef, pt.x, pt.y, &hitPoint)) {
        if (hitPoint != NULL) {
            CFRelease(hitPoint);
        }
        
        return event;
    }
    
    // Find the application that the hitPoint belongs to
    CFRetain(hitPoint);
    AXUIElementRef app = findApplicationFromElement(hitPoint);
    CFRelease(hitPoint);

    // If we can't find the app element, then this is something we shouldn't capture
    if (app == NULL) {
        return event;
    }
    CFBridgingRelease(app);
    
    CFTypeRef boolVal = NULL;
    bool setFrontMost = NO;
    int slept = 0;
    
    for (int slept = 0; slept < SLEEP_LIMIT; slept += SLEEP_INCREMENT) { // Cap the amount of time we wait for the app to go foreground
        // Some things can't be front most, like icons on the dock
        if (AXUIElementCopyAttributeValue(app, CFSTR("AXFrontmost"), &boolVal)) {
            break;
        }

        // If the desired app is already front most, pass this click on as normal
        if (CFBooleanGetValue(boolVal)) {
            break;
        }
    
        if (!setFrontMost) {
            if (AXUIElementSetAttributeValue(app, CFSTR("AXFrontmost"), kCFBooleanTrue)) {
                break;
            }
            setFrontMost = YES;
        }
        
        if (boolVal != NULL) {
            CFRelease(boolVal);
            boolVal = NULL;
        }
        
        usleep(SLEEP_INCREMENT);
    }
    
    if (boolVal != NULL) {
        CFRelease(boolVal);
    }
    
    // If we errored out or timed out, just return the original event (basically do nothing)
    if (!setFrontMost || slept >= SLEEP_LIMIT) {
        return event;
    }
    else {
        // Otherwise, swallow the original event and make a click.
        //
        // At first I tried setting front most and returning the original click, but OS X seems
        // to mark it somehow. If you return the original click, OS X will remember that it was
        // originally done on an application that was not front most, and it will effectively do nothing.
        //
        // Experimentally, it looks like that process happens between the kCGSessionEventTap and
        // kCGAnnotatedSessionEventTap points.
        CGEventRef evt = CGEventCreateMouseEvent(NULL, BTN_EVENT, pt, kCGMouseButtonLeft);
        CGEventPost(LOCATION, evt);
        CFRelease(evt);
        
        evt = CGEventCreateMouseEvent(NULL, kCGEventLeftMouseUp, pt, kCGMouseButtonLeft);
        CGEventPost(LOCATION, evt);
        CFRelease(evt);
        
        return NULL;
    }
}

AXUIElementRef findApplicationFromElement(AXUIElementRef elementRef) {
    
    AXUIElementRef loopCurrent = elementRef;
    AXUIElementRef parent = NULL;
    
    CFStringRef role = NULL;
    
    for (int safetyValve = 0; safetyValve < 100; safetyValve++) {
        // If there are 100 AXParent elements and no AXApplication has been found, something is likely wrong.
        // Since something wrong in this loop could take down the input system on OS X, we have this safety valve.
        // In 10.8, an infinite loop here still let me CTRL-CMD-ESC to force quit. In 10.7 I couldn't get any key sequence
        // to break through.

        
        if (!AXUIElementCopyAttributeValue(loopCurrent, CFSTR("AXRole"), (CFTypeRef *)&role)) {
            // Found the AXApplication element, which is what we will raise later
            if (!CFStringCompare(role, CFSTR("AXApplication"), 0)) {
                CFRelease(role);
                return loopCurrent;
            }
        }
    
        CFRelease(role);
        
        if (AXUIElementCopyAttributeValue(loopCurrent, CFSTR("AXParent"), (CFTypeRef *)&parent)) {
            CFRelease(loopCurrent);
            return NULL;
        }
        
        CFRelease(loopCurrent);
        loopCurrent = parent;
    }
    
    CFRelease(loopCurrent);
    return NULL;
}


@end


