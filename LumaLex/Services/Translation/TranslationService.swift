import Foundation

protocol TranslationService {
    func translate(_ sentences: [String]) async throws -> [String]
}

struct BackendTranslationService: TranslationService {
    func translate(_ sentences: [String]) async throws -> [String] {
        guard let base = BackendConfiguration.baseURL else { throw ExplanationError.backendNotConfigured }
        guard base.scheme == "https" else { throw ExplanationError.invalidURL }
        var translations: [String] = []
        for start in stride(from: 0, to: sentences.count, by: 30) {
            let batch = Array(sentences[start..<min(start + 30, sentences.count)])
            var request = URLRequest(url: base.appendingPathComponent("v1").appendingPathComponent("translate"))
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            if let token = BackendConfiguration.token {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }
            request.httpBody = try JSONEncoder().encode(Request(sentences: batch))
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let response = response as? HTTPURLResponse else { throw ExplanationError.incompleteResponse }
            guard (200..<300).contains(response.statusCode) else { throw ExplanationError.server(response.statusCode) }
            let result = try JSONDecoder().decode(Response.self, from: data)
            guard result.translations.count == batch.count else { throw ExplanationError.incompleteResponse }
            translations += result.translations
        }
        return translations
    }

    private struct Request: Encodable { let sentences: [String] }
    private struct Response: Decodable { let translations: [String] }
}
