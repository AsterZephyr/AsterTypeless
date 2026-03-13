#import <AppKit/AppKit.h>
#import <ApplicationServices/ApplicationServices.h>
#import <CoreGraphics/CoreGraphics.h>

static NSDictionary<NSString *, NSString *> *FrontmostAppInfo(void) {
    NSRunningApplication *app = NSWorkspace.sharedWorkspace.frontmostApplication;
    return @{
        @"name": app.localizedName ?: @"",
        @"bundleId": app.bundleIdentifier ?: @"",
    };
}

static BOOL IsAccessibilityTrusted(BOOL prompt) {
    NSDictionary *options = @{
        (__bridge NSString *)kAXTrustedCheckOptionPrompt: @(prompt),
    };
    return AXIsProcessTrustedWithOptions((__bridge CFDictionaryRef)options);
}

static void EmitJSON(NSDictionary *payload) {
    NSData *data = [NSJSONSerialization dataWithJSONObject:payload options:0 error:nil];
    if (data.length == 0) {
        return;
    }

    fwrite(data.bytes, 1, data.length, stdout);
}

static id CopyAttributeValue(AXUIElementRef element, CFStringRef attribute) {
    CFTypeRef value = NULL;
    AXError error = AXUIElementCopyAttributeValue(element, attribute, &value);
    if (error != kAXErrorSuccess || value == NULL) {
        return nil;
    }

    return CFBridgingRelease(value);
}

static NSString *StringAttribute(AXUIElementRef element, CFStringRef attribute) {
    id value = CopyAttributeValue(element, attribute);
    if ([value isKindOfClass:NSString.class]) {
        return value;
    }

    return @"";
}

static BOOL IsAttributeSettable(AXUIElementRef element, CFStringRef attribute) {
    Boolean settable = false;
    AXError error = AXUIElementIsAttributeSettable(element, attribute, &settable);
    return error == kAXErrorSuccess && settable;
}

static BOOL RangeAttribute(AXUIElementRef element, CFStringRef attribute, CFRange *range) {
    id value = CopyAttributeValue(element, attribute);
    if (value == nil || CFGetTypeID((__bridge CFTypeRef)value) != AXValueGetTypeID()) {
        return NO;
    }

    AXValueRef axValue = (__bridge AXValueRef)value;
    if (AXValueGetType(axValue) != kAXValueCFRangeType) {
        return NO;
    }

    return AXValueGetValue(axValue, kAXValueCFRangeType, range);
}

static AXValueRef CreateAXRangeValue(CFRange range) {
    CFRange mutableRange = range;
    return AXValueCreate(kAXValueCFRangeType, &mutableRange);
}

static AXUIElementRef FocusedElement(void) {
    AXUIElementRef systemWide = AXUIElementCreateSystemWide();
    CFTypeRef value = NULL;
    AXError error = AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute, &value);
    CFRelease(systemWide);

    if (error != kAXErrorSuccess || value == NULL) {
        return NULL;
    }

    if (CFGetTypeID(value) != AXUIElementGetTypeID()) {
        CFRelease(value);
        return NULL;
    }

    return (AXUIElementRef)value;
}

static NSDictionary<NSString *, NSString *> *ActivatePreferredApp(NSString *bundleId) {
    if (bundleId.length > 0) {
        NSArray<NSRunningApplication *> *apps =
            [NSRunningApplication runningApplicationsWithBundleIdentifier:bundleId];
        NSRunningApplication *targetApp = apps.firstObject;
        [targetApp activateWithOptions:0];
        usleep(220000);
    }

    return FrontmostAppInfo();
}

static BOOL ValidateRange(NSRange *outRange, CFRange range, NSUInteger length) {
    if (range.location == kCFNotFound) {
        return NO;
    }

    if (range.location < 0 || range.length < 0) {
        return NO;
    }

    NSUInteger start = (NSUInteger)range.location;
    NSUInteger span = (NSUInteger)range.length;
    if (start > length || start + span > length) {
        return NO;
    }

    if (outRange != NULL) {
        *outRange = NSMakeRange(start, span);
    }

    return YES;
}

static NSString *DerivedSelectedText(NSString *value, BOOL hasRange, CFRange range) {
    if (!hasRange || value.length == 0) {
        return @"";
    }

    NSRange selectionRange = NSMakeRange(0, 0);
    if (!ValidateRange(&selectionRange, range, value.length) || selectionRange.length == 0) {
        return @"";
    }

    return [value substringWithRange:selectionRange];
}

static NSString *SurroundingText(NSString *value, BOOL hasRange, CFRange range) {
    if (value.length == 0) {
        return @"";
    }

    NSUInteger radius = 180;
    if (hasRange) {
        NSRange selectionRange = NSMakeRange(0, 0);
        if (ValidateRange(&selectionRange, range, value.length)) {
            NSUInteger start = selectionRange.location > radius
                ? selectionRange.location - radius
                : 0;
            NSUInteger end = MIN(value.length, selectionRange.location + selectionRange.length + radius);
            return [value substringWithRange:NSMakeRange(start, end - start)];
        }
    }

    NSUInteger end = MIN(value.length, radius * 2);
    return [value substringToIndex:end];
}

static NSDictionary *BuildStatus(NSString *helperPath, BOOL prompt) {
    NSDictionary *appInfo = FrontmostAppInfo();
    return @{
        @"helperAvailable": @YES,
        @"helperPath": helperPath ?: @"",
        @"accessibilityTrusted": @(IsAccessibilityTrusted(prompt)),
        @"accessibilityPermissionPrompted": @(prompt),
        @"focusedAppName": appInfo[@"name"] ?: @"",
        @"focusedBundleId": appInfo[@"bundleId"] ?: @"",
        @"lastError": @"",
    };
}

static NSDictionary *BuildSelectionSnapshot(void) {
    NSDictionary *appInfo = FrontmostAppInfo();
    if (!IsAccessibilityTrusted(NO)) {
        return @{
            @"available": @NO,
            @"selectedText": @"",
            @"surroundingText": @"",
            @"focusedAppName": appInfo[@"name"] ?: @"",
            @"focusedBundleId": appInfo[@"bundleId"] ?: @"",
            @"source": @"unavailable",
            @"lastError": @"Accessibility permission is required to read the focused selection.",
        };
    }

    AXUIElementRef element = FocusedElement();
    if (element == NULL) {
        return @{
            @"available": @NO,
            @"selectedText": @"",
            @"surroundingText": @"",
            @"focusedAppName": appInfo[@"name"] ?: @"",
            @"focusedBundleId": appInfo[@"bundleId"] ?: @"",
            @"source": @"unavailable",
            @"lastError": @"Unable to resolve the focused accessibility element.",
        };
    }

    NSString *explicitSelectedText = StringAttribute(element, kAXSelectedTextAttribute);
    NSString *valueText = StringAttribute(element, kAXValueAttribute);
    CFRange selectedRange = CFRangeMake(0, 0);
    BOOL hasSelectedRange = RangeAttribute(element, kAXSelectedTextRangeAttribute, &selectedRange);
    NSString *derivedText = explicitSelectedText.length == 0
        ? DerivedSelectedText(valueText, hasSelectedRange, selectedRange)
        : explicitSelectedText;
    NSString *contextText = SurroundingText(valueText, hasSelectedRange, selectedRange);
    BOOL hasReadableContent = derivedText.length > 0 || contextText.length > 0;

    CFRelease(element);

    return @{
        @"available": @(hasReadableContent),
        @"selectedText": derivedText ?: @"",
        @"surroundingText": contextText ?: @"",
        @"focusedAppName": appInfo[@"name"] ?: @"",
        @"focusedBundleId": appInfo[@"bundleId"] ?: @"",
        @"source": explicitSelectedText.length == 0 ? @"derived-value" : @"accessibility",
        @"lastError": hasReadableContent ? @"" : @"No readable text selection was found in the focused element.",
    };
}

static NSDictionary *InsertTextViaValueAttribute(
    AXUIElementRef element,
    NSString *text,
    NSDictionary *appInfo
) {
    if (!IsAttributeSettable(element, kAXValueAttribute)) {
        return nil;
    }

    NSString *currentValue = StringAttribute(element, kAXValueAttribute);
    CFRange selectedRange = CFRangeMake((CFIndex)currentValue.length, 0);
    BOOL hasSelectedRange = RangeAttribute(element, kAXSelectedTextRangeAttribute, &selectedRange);
    NSRange replacementRange = NSMakeRange(currentValue.length, 0);
    if (hasSelectedRange) {
        ValidateRange(&replacementRange, selectedRange, currentValue.length);
    }

    NSString *nextValue = [currentValue stringByReplacingCharactersInRange:replacementRange withString:text];
    AXError setValueError = AXUIElementSetAttributeValue(
        element,
        kAXValueAttribute,
        (__bridge CFTypeRef)nextValue
    );
    if (setValueError != kAXErrorSuccess) {
        return nil;
    }

    if (IsAttributeSettable(element, kAXSelectedTextRangeAttribute)) {
        CFRange nextCursor = CFRangeMake((CFIndex)(replacementRange.location + text.length), 0);
        AXValueRef rangeValue = CreateAXRangeValue(nextCursor);
        if (rangeValue != NULL) {
            AXUIElementSetAttributeValue(element, kAXSelectedTextRangeAttribute, rangeValue);
            CFRelease(rangeValue);
        }
    }

    return @{
        @"ok": @YES,
        @"method": replacementRange.length > 0 ? @"replace-selection" : @"append-value",
        @"focusedAppName": appInfo[@"name"] ?: @"",
        @"focusedBundleId": appInfo[@"bundleId"] ?: @"",
        @"lastError": @"",
    };
}

static BOOL PostPasteShortcut(void) {
    CGEventSourceRef source = CGEventSourceCreate(kCGEventSourceStateCombinedSessionState);
    if (source == NULL) {
        return NO;
    }

    CGKeyCode keyCode = 9;
    CGEventRef keyDown = CGEventCreateKeyboardEvent(source, keyCode, true);
    CGEventRef keyUp = CGEventCreateKeyboardEvent(source, keyCode, false);
    CFRelease(source);
    if (keyDown == NULL || keyUp == NULL) {
        if (keyDown != NULL) {
            CFRelease(keyDown);
        }
        if (keyUp != NULL) {
            CFRelease(keyUp);
        }
        return NO;
    }

    CGEventSetFlags(keyDown, kCGEventFlagMaskCommand);
    CGEventSetFlags(keyUp, kCGEventFlagMaskCommand);
    CGEventPost(kCGHIDEventTap, keyDown);
    CGEventPost(kCGHIDEventTap, keyUp);
    CFRelease(keyDown);
    CFRelease(keyUp);
    return YES;
}

static NSDictionary *InsertTextViaPasteboard(NSString *text, NSDictionary *appInfo) {
    NSPasteboard *pasteboard = NSPasteboard.generalPasteboard;
    NSString *existingString = [pasteboard stringForType:NSPasteboardTypeString];

    [pasteboard clearContents];
    [pasteboard setString:text forType:NSPasteboardTypeString];

    BOOL pasted = PostPasteShortcut();
    usleep(180000);

    [pasteboard clearContents];
    if (existingString.length > 0) {
        [pasteboard setString:existingString forType:NSPasteboardTypeString];
    }

    return @{
        @"ok": @(pasted),
        @"method": pasted ? @"pasteboard" : @"unavailable",
        @"focusedAppName": appInfo[@"name"] ?: @"",
        @"focusedBundleId": appInfo[@"bundleId"] ?: @"",
        @"lastError": pasted ? @"" : @"Unable to trigger a paste shortcut for the focused app.",
    };
}

static NSDictionary *BuildInsertTextResult(NSString *encodedText, NSString *preferredBundleId) {
    NSDictionary *appInfo = ActivatePreferredApp(preferredBundleId ?: @"");
    if (!IsAccessibilityTrusted(NO)) {
        return @{
            @"ok": @NO,
            @"method": @"unavailable",
            @"focusedAppName": appInfo[@"name"] ?: @"",
            @"focusedBundleId": appInfo[@"bundleId"] ?: @"",
            @"lastError": @"Accessibility permission is required to insert text into the focused app.",
        };
    }

    NSData *data = [[NSData alloc] initWithBase64EncodedString:(encodedText ?: @"") options:0];
    NSString *text = data.length > 0 ? [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] : nil;
    if (text.length == 0) {
        return @{
            @"ok": @NO,
            @"method": @"unavailable",
            @"focusedAppName": appInfo[@"name"] ?: @"",
            @"focusedBundleId": appInfo[@"bundleId"] ?: @"",
            @"lastError": @"No insertion text was provided.",
        };
    }

    AXUIElementRef element = FocusedElement();
    if (element != NULL) {
        NSDictionary *directInsert = InsertTextViaValueAttribute(element, text, appInfo);
        CFRelease(element);
        if (directInsert != nil) {
            return directInsert;
        }
    }

    return InsertTextViaPasteboard(text, appInfo);
}

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        NSString *command = argc > 1 ? [NSString stringWithUTF8String:argv[1]] : @"status";
        NSString *helperPath = argc > 0 ? [NSString stringWithUTF8String:argv[0]] : @"";
        NSString *encodedText = argc > 2 ? [NSString stringWithUTF8String:argv[2]] : @"";
        NSString *preferredBundleId = argc > 3 ? [NSString stringWithUTF8String:argv[3]] : @"";

        if ([command isEqualToString:@"status"]) {
            EmitJSON(BuildStatus(helperPath, NO));
            return 0;
        }

        if ([command isEqualToString:@"prompt-accessibility"]) {
            EmitJSON(BuildStatus(helperPath, YES));
            return 0;
        }

        if ([command isEqualToString:@"read-selection"]) {
            EmitJSON(BuildSelectionSnapshot());
            return 0;
        }

        if ([command isEqualToString:@"insert-text"]) {
            EmitJSON(BuildInsertTextResult(encodedText, preferredBundleId));
            return 0;
        }

        EmitJSON(@{
            @"helperAvailable": @NO,
            @"helperPath": @"",
            @"accessibilityTrusted": @NO,
            @"accessibilityPermissionPrompted": @NO,
            @"focusedAppName": @"",
            @"focusedBundleId": @"",
            @"lastError": @"Unknown native helper command.",
        });
        return 1;
    }
}
