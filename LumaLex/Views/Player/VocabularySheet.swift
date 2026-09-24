import SwiftData
import SwiftUI

struct VocabularySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var vocabulary: [VocabularyItem]
    @Query private var known: [KnownExpression]
    @Query private var profiles: [UserProfile]
    @State private var explanation: VocabularyExplanation?
    @State private var chineseMeaning = ""
    @State private var englishDefinition = ""
    @State private var pronunciation = ""
    @State private var partOfSpeech = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    let word: String
    let sentence: String
    let audioID: UUID

    private var existing: VocabularyItem? {
        vocabulary.first { $0.lemma.caseInsensitiveCompare(word) == .orderedSame }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(word).font(.title.bold())
                    if !pronunciation.isEmpty { Text(pronunciation).foregroundStyle(.secondary) }
                    Text(sentence).italic()
                }
                Section("Meaning") {
                    TextField("Chinese meaning", text: $chineseMeaning)
                    TextField("Short English definition", text: $englishDefinition, axis: .vertical)
                    if !partOfSpeech.isEmpty { LabeledContent("Part of speech", value: partOfSpeech) }
                }
                if let explanation {
                    Section("In Context") {
                        Text(explanation.contextExplanation)
                        Text(explanation.example).foregroundStyle(.secondary)
                        if !explanation.note.isEmpty { Text(explanation.note).font(.footnote) }
                    }
                }
                if BackendConfiguration.baseURL != nil && existing == nil {
                    Section {
                        Button("Explain with Server") { Task { await loadExplanation() } }
                            .disabled(isLoading)
                        Text("Sends this word and its sentence to your configured server and its AI provider.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }
                if isLoading { ProgressView("Getting explanation") }
                if let errorMessage { Text(errorMessage).font(.footnote).foregroundStyle(.secondary) }
                if existing != nil { Text("Already in Vocabulary").foregroundStyle(.secondary) }
                if known.contains(where: { $0.lemma == word.lowercased() }) {
                    Text("Marked as known").foregroundStyle(.secondary)
                } else {
                    Button("I Already Know This") { markKnown() }
                }
            }
            .navigationTitle("Word")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { add() }
                        .disabled(chineseMeaning.trimmingCharacters(in: .whitespaces).isEmpty || existing != nil)
                }
            }
            .task { loadCachedWord() }
        }
    }

    private func loadCachedWord() {
        if let existing {
            chineseMeaning = existing.chineseMeaning
            englishDefinition = existing.englishDefinition
            pronunciation = existing.pronunciation ?? ""
            partOfSpeech = existing.partOfSpeech ?? ""
        } else if let demo = DemoVocabularyExplanation.lookup(word, audioID: audioID) {
            apply(demo)
        }
    }

    private func loadExplanation() async {
        guard BackendConfiguration.baseURL != nil else {
            errorMessage = ExplanationError.backendNotConfigured.localizedDescription
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            let value = try await GeminiVocabularyService().explain(
                word: word, sentence: sentence, level: profiles.first?.cefrLevel ?? .b1
            )
            apply(value)
        } catch { errorMessage = error.localizedDescription }
    }

    private func apply(_ value: VocabularyExplanation) {
        explanation = value
        chineseMeaning = value.chinese
        englishDefinition = value.definition
        pronunciation = value.ipa
        partOfSpeech = value.partOfSpeech
    }

    private func add() {
        let state = ReviewScheduler.initial(at: .now)
        modelContext.insert(VocabularyItem(word: word, lemma: explanation?.lemma ?? word.lowercased(),
                                           pronunciation: pronunciation.isEmpty ? nil : pronunciation,
                                           partOfSpeech: partOfSpeech.isEmpty ? nil : partOfSpeech,
                                           chineseMeaning: chineseMeaning.trimmingCharacters(in: .whitespaces),
                                           englishDefinition: englishDefinition,
                                           originalSentence: sentence, sourceAudioID: audioID,
                                           reviewStage: state.stage, nextReviewDate: state.nextReviewDate))
        do {
            try modelContext.save()
            dismiss()
        } catch {
            modelContext.rollback()
            errorMessage = error.localizedDescription
        }
    }

    private func markKnown() {
        modelContext.insert(KnownExpression(lemma: word))
        do {
            try modelContext.save()
            dismiss()
        } catch {
            modelContext.rollback()
            errorMessage = error.localizedDescription
        }
    }
}
