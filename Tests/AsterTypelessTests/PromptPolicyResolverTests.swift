import XCTest
@testable import AsterTypeless

@MainActor
final class PromptPolicyResolverTests: XCTestCase {
    func testCodeContextResolvesCodePolicy() {
        let resolver = PromptPolicyResolver()
        let context = VoiceFlowContext(
            appName: "Cursor",
            bundleIdentifier: "com.todesktop.230313mzl4w4u92",
            windowTitle: "AppModel.swift",
            selectedText: "",
            surroundingText: "let value = 1",
            captureMode: .manual,
            mode: .dictate,
            locale: "zh-CN",
            lastSuccessfulDeliveryMethod: .accessibilityValue,
            capturedAt: .now
        )

        let policy = resolver.resolve(context: context, enabled: true)
        XCTAssertEqual(policy.id, "code")
    }

    func testDisabledContextAwarenessFallsBackToDefault() {
        let resolver = PromptPolicyResolver()
        let context = VoiceFlowContext(
            appName: "Slack",
            bundleIdentifier: "com.tinyspeck.slackmacgap",
            windowTitle: "",
            selectedText: "",
            surroundingText: "",
            captureMode: .manual,
            mode: .dictate,
            locale: "zh-CN",
            lastSuccessfulDeliveryMethod: nil,
            capturedAt: .now
        )

        let policy = resolver.resolve(context: context, enabled: false)
        XCTAssertEqual(policy.id, "default")
    }
}
