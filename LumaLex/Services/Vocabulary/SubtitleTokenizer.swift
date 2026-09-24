import Foundation

struct SubtitleToken: Equatable {
    let display: String
    let lookup: String
}

enum SubtitleTokenizer {
    private static let phrases: [String: String] = [
        "price in": "price in", "priced in": "price in",
        "look up": "look up", "figure out": "figure out",
        "carry out": "carry out", "set up": "set up",
        "take over": "take over", "point out": "point out"
    ]

    static func tokenize(_ sentence: String, savedPhrases: Set<String> = []) -> [SubtitleToken] {
        let words = sentence.split(separator: " ").map(String.init)
        var result: [SubtitleToken] = []
        var index = 0
        while index < words.count {
            if index + 1 < words.count {
                let pair = [words[index], words[index + 1]].joined(separator: " ")
                let normalized = pair.lowercased().trimmingCharacters(in: .punctuationCharacters)
                if let lemma = phrases[normalized] ?? (savedPhrases.contains(normalized) ? normalized : nil) {
                    result.append(.init(display: pair, lookup: lemma))
                    index += 2
                    continue
                }
            }
            result.append(.init(display: words[index],
                                lookup: words[index].trimmingCharacters(in: .punctuationCharacters)))
            index += 1
        }
        return result
    }
}

