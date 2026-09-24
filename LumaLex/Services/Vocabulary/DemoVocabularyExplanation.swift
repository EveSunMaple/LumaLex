import Foundation

enum DemoVocabularyExplanation {
    static func lookup(_ word: String, audioID: UUID) -> VocabularyExplanation? {
        guard audioID == DemoContentSeeder.audioID,
              word.caseInsensitiveCompare("price in") == .orderedSame else { return nil }
        return VocabularyExplanation(
            word: "price in",
            lemma: "price in",
            ipa: "/ˌpraɪs ˈɪn/",
            partOfSpeech: "phrasal verb",
            chinese: "将预期事件计入价格；市场已消化",
            definition: "to reflect an expected event in the current price",
            contextExplanation: "Investors already expected the rate cut, so market prices reflect it.",
            example: "Investors have priced in the policy change.",
            collocations: ["price in a rate cut", "fully priced in"],
            difficultyCEFR: "B2",
            note: "Finance"
        )
    }
}

