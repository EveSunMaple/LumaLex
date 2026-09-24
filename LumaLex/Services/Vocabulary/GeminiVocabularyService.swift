import Foundation

struct VocabularyExplanation: Codable, Equatable {
    let word: String
    let lemma: String
    let ipa: String
    let partOfSpeech: String
    let chinese: String
    let definition: String
    let contextExplanation: String
    let example: String
    let collocations: [String]
    let difficultyCEFR: String
    let note: String

    enum CodingKeys: String, CodingKey {
        case word, lemma, ipa, chinese, definition, example, collocations, note
        case partOfSpeech = "part_of_speech"
        case contextExplanation = "context_explanation"
        case difficultyCEFR = "difficulty_cefr"
    }

    static func decode(_ data: Data) throws -> Self {
        let value = try JSONDecoder().decode(Self.self, from: data)
        guard !value.word.isEmpty, value.word.count <= 120,
              !value.chinese.isEmpty, value.chinese.count <= 300,
              !value.definition.isEmpty, value.definition.count <= 800,
              value.contextExplanation.count <= 1000,
              value.example.count <= 800,
              value.collocations.count <= 3 else {
            throw ExplanationError.incompleteResponse
        }
        return value
    }
}

enum ExplanationError: LocalizedError {
    case backendNotConfigured, invalidURL, incompleteResponse, server(Int)

    var errorDescription: String? {
        switch self {
        case .backendNotConfigured: "No explanation service is configured. You can enter a meaning manually."
        case .invalidURL: "The backend URL must use HTTPS."
        case .incompleteResponse: "The explanation service returned incomplete data."
        case .server(let code): "The explanation service returned HTTP \(code)."
        }
    }
}

protocol VocabularyExplaining {
    func explain(word: String, sentence: String, level: CEFRLevel) async throws -> VocabularyExplanation
}

struct GeminiVocabularyService: VocabularyExplaining {
    var baseURL: URL? { BackendConfiguration.baseURL }

    func explain(word: String, sentence: String, level: CEFRLevel) async throws -> VocabularyExplanation {
        guard let baseURL else { throw ExplanationError.backendNotConfigured }
        guard baseURL.scheme == "https" else { throw ExplanationError.invalidURL }
        let url = baseURL.appendingPathComponent("v1")
            .appendingPathComponent("vocabulary").appendingPathComponent("explain")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = BackendConfiguration.token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONEncoder().encode(Request(word: word, sentence: sentence,
                                                             cefrLevel: level.rawValue))
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse else { throw ExplanationError.incompleteResponse }
        guard (200..<300).contains(response.statusCode) else { throw ExplanationError.server(response.statusCode) }
        return try VocabularyExplanation.decode(data)
    }

    private struct Request: Encodable {
        let word: String
        let sentence: String
        let cefrLevel: String
    }
}

enum BackendConfiguration {
    static var baseURL: URL? {
        guard let value = UserDefaults.standard.string(forKey: "backendURL") else { return nil }
        return URL(string: value)
    }

    static var token: String? {
        get { KeychainStore.read("backendToken") }
        set {
            if let newValue, !newValue.isEmpty { KeychainStore.write(newValue, for: "backendToken") }
            else { KeychainStore.delete("backendToken") }
        }
    }
}
