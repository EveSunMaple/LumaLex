import Foundation
import SwiftData

@Model
final class KnownExpression {
    @Attribute(.unique) var lemma: String
    var markedAt: Date

    init(lemma: String, markedAt: Date = .now) {
        self.lemma = lemma.lowercased()
        self.markedAt = markedAt
    }
}

