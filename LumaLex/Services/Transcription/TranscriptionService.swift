import Foundation
import Speech

protocol TranscriptionService {
    func transcribe(_ url: URL) async throws -> [ParsedSubtitle]
}

enum TranscriptionError: LocalizedError {
    case denied, unavailable, empty

    var errorDescription: String? {
        switch self {
        case .denied: "Speech recognition permission was not granted."
        case .unavailable: "On-device English speech recognition is unavailable on this device. Import SRT or VTT instead."
        case .empty: "No speech was found in this audio."
        }
    }
}

struct OnDeviceTranscriptionService: TranscriptionService {
    func transcribe(_ url: URL) async throws -> [ParsedSubtitle] {
        let permission = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
        }
        guard permission == .authorized else { throw TranscriptionError.denied }
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US")),
              recognizer.isAvailable, recognizer.supportsOnDeviceRecognition else {
            throw TranscriptionError.unavailable
        }
        let request = SFSpeechURLRecognitionRequest(url: url)
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = false
        let transcription: SFTranscription = try await withCheckedThrowingContinuation { continuation in
            let lock = NSLock()
            var finished = false
            recognizer.recognitionTask(with: request) { result, error in
                lock.lock()
                defer { lock.unlock() }
                guard !finished else { return }
                if let error {
                    finished = true
                    continuation.resume(throwing: error)
                } else if let result, result.isFinal {
                    finished = true
                    continuation.resume(returning: result.bestTranscription)
                }
            }
        }
        let words = transcription.segments
        guard !words.isEmpty else { throw TranscriptionError.empty }
        var output: [ParsedSubtitle] = []
        var group: [SFTranscriptionSegment] = []
        for word in words {
            if let previous = group.last, word.timestamp - (previous.timestamp + previous.duration) > 1 {
                output.append(makeSubtitle(group))
                group.removeAll()
            }
            group.append(word)
            if word.substring.hasSuffix(".") || word.substring.hasSuffix("?") ||
                word.substring.hasSuffix("!") || group.count >= 18 {
                output.append(makeSubtitle(group))
                group.removeAll()
            }
        }
        if !group.isEmpty { output.append(makeSubtitle(group)) }
        return output
    }

    private func makeSubtitle(_ words: [SFTranscriptionSegment]) -> ParsedSubtitle {
        let first = words[0]
        let last = words[words.count - 1]
        return ParsedSubtitle(start: first.timestamp, end: last.timestamp + last.duration,
                              english: words.map(\.substring).joined(separator: " "), chinese: "")
    }
}

