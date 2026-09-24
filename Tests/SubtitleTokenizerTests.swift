import XCTest
@testable import LumaLex

final class SubtitleTokenizerTests: XCTestCase {
    func testSupportedPhraseIsOneTappableExpression() {
        let tokens = SubtitleTokenizer.tokenize("The market has priced in the cut.")
        XCTAssertTrue(tokens.contains(.init(display: "priced in", lookup: "price in")))
    }

    func testSavedPhraseIsSupported() {
        let tokens = SubtitleTokenizer.tokenize("A custom phrase appears.", savedPhrases: ["custom phrase"])
        XCTAssertTrue(tokens.contains(.init(display: "custom phrase", lookup: "custom phrase")))
    }
}

