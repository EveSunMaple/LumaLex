import Foundation

enum VocabularyDifficulty: String {
    case known, normal, difficult, specialized
}

struct DifficultyContext {
    let cefr: CEFRLevel
    let estimatedVocabulary: Int
    let knownLemmas: Set<String>
}

protocol VocabularyDifficultyService {
    func classify(_ word: String, context: DifficultyContext) -> VocabularyDifficulty
}

struct HeuristicVocabularyDifficultyService: VocabularyDifficultyService {
    private let common: Set<String> = [
        "a", "about", "after", "all", "and", "are", "as", "at", "be", "been", "but", "by",
        "can", "do", "for", "from", "get", "go", "had", "has", "have", "he", "her", "his",
        "i", "in", "into", "is", "it", "its", "know", "like", "make", "me", "more", "my",
        "not", "of", "on", "one", "or", "our", "out", "people", "say", "see", "she", "so",
        "some", "that", "the", "their", "them", "there", "these", "they", "this", "time",
        "to", "up", "us", "was", "we", "were", "what", "when", "which", "who", "will",
        "with", "would", "you", "your"
    ]
    private let specialized: Set<String> = ["amortization", "photosynthesis", "quantitative", "stochastic"]

    func classify(_ word: String, context: DifficultyContext) -> VocabularyDifficulty {
        let normalized = word.lowercased().trimmingCharacters(in: .punctuationCharacters.union(.whitespaces))
        if context.knownLemmas.contains(normalized) || common.contains(normalized) { return .known }
        if specialized.contains(normalized) { return .specialized }
        let threshold: Int
        switch context.cefr {
        case .a1, .a2: threshold = 6
        case .b1: threshold = 8
        case .b2: threshold = 10
        case .c1, .c2: threshold = 13
        }
        let adjusted = threshold + (context.estimatedVocabulary >= 8000 ? 2 : 0)
        return normalized.count >= adjusted ? .difficult : .normal
    }
}
