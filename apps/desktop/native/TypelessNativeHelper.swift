import AppKit
import ApplicationServices
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

enum HelperCommand: String {
    case status
    case promptAccessibility = "prompt-accessibility"
    case readSelection = "read-selection"
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

let command = HelperCommand(rawValue: CommandLine.arguments.dropFirst().first ?? "") ?? .status
let helperPath = CommandLine.arguments.first ?? ""

do {
    switch command {
    case .status:
        try emit(buildStatus(helperPath: helperPath, prompt: false))
    case .promptAccessibility:
        try emit(buildStatus(helperPath: helperPath, prompt: true))
    case .readSelection:
        try emit(buildSelectionSnapshot())
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
    }

    exit(1)
}
