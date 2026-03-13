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

enum HelperCommand: String {
    case status
    case promptAccessibility = "prompt-accessibility"
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

func emit(_ status: NativeStatus) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.withoutEscapingSlashes]
    let data = try encoder.encode(status)
    guard let text = String(data: data, encoding: .utf8) else {
        throw NSError(domain: "TypelessNativeHelper", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to encode JSON output"])
    }
    FileHandle.standardOutput.write(Data(text.utf8))
}

let command = HelperCommand(rawValue: CommandLine.arguments.dropFirst().first ?? "") ?? .status
let helperPath = CommandLine.arguments.first ?? ""
let prompt = command == .promptAccessibility
let accessibilityTrusted = isAccessibilityTrusted(prompt: prompt)
let focusedApp = frontmostAppInfo()

let status = NativeStatus(
    helperAvailable: true,
    helperPath: helperPath,
    accessibilityTrusted: accessibilityTrusted,
    accessibilityPermissionPrompted: prompt,
    focusedAppName: focusedApp.name,
    focusedBundleId: focusedApp.bundleId,
    lastError: ""
)

do {
    try emit(status)
} catch {
    let fallback = """
    {"helperAvailable":false,"helperPath":"","accessibilityTrusted":false,"accessibilityPermissionPrompted":\(prompt ? "true" : "false"),"focusedAppName":"","focusedBundleId":"","lastError":"Failed to encode native helper output."}
    """
    FileHandle.standardOutput.write(Data(fallback.utf8))
    exit(1)
}
