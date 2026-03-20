import XCTest
@testable import AsterTypeless

final class ProviderPresetTests: XCTestCase {
    func testTypelessLikePresetSelectsExpectedProviders() {
        var config = ProviderConfiguration.default
        config.applyPreset(.typelessLike)

        XCTAssertEqual(config.selectedLLM, .cerebras)
        XCTAssertEqual(config.selectedSTT, .groq)
    }
}
