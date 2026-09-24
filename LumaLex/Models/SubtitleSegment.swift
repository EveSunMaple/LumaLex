import Foundation
import SwiftData

@Model
final class SubtitleSegment {
    @Attribute(.unique) var id: UUID
    var transcriptID: UUID
    var startTime: TimeInterval
    var endTime: TimeInterval
    var english: String
    var chinese: String
    var tokens: [String]

    init(id: UUID = UUID(), transcriptID: UUID, startTime: TimeInterval, endTime: TimeInterval,
         english: String, chinese: String = "", tokens: [String] = []) {
        self.id = id
        self.transcriptID = transcriptID
        self.startTime = startTime
        self.endTime = endTime
        self.english = english
        self.chinese = chinese
        self.tokens = tokens
    }
}

