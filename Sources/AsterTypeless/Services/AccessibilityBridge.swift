import AppKit
import ApplicationServices
import Foundation

@MainActor
final class AccessibilityBridge {
    private let directInsertRetryDelays: [UInt64] = [140_000_000, 220_000_000]
    private let clipboardRetryDelays: [UInt64] = [120_000_000, 220_000_000]

    struct InsertionResult {
        var appName: String
        var bundleIdentifier: String
        var method: InsertionMethod
        var success: Bool
        var detail: String
    }

    func accessibilityPermission(prompt: Bool) -> PermissionState {
        let options = ["AXTrustedCheckOptionPrompt": prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(options) ? .granted : .required
    }

    func captureSelectionContext() -> SelectionContext {
        let app = frontmostAppInfo()

        guard accessibilityPermission(prompt: false) == .granted else {
            return SelectionContext(
                focusedAppName: app.name,
                bundleIdentifier: app.bundleIdentifier,
                selectedText: "",
                surroundingText: "",
                capturedAt: .now
            )
        }

        guard let element = focusedElement() else {
            return SelectionContext(
                focusedAppName: app.name,
                bundleIdentifier: app.bundleIdentifier,
                selectedText: "",
                surroundingText: "",
                capturedAt: .now
            )
        }

        let value = stringAttribute(of: element, attribute: kAXValueAttribute as String)
        let explicitSelection = stringAttribute(of: element, attribute: kAXSelectedTextAttribute as String)
        let selectionRange = rangeAttribute(of: element, attribute: kAXSelectedTextRangeAttribute as String)

        let derivedSelection = explicitSelection.isEmpty
            ? deriveSelection(from: value, range: selectionRange)
            : explicitSelection
        let contextText = surroundingText(from: value, range: selectionRange)

        return SelectionContext(
            focusedAppName: app.name,
            bundleIdentifier: app.bundleIdentifier,
            selectedText: derivedSelection,
            surroundingText: contextText,
            capturedAt: .now
        )
    }

    func insert(text: String, preferredBundleIdentifier: String?) async -> InsertionResult {
        let target = await activatePreferredTarget(bundleIdentifier: preferredBundleIdentifier)

        guard accessibilityPermission(prompt: false) == .granted else {
            return InsertionResult(
                appName: target.name,
                bundleIdentifier: target.bundleIdentifier,
                method: .unavailable,
                success: false,
                detail: "辅助功能权限未开启"
            )
        }

        for (index, delay) in directInsertRetryDelays.enumerated() {
            if index > 0 {
                try? await Task.sleep(nanoseconds: delay)
            }

            if let element = focusedElement(), insertViaValueAttribute(text: text, into: element) {
                let attemptDetail = index == 0 ? "通过 AXValue 直接写回" : "通过 AXValue 重试后写回"
                return InsertionResult(
                    appName: target.name,
                    bundleIdentifier: target.bundleIdentifier,
                    method: .accessibilityValue,
                    success: true,
                    detail: attemptDetail
                )
            }
        }

        for (index, delay) in clipboardRetryDelays.enumerated() {
            if index > 0 {
                try? await Task.sleep(nanoseconds: delay)
                _ = await activatePreferredTarget(bundleIdentifier: target.bundleIdentifier)
            }

            if await pasteViaClipboard(text: text) {
                let attemptDetail = index == 0
                    ? "AX 直写失败，已回退到剪贴板粘贴"
                    : "AX 直写失败，剪贴板重试后完成写回"
                return InsertionResult(
                    appName: target.name,
                    bundleIdentifier: target.bundleIdentifier,
                    method: .clipboardFallback,
                    success: true,
                    detail: attemptDetail
                )
            }
        }

        return InsertionResult(
            appName: target.name,
            bundleIdentifier: target.bundleIdentifier,
            method: .failed,
            success: false,
            detail: "目标 App 已回焦，但 AX 与剪贴板两条路径都未成功"
        )
    }

    private func activatePreferredTarget(bundleIdentifier: String?) async -> (name: String, bundleIdentifier: String) {
        if let bundleIdentifier, !bundleIdentifier.isEmpty,
           let targetApp = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).first {
            targetApp.activate(options: [])
            try? await Task.sleep(nanoseconds: 180_000_000)
            return (targetApp.localizedName ?? "", targetApp.bundleIdentifier ?? bundleIdentifier)
        }

        return frontmostAppInfo()
    }

    private func frontmostAppInfo() -> (name: String, bundleIdentifier: String) {
        let app = NSWorkspace.shared.frontmostApplication
        return (app?.localizedName ?? "", app?.bundleIdentifier ?? "")
    }

    private func focusedElement() -> AXUIElement? {
        let systemWide = AXUIElementCreateSystemWide()
        var value: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &value)
        guard error == .success, let value, CFGetTypeID(value) == AXUIElementGetTypeID() else {
            return nil
        }
        return unsafeDowncast(value, to: AXUIElement.self)
    }

    private func stringAttribute(of element: AXUIElement, attribute: String) -> String {
        var value: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        guard error == .success, let stringValue = value as? String else {
            return ""
        }
        return stringValue
    }

    private func rangeAttribute(of element: AXUIElement, attribute: String) -> CFRange? {
        var value: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        guard error == .success, let value, CFGetTypeID(value) == AXValueGetTypeID() else {
            return nil
        }

        let axValue = unsafeDowncast(value, to: AXValue.self)
        guard AXValueGetType(axValue) == .cfRange else {
            return nil
        }

        var range = CFRange(location: 0, length: 0)
        guard AXValueGetValue(axValue, .cfRange, &range) else {
            return nil
        }

        return range
    }

    private func deriveSelection(from value: String, range: CFRange?) -> String {
        let stringValue = value as NSString
        guard let range,
              range.location != kCFNotFound,
              range.location >= 0,
              range.length > 0,
              range.location + range.length <= stringValue.length else {
            return ""
        }

        return stringValue.substring(with: NSRange(location: range.location, length: range.length))
    }

    private func surroundingText(from value: String, range: CFRange?) -> String {
        let stringValue = value as NSString
        guard stringValue.length > 0 else {
            return ""
        }

        guard let range,
              range.location != kCFNotFound,
              range.location >= 0,
              range.location <= stringValue.length else {
            return stringValue.substring(with: NSRange(location: 0, length: min(stringValue.length, 220)))
        }

        let radius = 120
        let start = max(0, range.location - radius)
        let end = min(stringValue.length, range.location + max(range.length, 0) + radius)
        return stringValue.substring(with: NSRange(location: start, length: end - start))
    }

    private func insertViaValueAttribute(text: String, into element: AXUIElement) -> Bool {
        var settable = DarwinBoolean(false)
        let settableError = AXUIElementIsAttributeSettable(element, kAXValueAttribute as CFString, &settable)
        guard settableError == .success, settable.boolValue else {
            return false
        }

        let currentValue = stringAttribute(of: element, attribute: kAXValueAttribute as String) as NSString
        let selectedRange = rangeAttribute(of: element, attribute: kAXSelectedTextRangeAttribute as String)
        let replacementRange: NSRange

        if let selectedRange,
           selectedRange.location >= 0,
           selectedRange.length >= 0,
           selectedRange.location + selectedRange.length <= currentValue.length {
            replacementRange = NSRange(location: selectedRange.location, length: selectedRange.length)
        } else {
            replacementRange = NSRange(location: currentValue.length, length: 0)
        }

        let nextValue = currentValue.replacingCharacters(in: replacementRange, with: text)
        let setValueError = AXUIElementSetAttributeValue(element, kAXValueAttribute as CFString, nextValue as CFTypeRef)
        guard setValueError == .success else {
            return false
        }

        let nextCursorRange = CFRange(location: replacementRange.location + (text as NSString).length, length: 0)
        if var rangeValue = Optional(nextCursorRange),
           let axValue = AXValueCreate(.cfRange, &rangeValue) {
            _ = AXUIElementSetAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, axValue)
        }

        return true
    }

    private func pasteViaClipboard(text: String) async -> Bool {
        let pasteboard = NSPasteboard.general
        let snapshot = pasteboardSnapshot(from: pasteboard)

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        let source = CGEventSource(stateID: .combinedSessionState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false)
        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)

        try? await Task.sleep(nanoseconds: 120_000_000)
        restorePasteboard(snapshot, to: pasteboard)

        return keyDown != nil && keyUp != nil
    }

    private func pasteboardSnapshot(from pasteboard: NSPasteboard) -> [[NSPasteboard.PasteboardType: Data]] {
        (pasteboard.pasteboardItems ?? []).map { item in
            var entry: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types {
                if let data = item.data(forType: type) {
                    entry[type] = data
                }
            }
            return entry
        }
    }

    private func restorePasteboard(_ snapshot: [[NSPasteboard.PasteboardType: Data]], to pasteboard: NSPasteboard) {
        pasteboard.clearContents()

        guard !snapshot.isEmpty else { return }

        let items = snapshot.map { itemSnapshot in
            let item = NSPasteboardItem()
            for (type, data) in itemSnapshot {
                item.setData(data, forType: type)
            }
            return item
        }

        pasteboard.writeObjects(items)
    }
}
