import Foundation
import SwiftData

enum CEFRLevel: String, CaseIterable, Codable {
    case a1 = "A1", a2 = "A2", b1 = "B1", b2 = "B2", c1 = "C1", c2 = "C2"

    static func inferred(fromVocabularySize size: Int) -> Self {
        switch size {
        case ..<1200: .a1
        case ..<2500: .a2
        case ..<4500: .b1
        case ..<8000: .b2
        case ..<12000: .c1
        default: .c2
        }
    }
}

@Model
final class UserProfile {
    @Attribute(.unique) var id: UUID
    var cefrLevelRaw: String
    var estimatedVocabulary: Int
    var assessmentDate: Date

    var cefrLevel: CEFRLevel {
        get { CEFRLevel(rawValue: cefrLevelRaw) ?? .a1 }
        set { cefrLevelRaw = newValue.rawValue }
    }

    init(id: UUID = UUID(), cefrLevel: CEFRLevel, estimatedVocabulary: Int, assessmentDate: Date = .now) {
        self.id = id
        self.cefrLevelRaw = cefrLevel.rawValue
        self.estimatedVocabulary = estimatedVocabulary
        self.assessmentDate = assessmentDate
    }
}
