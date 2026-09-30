import ActivityKit
import Foundation

@MainActor
final class LiveActivityCoordinator {
    private var activity: Activity<LumaLexActivityAttributes>?
    private var lastUpdate = Date.distantPast
    private var lastEnglish = ""
    private var lastIsPlaying = false

    @discardableResult
    func update(title: String, english: String, chinese: String,
                elapsed: TimeInterval, isPlaying: Bool) -> Bool {
        guard UserDefaults.standard.bool(forKey: "lockScreenSubtitles"),
              ActivityAuthorizationInfo().areActivitiesEnabled else { return false }
        guard activity != nil || isPlaying else { return false }
        let now = Date()
        guard (english != lastEnglish && now.timeIntervalSince(lastUpdate) >= 15) ||
                isPlaying != lastIsPlaying else { return false }
        lastEnglish = english
        lastIsPlaying = isPlaying
        lastUpdate = now
        let state = LumaLexActivityAttributes.ContentState(
            english: String(english.prefix(220)), chinese: String(chinese.prefix(160)),
            elapsed: Int(elapsed), elapsedAnchor: now, isPlaying: isPlaying
        )
        let content = ActivityContent(state: state, staleDate: now.addingTimeInterval(90))
        if let activity {
            Task { await activity.update(content) }
        } else {
            activity = try? Activity.request(attributes: .init(title: title), content: content)
        }
        return activity != nil
    }

    func end() {
        let current = activity
        activity = nil
        lastEnglish = ""
        lastIsPlaying = false
        guard let current else { return }
        Task {
            await current.end(nil, dismissalPolicy: .immediate)
            for stale in Activity<LumaLexActivityAttributes>.activities where stale.id != current.id {
                await stale.end(nil, dismissalPolicy: .immediate)
            }
        }
    }
}
