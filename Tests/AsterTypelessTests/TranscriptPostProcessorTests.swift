import XCTest
@testable import AsterTypeless

@MainActor
final class TranscriptPostProcessorTests: XCTestCase {
    func testAcronymFoldingAndLexiconReplacement() {
        let processor = TranscriptPostProcessor()
        let context = VoiceFlowContext(
            appName: "Cursor",
            bundleIdentifier: "com.todesktop.cursor",
            windowTitle: "VoiceFlowEngine.swift",
            selectedText: "",
            surroundingText: "",
            captureMode: .manual,
            mode: .dictate,
            locale: "zh-CN",
            lastSuccessfulDeliveryMethod: .accessibilityValue,
            capturedAt: .now
        )
        let lexicon = [
            LexiconEntry(
                canonical: "AsterTypeless",
                variants: ["aster typeless"],
                locale: "zh-CN",
                appBundlePattern: "cursor",
                hitCount: 3,
                promotedAt: .now,
                updatedAt: .now
            )
        ]

        let result = processor.process(
            rawText: "请把 A P I 接到 aster typeless 里",
            context: context,
            lexicon: lexicon
        )

        XCTAssertTrue(result.normalizedText.contains("API"))
        XCTAssertTrue(result.normalizedText.contains("AsterTypeless"))
    }
}
