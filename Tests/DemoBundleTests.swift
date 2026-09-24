import Foundation
import XCTest
@testable import LumaLex

final class DemoBundleTests: XCTestCase {
    func testOfflineDemoIsBundled() {
        XCTAssertNotNil(Bundle.main.url(forResource: "Demo", withExtension: "wav"))
    }

    func testInternalLevelIsDerivedFromVocabularySize() {
        XCTAssertEqual(CEFRLevel.inferred(fromVocabularySize: 550), .a1)
        XCTAssertEqual(CEFRLevel.inferred(fromVocabularySize: 2650), .b1)
        XCTAssertEqual(CEFRLevel.inferred(fromVocabularySize: 12500), .c2)
    }
}
