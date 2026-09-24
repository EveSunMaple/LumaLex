import Foundation

struct BackendTranscriptionService: TranscriptionService {
    func transcribe(_ url: URL) async throws -> [ParsedSubtitle] {
        guard let base = BackendConfiguration.baseURL else { throw ExplanationError.backendNotConfigured }
        guard base.scheme == "https" else { throw ExplanationError.invalidURL }
        let data = try await Task.detached(priority: .userInitiated) {
            try Data(contentsOf: url)
        }.value
        guard data.count <= 12_000_000 else { throw BackendTranscriptionError.tooLarge }
        let mime: String
        switch url.pathExtension.lowercased() {
        case "mp3": mime = "audio/mpeg"
        case "m4a", "mp4": mime = "audio/mp4"
        case "wav": mime = "audio/wav"
        default: throw BackendTranscriptionError.unsupportedFormat
        }
        var request = URLRequest(url: base.appendingPathComponent("v1").appendingPathComponent("transcribe"))
        request.httpMethod = "POST"
        request.timeoutInterval = 120
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = BackendConfiguration.token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONEncoder().encode(Request(mimeType: mime, audioBase64: data.base64EncodedString()))
        let (result, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse else { throw ExplanationError.incompleteResponse }
        guard (200..<300).contains(response.statusCode) else { throw ExplanationError.server(response.statusCode) }
        let decoded = try JSONDecoder().decode(Response.self, from: result)
        let segments = decoded.segments.compactMap { item -> ParsedSubtitle? in
            guard item.start.isFinite, item.end.isFinite,
                  item.start >= 0, item.end > item.start, !item.english.isEmpty else { return nil }
            return ParsedSubtitle(start: item.start, end: item.end, english: item.english, chinese: "")
        }
        guard !segments.isEmpty else { throw TranscriptionError.empty }
        return segments.sorted { $0.start < $1.start }
    }

    private struct Request: Encodable { let mimeType: String; let audioBase64: String }
    private struct Response: Decodable { let segments: [Segment] }
    private struct Segment: Decodable { let start: Double; let end: Double; let english: String }
}

enum BackendTranscriptionError: LocalizedError {
    case tooLarge, unsupportedFormat
    var errorDescription: String? {
        switch self {
        case .tooLarge: "Remote transcription supports audio files up to 12 MB."
        case .unsupportedFormat: "Remote transcription supports MP3, M4A, and WAV."
        }
    }
}
