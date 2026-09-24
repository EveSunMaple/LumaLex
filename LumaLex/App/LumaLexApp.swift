import SwiftData
import SwiftUI

@main
struct LumaLexApp: App {
    @StateObject private var player = AudioPlayerService()

    var body: some Scene {
        WindowGroup {
            AppRouter()
                .environmentObject(player)
        }
        .modelContainer(for: [
            UserProfile.self,
            AudioDocument.self,
            Transcript.self,
            SubtitleSegment.self,
            VocabularyItem.self,
            KnownExpression.self,
            ReviewRecord.self
        ])
    }
}
