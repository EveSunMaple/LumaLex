import Foundation
import SwiftData

enum ReviewResult: String, Codable {
    case forgot, remembered
}

@Model
final class ReviewRecord {
    @Attribute(.unique) var id: UUID
    var vocabularyID: UUID
    var date: Date
    var resultRaw: String
    var previousStage: Int
    var newStage: Int

    var result: ReviewResult {
        get { ReviewResult(rawValue: resultRaw) ?? .forgot }
        set { resultRaw = newValue.rawValue }
    }

    init(id: UUID = UUID(), vocabularyID: UUID, date: Date, result: ReviewResult,
         previousStage: Int, newStage: Int) {
        self.id = id
        self.vocabularyID = vocabularyID
        self.date = date
        self.resultRaw = result.rawValue
        self.previousStage = previousStage
        self.newStage = newStage
    }
}

