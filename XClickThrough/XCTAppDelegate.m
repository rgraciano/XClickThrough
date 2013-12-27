

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
    
    AXUIElementRef hitPoint = NULL; // Reference to the AX element that was hit
    
    // Get the AX element at the hitPoint position
    if (AXUIElementCopyElementAtPosition(sysWideRef, pt.x, pt.y, &hitPoint)) {
        CFRelease(sysWideRef);
        
        if (hitPoint != NULL) {
            CFRelease(hitPoint);
        }
        
        return event;
    }
    CFRelease(sysWideRef);
    
    // Find the application that the hitPoint belongs to
    CFRetain(hitPoint);
    AXUIElementRef app = [XCTAppDelegate findParentElementByRole:CFSTR("AXApplication") fromElement:hitPoint];

    // If we can't find the app element, then this is something we shouldn't capture
    if (app == NULL) {
        CFRelease(hitPoint);
        return event;
    }
    
    // Now find the window that the hitPoint belongs to
    AXUIElementRef window;
    if (AXUIElementCopyAttributeValue(hitPoint, CFSTR("AXWindow"), (CFTypeRef *)&window) || window == NULL) {
        CFRelease(hitPoint);
        CFRelease(app);
        return event;
    }
    CFRelease(hitPoint);
    
    // Make the hitPoint's window frontMost
    BOOL changedAppFocus = [XCTAppDelegate checkAttributeUntilChanged:CFSTR("AXFrontmost")
                                                   changeAttrOrAction:CFSTR("AXFrontmost")
                                                           withAction:NO
                                                          fromElement:app];
    BOOL changedWindowFocus = NO;

    // Now check that the window we clicked is the 'main window', making sure
    // first that a 'main window' is possible in this application.
    CFStringRef axMainWindowVal = NULL;
    AXUIElementCopyAttributeValue(app, CFSTR("AXMainWindow"), (CFTypeRef *)&axMainWindowVal);
    
    // If the app has a 'main window', make sure the one we clicked is it
    if (axMainWindowVal != NULL) {
        changedWindowFocus = [XCTAppDelegate checkAttributeUntilChanged:CFSTR("AXMain")
                                                      changeAttrOrAction:CFSTR("AXRaise")
                                                              withAction:YES
                                                             fromElement:window];
    }

    CFRelease(app);
    CFRelease(window);

    // If we changed neither the app focus nor the window focus, then do nothing
    if (!changedAppFocus && !changedWindowFocus) {
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

+ (BOOL) checkAttributeUntilChanged:(CFStringRef)checkAttribute changeAttrOrAction:(CFStringRef)attrOrAction withAction:(BOOL)isAction fromElement:(AXUIElementRef)element {
     
    CFTypeRef boolVal = NULL;
    bool didSomething = NO;
    int slept;
    
    for (slept = 0; slept < SLEEP_LIMIT; slept += SLEEP_INCREMENT) { // Cap the amount of time we wait for the action to complete
        // Some things can't be front most, like icons on the dock
        if (AXUIElementCopyAttributeValue(element, checkAttribute, &boolVal)) {
            break;
        }

        // If the desired app is already front most, pass this click on as normal
        if (CFBooleanGetValue(boolVal)) {
            break;
        }

        if (!didSomething) {
            if (isAction) {
                if(AXUIElementPerformAction(element, attrOrAction)) {
                    break;
                }
            }
            else {
                if (AXUIElementSetAttributeValue(element, attrOrAction, kCFBooleanTrue)) {
                    break;
                }
            }
    
            didSomething = YES;
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
    
    if (slept >= SLEEP_LIMIT) {
        return NO;
    }
    else {
        return didSomething;
    }
}

+ (AXUIElementRef) findParentElementByRole:(CFStringRef)roleToFind fromElement:(AXUIElementRef)startElement {
        
    AXUIElementRef loopCurrent = startElement;
    AXUIElementRef parent = NULL;
    
    CFStringRef role = NULL;
    
    for (int safetyValve = 0; safetyValve < 100; safetyValve++) {
        // If there are 100 AXParent elements and no AXApplication has been found, something is likely wrong.
        // Since something wrong in this loop could take down the input system on OS X, we have this safety valve.
        // In 10.8, an infinite loop here still let me CTRL-CMD-ESC to force quit. In 10.7 I couldn't get any key sequence
        // to break through.
        
        
        if (!AXUIElementCopyAttributeValue(loopCurrent, CFSTR("AXRole"), (CFTypeRef *)&role)) {
            // Found the AXApplication element, which is what we will raise later
            if (!CFStringCompare(role, roleToFind, 0)) {
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


