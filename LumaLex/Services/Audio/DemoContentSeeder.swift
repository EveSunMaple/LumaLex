import Foundation
import SwiftData

enum DemoContentSeeder {
    static let audioID = UUID(uuidString: "6FE87BE1-25F6-4D24-9E84-71CD7BFE11A9")!
    private static let seededKey = "didSeedDemo"

    static func seedIfNeeded(in context: ModelContext) throws {
        guard !UserDefaults.standard.bool(forKey: seededKey) else { return }
        guard let bundled = Bundle.main.url(forResource: "Demo", withExtension: "wav") else {
            throw DemoSeedError.missingAudio
        }
        try FileManager.default.createDirectory(at: AudioStorage.directory, withIntermediateDirectories: true)
        let filename = "demo.wav"
        let destination = AudioStorage.url(for: filename)
        if !FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.copyItem(at: bundled, to: destination)
        }

        let document = AudioDocument(id: audioID, title: "Market Update · Demo",
                                     localRelativePath: filename, duration: 11.40)
        let transcript = Transcript(audioDocumentID: audioID, source: "bundled-demo")
        context.insert(document)
        context.insert(transcript)
        let entries: [(Double, Double, String, String)] = [
            (0, 2.925, "The market has already priced in the cut.", "市场已经消化了降息预期。"),
            (3.375, 7.21, "Investors are waiting for the central bank's next decision.", "投资者正在等待央行的下一步决定。"),
            (7.66, 10.95, "Some analysts expect a gradual recovery.", "一些分析师预计经济会逐步复苏。")
        ]
        for (start, end, english, chinese) in entries {
            context.insert(SubtitleSegment(transcriptID: transcript.id, startTime: start,
                                           endTime: end, english: english, chinese: chinese,
                                           tokens: english.split(separator: " ").map(String.init)))
        }
        do {
            try context.save()
            UserDefaults.standard.set(true, forKey: seededKey)
        } catch {
            context.rollback()
            throw error
        }
    }
}

enum DemoSeedError: LocalizedError {
    case missingAudio
    var errorDescription: String? { "The bundled demo audio is missing from the app." }
}

