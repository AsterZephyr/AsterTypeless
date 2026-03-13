import AppKit
import ApplicationServices
import CoreGraphics
import Foundation

struct NativeStatus: Codable {
    let helperAvailable: Bool
    let helperPath: String
    let accessibilityTrusted: Bool
    let accessibilityPermissionPrompted: Bool
    let focusedAppName: String
    let focusedBundleId: String
    let lastError: String
}

struct SelectionSnapshot: Codable {
    let available: Bool
    let selectedText: String
    let surroundingText: String
    let focusedAppName: String
    let focusedBundleId: String
    let source: String
    let lastError: String
}

struct InsertTextResult: Codable {
    let ok: Bool
    let method: String
    let focusedAppName: String
    let focusedBundleId: String
    let lastError: String
}

enum HelperCommand: String {
    case status
    case promptAccessibility = "prompt-accessibility"
    case readSelection = "read-selection"
    case insertText = "insert-text"
}

func frontmostAppInfo() -> (name: String, bundleId: String) {
    guard let app = NSWorkspace.shared.frontmostApplication else {
        return ("", "")
    }

    return (app.localizedName ?? "", app.bundleIdentifier ?? "")
}

func isAccessibilityTrusted(prompt: Bool) -> Bool {
    let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: prompt] as CFDictionary
    return AXIsProcessTrustedWithOptions(options)
}

func emit<T: Codable>(_ value: T) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.withoutEscapingSlashes]
    let data = try encoder.encode(value)

    guard let text = String(data: data, encoding: .utf8) else {
        throw NSError(
            domain: "TypelessNativeHelper",
            code: 2,
            userInfo: [NSLocalizedDescriptionKey: "Failed to encode JSON output"]
        )
    }

    FileHandle.standardOutput.write(Data(text.utf8))
}

func copyAttributeValue(element: AXUIElement, attribute: String) -> CFTypeRef? {
    var value: CFTypeRef?
    let error = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)

    guard error == .success else {
        return nil
    }

    return value
}

func stringAttribute(element: AXUIElement, attribute: String) -> String? {
    copyAttributeValue(element: element, attribute: attribute) as? String
}

func isAttributeSettable(element: AXUIElement, attribute: String) -> Bool {
    var settable: DarwinBoolean = false
    let error = AXUIElementIsAttributeSettable(element, attribute as CFString, &settable)
    return error == .success && settable.boolValue
}

func rangeAttribute(element: AXUIElement, attribute: String) -> CFRange? {
    guard let value = copyAttributeValue(element: element, attribute: attribute) else {
        return nil
    }

    guard CFGetTypeID(value) == AXValueGetTypeID() else {
        return nil
    }

    let axValue = unsafeBitCast(value, to: AXValue.self)

    guard AXValueGetType(axValue) == .cfRange else {
        return nil
    }

    var range = CFRange(location: 0, length: 0)
    guard AXValueGetValue(axValue, .cfRange, &range) else {
        return nil
    }

    return range
}

func axRangeValue(_ range: CFRange) -> AXValue? {
    var mutableRange = range
    return AXValueCreate(.cfRange, &mutableRange)
}

func focusedElement() -> AXUIElement? {
    let systemWide = AXUIElementCreateSystemWide()
    guard let value = copyAttributeValue(
        element: systemWide,
        attribute: kAXFocusedUIElementAttribute as String
    ) else {
        return nil
    }

    guard CFGetTypeID(value) == AXUIElementGetTypeID() else {
        return nil
    }

    return unsafeBitCast(value, to: AXUIElement.self)
}

func activatePreferredApp(bundleId: String) -> (name: String, bundleId: String) {
    if bundleId.isEmpty {
        return frontmostAppInfo()
    }

    let runningApp = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId).first
    _ = runningApp?.activate(options: [])
    usleep(220_000)
    return frontmostAppInfo()
}

func validatedRange(_ range: CFRange?, in value: NSString) -> NSRange? {
    guard let range else {
        return nil
    }

    guard range.location != kCFNotFound else {
        return nil
    }

    guard range.location >= 0, range.length >= 0 else {
        return nil
    }

    let upperBound = range.location + range.length
    guard upperBound <= value.length else {
        return nil
    }

    return NSRange(location: range.location, length: range.length)
}

func derivedSelectedText(from value: String, range: CFRange?) -> String {
    let text = value as NSString

    guard let selectionRange = validatedRange(range, in: text), selectionRange.length > 0 else {
        return ""
    }

    return text.substring(with: selectionRange)
}

func surroundingText(from value: String, range: CFRange?) -> String {
    let text = value as NSString
    guard text.length > 0 else {
        return ""
    }

    let radius = 180

    if let selectionRange = validatedRange(range, in: text) {
        let start = max(0, selectionRange.location - radius)
        let end = min(text.length, selectionRange.location + selectionRange.length + radius)
        return text.substring(with: NSRange(location: start, length: end - start))
    }

    let end = min(text.length, radius * 2)
    return text.substring(with: NSRange(location: 0, length: end))
}

func buildStatus(helperPath: String, prompt: Bool) -> NativeStatus {
    let focusedApp = frontmostAppInfo()

    return NativeStatus(
        helperAvailable: true,
        helperPath: helperPath,
        accessibilityTrusted: isAccessibilityTrusted(prompt: prompt),
        accessibilityPermissionPrompted: prompt,
        focusedAppName: focusedApp.name,
        focusedBundleId: focusedApp.bundleId,
        lastError: ""
    )
}

func buildSelectionSnapshot() -> SelectionSnapshot {
    let focusedApp = frontmostAppInfo()

    guard isAccessibilityTrusted(prompt: false) else {
        return SelectionSnapshot(
            available: false,
            selectedText: "",
            surroundingText: "",
            focusedAppName: focusedApp.name,
            focusedBundleId: focusedApp.bundleId,
            source: "unavailable",
            lastError: "Accessibility permission is required to read the focused selection."
        )
    }

    guard let element = focusedElement() else {
        return SelectionSnapshot(
            available: false,
            selectedText: "",
            surroundingText: "",
            focusedAppName: focusedApp.name,
            focusedBundleId: focusedApp.bundleId,
            source: "unavailable",
            lastError: "Unable to resolve the focused accessibility element."
        )
    }

    let explicitSelectedText = stringAttribute(
        element: element,
        attribute: kAXSelectedTextAttribute as String
    ) ?? ""
    let valueText = stringAttribute(element: element, attribute: kAXValueAttribute as String) ?? ""
    let selectedRange = rangeAttribute(
        element: element,
        attribute: kAXSelectedTextRangeAttribute as String
    )

    let derivedText = explicitSelectedText.isEmpty
        ? derivedSelectedText(from: valueText, range: selectedRange)
        : explicitSelectedText
    let contextText = surroundingText(from: valueText, range: selectedRange)
    let hasReadableContent = !derivedText.isEmpty || !contextText.isEmpty

    return SelectionSnapshot(
        available: hasReadableContent,
        selectedText: derivedText,
        surroundingText: contextText,
        focusedAppName: focusedApp.name,
        focusedBundleId: focusedApp.bundleId,
        source: explicitSelectedText.isEmpty ? "derived-value" : "accessibility",
        lastError: hasReadableContent ? "" : "No readable text selection was found in the focused element."
    )
}

func insertTextViaValueAttribute(
    element: AXUIElement,
    text: String,
    appInfo: (name: String, bundleId: String)
) -> InsertTextResult? {
    guard isAttributeSettable(element: element, attribute: kAXValueAttribute as String) else {
        return nil
    }

    let currentValue = stringAttribute(element: element, attribute: kAXValueAttribute as String) ?? ""
    let currentNSString = currentValue as NSString
    let currentRange = validatedRange(
        rangeAttribute(element: element, attribute: kAXSelectedTextRangeAttribute as String),
        in: currentNSString
    )

    let replacementRange = currentRange ?? NSRange(location: currentNSString.length, length: 0)
    let nextValue = currentNSString.replacingCharacters(in: replacementRange, with: text)
    let setValueError = AXUIElementSetAttributeValue(
        element,
        kAXValueAttribute as CFString,
        nextValue as CFTypeRef
    )

    guard setValueError == .success else {
        return nil
    }

    let nextCursor = CFRange(location: replacementRange.location + (text as NSString).length, length: 0)
    if isAttributeSettable(element: element, attribute: kAXSelectedTextRangeAttribute as String),
       let rangeValue = axRangeValue(nextCursor) {
        _ = AXUIElementSetAttributeValue(
            element,
            kAXSelectedTextRangeAttribute as CFString,
            rangeValue
        )
    }

    return InsertTextResult(
        ok: true,
        method: replacementRange.length > 0 ? "replace-selection" : "append-value",
        focusedAppName: appInfo.name,
        focusedBundleId: appInfo.bundleId,
        lastError: ""
    )
}

func postPasteShortcut() -> Bool {
    guard let source = CGEventSource(stateID: .combinedSessionState) else {
        return false
    }

    let keyCode: CGKeyCode = 9
    guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
          let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false) else {
        return false
    }

    keyDown.flags = .maskCommand
    keyUp.flags = .maskCommand
    keyDown.post(tap: .cghidEventTap)
    keyUp.post(tap: .cghidEventTap)
    return true
}

func insertTextViaPasteboard(text: String, appInfo: (name: String, bundleId: String)) -> InsertTextResult {
    let pasteboard = NSPasteboard.general
    let existingString = pasteboard.string(forType: .string)

    pasteboard.clearContents()
    pasteboard.setString(text, forType: .string)

    let pasted = postPasteShortcut()
    usleep(180_000)

    pasteboard.clearContents()
    if let existingString {
        pasteboard.setString(existingString, forType: .string)
    }

    return InsertTextResult(
        ok: pasted,
        method: pasted ? "pasteboard" : "unavailable",
        focusedAppName: appInfo.name,
        focusedBundleId: appInfo.bundleId,
        lastError: pasted ? "" : "Unable to trigger a paste shortcut for the focused app."
    )
}

func buildInsertTextResult(encodedText: String?, preferredBundleId: String) -> InsertTextResult {
    let appInfo = activatePreferredApp(bundleId: preferredBundleId)

    guard isAccessibilityTrusted(prompt: false) else {
        return InsertTextResult(
            ok: false,
            method: "unavailable",
            focusedAppName: appInfo.name,
            focusedBundleId: appInfo.bundleId,
            lastError: "Accessibility permission is required to insert text into the focused app."
        )
    }

    guard let encodedText, let data = Data(base64Encoded: encodedText),
          let text = String(data: data, encoding: .utf8), !text.isEmpty else {
        return InsertTextResult(
            ok: false,
            method: "unavailable",
            focusedAppName: appInfo.name,
            focusedBundleId: appInfo.bundleId,
            lastError: "No insertion text was provided."
        )
    }

    if let element = focusedElement(),
       let directInsert = insertTextViaValueAttribute(element: element, text: text, appInfo: appInfo) {
        return directInsert
    }

    return insertTextViaPasteboard(text: text, appInfo: appInfo)
}

let command = HelperCommand(rawValue: CommandLine.arguments.dropFirst().first ?? "") ?? .status
let helperPath = CommandLine.arguments.first ?? ""
let encodedTextArgument = CommandLine.arguments.dropFirst(2).first
let preferredBundleIdArgument = CommandLine.arguments.dropFirst(3).first ?? ""

do {
    switch command {
    case .status:
        try emit(buildStatus(helperPath: helperPath, prompt: false))
    case .promptAccessibility:
        try emit(buildStatus(helperPath: helperPath, prompt: true))
    case .readSelection:
        try emit(buildSelectionSnapshot())
    case .insertText:
        try emit(buildInsertTextResult(
            encodedText: encodedTextArgument,
            preferredBundleId: preferredBundleIdArgument
        ))
    }
} catch {
    switch command {
    case .status, .promptAccessibility:
        let fallback = NativeStatus(
            helperAvailable: false,
            helperPath: "",
            accessibilityTrusted: false,
            accessibilityPermissionPrompted: command == .promptAccessibility,
            focusedAppName: "",
            focusedBundleId: "",
            lastError: "Failed to encode native helper output."
        )
        try? emit(fallback)
    case .readSelection:
        let fallback = SelectionSnapshot(
            available: false,
            selectedText: "",
            surroundingText: "",
            focusedAppName: "",
            focusedBundleId: "",
            source: "unavailable",
            lastError: "Failed to encode native helper output."
        )
        try? emit(fallback)
    case .insertText:
        let fallback = InsertTextResult(
            ok: false,
            method: "unavailable",
            focusedAppName: "",
            focusedBundleId: "",
            lastError: "Failed to encode native helper output."
        )
        try? emit(fallback)
    }

    exit(1)
}
