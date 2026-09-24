import XCTest
@testable import LumaLex

final class TranscriptParserTests: XCTestCase {
    func testParsesBilingualSRTAndWebVTT() {
        let input = """
        WEBVTT

        1
        00:00:01,000 --> 00:00:03,500
        The market has priced in the cut.
        市场已经消化了降息预期。

        00:04.000 --> 00:06.000
        Another sentence.
        """
        let result = TranscriptParser.parse(input)
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].start, 1)
        XCTAssertEqual(result[0].end, 3.5)
        XCTAssertEqual(result[0].english, "The market has priced in the cut.")
        XCTAssertEqual(result[0].chinese, "市场已经消化了降息预期。")
        XCTAssertEqual(result[1].start, 4)
    }

    func testRejectsUntimedOrBackwardsSegments() {
        XCTAssertTrue(TranscriptParser.parse("Hello world").isEmpty)
        XCTAssertTrue(TranscriptParser.parse("00:03 --> 00:02\nNope").isEmpty)
    }

    func testTimestampLookupIncludesStartButExcludesEnd() {
        let subtitles = TranscriptParser.parse("00:01 --> 00:03\nFirst\n\n00:03 --> 00:05\nSecond")
        XCTAssertNil(TranscriptParser.activeIndex(at: 0.99, in: subtitles))
        XCTAssertEqual(TranscriptParser.activeIndex(at: 1, in: subtitles), 0)
        XCTAssertEqual(TranscriptParser.activeIndex(at: 3, in: subtitles), 1)
        XCTAssertNil(TranscriptParser.activeIndex(at: 5, in: subtitles))
    }
}

