import SwiftData
import SwiftUI

struct AssessmentView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    @State private var started = false
    @State private var index = 0
    @State private var knownWords: Set<String> = []
    @State private var showingResult = false
    @State private var errorMessage: String?

    private let engine = InitialVocabularyAssessmentEngine()

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()
                if showingResult {
                    let result = engine.estimate(knownWords: knownWords)
                    Text("Estimated vocabulary").foregroundStyle(.secondary)
                    Text("About \(result.vocabularySize.formatted()) words")
                        .font(.largeTitle.bold())
                    Text("This short check is only an estimate.")
                        .font(.footnote).foregroundStyle(.secondary)
                    Button("Continue") { save(result) }.buttonStyle(.borderedProminent)
                } else if started {
                    Text("\(index + 1) / \(engine.words.count)")
                        .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                    Text(engine.words[index].word).font(.largeTitle.bold())
                    Text("Do you know this word?").foregroundStyle(.secondary)
                    HStack {
                        Button("Not Yet") { answer(false) }.buttonStyle(.bordered)
                        Button("I Know It") { answer(true) }.buttonStyle(.borderedProminent)
                    }
                } else {
                    Image(systemName: "waveform.and.book").font(.largeTitle).foregroundStyle(.tint)
                    Text("Welcome to LumaLex").font(.largeTitle.bold())
                    Text("Listen, capture new words, and review them at the right time.")
                        .multilineTextAlignment(.center).foregroundStyle(.secondary)
                    Button("Estimate My Vocabulary") { started = true }.buttonStyle(.borderedProminent)
                }
                Spacer()
            }
            .padding(32)
            .frame(maxWidth: .infinity)
            .alert("Could Not Save Assessment", isPresented: Binding(get: { errorMessage != nil },
                                                                      set: { if !$0 { errorMessage = nil } })) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: { Text(errorMessage ?? "") }
        }
    }

    private func answer(_ known: Bool) {
        if known { knownWords.insert(engine.words[index].word) }
        if index + 1 == engine.words.count { showingResult = true }
        else { index += 1 }
    }

    private func save(_ result: AssessmentEstimate) {
        if let profile = profiles.first {
            profile.cefrLevel = .inferred(fromVocabularySize: result.vocabularySize)
            profile.estimatedVocabulary = result.vocabularySize
            profile.assessmentDate = .now
        } else {
            modelContext.insert(UserProfile(cefrLevel: .inferred(fromVocabularySize: result.vocabularySize),
                                            estimatedVocabulary: result.vocabularySize))
        }
        do {
            try modelContext.save()
            dismiss()
        } catch {
            modelContext.rollback()
            errorMessage = error.localizedDescription
        }
    }
}
