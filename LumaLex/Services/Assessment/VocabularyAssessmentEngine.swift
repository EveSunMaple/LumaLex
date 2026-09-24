import Foundation

struct AssessmentWord: Identifiable {
    let word: String
    let level: CEFRLevel
    var id: String { word }
}

struct AssessmentEstimate {
    let vocabularySize: Int
}

protocol VocabularyAssessmentEngine {
    var words: [AssessmentWord] { get }
    func estimate(knownWords: Set<String>) -> AssessmentEstimate
}

struct InitialVocabularyAssessmentEngine: VocabularyAssessmentEngine {
    let words: [AssessmentWord] = [
        .init(word: "house", level: .a1), .init(word: "family", level: .a1),
        .init(word: "journey", level: .a2), .init(word: "improve", level: .a2),
        .init(word: "benefit", level: .b1), .init(word: "concern", level: .b1),
        .init(word: "perspective", level: .b2), .init(word: "inevitable", level: .b2),
        .init(word: "ambiguous", level: .c1), .init(word: "contemplate", level: .c1),
        .init(word: "ubiquitous", level: .c2), .init(word: "quintessential", level: .c2)
    ]

    func estimate(knownWords: Set<String>) -> AssessmentEstimate {
        let levels: [CEFRLevel] = [.a1, .a2, .b1, .b2, .c1, .c2]
        let sizes = [500, 1200, 2500, 4500, 8000, 12000]
        var reached = 0
        for (index, level) in levels.enumerated() {
            let items = words.filter { $0.level == level }
            if items.filter({ knownWords.contains($0.word) }).count >= 1 { reached = index }
            else { break }
        }
        let knownCount = words.filter { knownWords.contains($0.word) }.count
        let withinBand = knownCount == 0 ? 0 : min(knownCount * 50, 500)
        return AssessmentEstimate(vocabularySize: sizes[reached] + withinBand)
    }
}
