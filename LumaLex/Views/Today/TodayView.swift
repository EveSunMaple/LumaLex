import Foundation
import SwiftData
import SwiftUI

struct TodayView: View {
    @Query private var words: [VocabularyItem]
    @Query(sort: \AudioDocument.importedAt, order: .reverse) private var audio: [AudioDocument]

    private var dueCount: Int {
        words.filter {
            ReviewScheduler.isDue(
                ReviewState(stage: $0.reviewStage, nextReviewDate: $0.nextReviewDate, status: $0.status),
                at: .now
            )
        }.count
    }

    private var recentAudio: AudioDocument? {
        audio.max { ($0.lastPlayedAt ?? $0.importedAt) < ($1.lastPlayedAt ?? $1.importedAt) }
    }

    private var greeting: String {
        switch Calendar.current.component(.hour, from: .now) {
        case 0..<12: "Good morning"
        case 12..<18: "Good afternoon"
        default: "Good evening"
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(greeting)
                        .font(.largeTitle.bold())
                    Text(dueCount == 1 ? "1 word today" : "\(dueCount) words today")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    if dueCount > 0 {
                        NavigationLink {
                            ReviewView()
                        } label: {
                            Text("Start Review")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .padding(.top, 12)
                    } else {
                        Text("You're all caught up.")
                            .foregroundStyle(.secondary)
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Continue Listening")
                        .font(.headline)
                    if let latest = recentAudio {
                        NavigationLink {
                            PlayerView(documentID: latest.id)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(latest.title).font(.body)
                                let remaining = max(0, latest.duration - latest.lastPlaybackTime)
                                Text("\(Int(remaining) / 60):\(String(format: "%02d", Int(remaining) % 60)) remaining")
                                    .font(.subheadline).foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    } else {
                        Text("Import audio in Library to begin listening.")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
        }
        .navigationTitle("Today")
    }
}
