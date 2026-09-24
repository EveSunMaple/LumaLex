import Foundation
import SwiftData

@Model
final class AudioDocument {
    @Attribute(.unique) var id: UUID
    var title: String
    var localRelativePath: String
    var duration: TimeInterval
    var lastPlaybackTime: TimeInterval
    var lastPlayedAt: Date?
    var importedAt: Date

    init(id: UUID = UUID(), title: String, localRelativePath: String, duration: TimeInterval = 0,
         lastPlaybackTime: TimeInterval = 0, importedAt: Date = .now) {
        self.id = id
        self.title = title
        self.localRelativePath = localRelativePath
        self.duration = duration
        self.lastPlaybackTime = lastPlaybackTime
        self.lastPlayedAt = nil
        self.importedAt = importedAt
    }
}

@Model
final class Transcript {
    @Attribute(.unique) var id: UUID
    var audioDocumentID: UUID
    var source: String
    var createdAt: Date

    init(id: UUID = UUID(), audioDocumentID: UUID, source: String, createdAt: Date = .now) {
        self.id = id
        self.audioDocumentID = audioDocumentID
        self.source = source
        self.createdAt = createdAt
    }
}
