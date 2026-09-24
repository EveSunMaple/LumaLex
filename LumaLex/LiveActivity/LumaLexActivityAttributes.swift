import ActivityKit
import Foundation

struct LumaLexActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        let english: String
        let chinese: String
        let elapsed: Int
        let isPlaying: Bool
    }

    let title: String
}

