import SwiftData
import SwiftUI

struct ProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var player: AudioPlayerService
    @Query private var profiles: [UserProfile]
    @AppStorage("backendURL") private var backendURL = ""
    @AppStorage("lockScreenSubtitles") private var lockScreenSubtitles = false
    @State private var backendToken = ""
    @State private var showingAssessment = false
    @State private var confirmDelete = false
    @State private var errorMessage: String?

    var body: some View {
        List {
            Section("Vocabulary Estimate") {
                if let profile = profiles.first {
                    LabeledContent("Estimated vocabulary", value: profile.estimatedVocabulary.formatted())
                    LabeledContent("Assessed", value: profile.assessmentDate.formatted(date: .abbreviated, time: .omitted))
                }
                Button("Retake Vocabulary Check") { showingAssessment = true }
                NavigationLink("Known Words") { KnownExpressionsView() }
            }
            Section("Optional AI Server") {
                TextField("https://api.example.com", text: $backendURL)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    .autocorrectionDisabled()
                SecureField("Access token", text: $backendToken)
                Button("Save Access Token") { BackendConfiguration.token = backendToken }
                Text("The server receives only content you choose to explain, translate, or transcribe. Audio and transcripts remain local otherwise.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section("Privacy") {
                Toggle("Show subtitles on Lock Screen", isOn: $lockScreenSubtitles)
                Text("When enabled, the current sentence may appear in a Live Activity while audio plays.")
                    .font(.footnote).foregroundStyle(.secondary)
                Button("Delete All Local Data", role: .destructive) { confirmDelete = true }
            }
        }
        .navigationTitle("Profile")
        .onAppear { backendToken = BackendConfiguration.token ?? "" }
        .onChange(of: lockScreenSubtitles) { _, _ in player.refreshLockScreenPresentation() }
        .sheet(isPresented: $showingAssessment) { AssessmentView() }
        .confirmationDialog("Delete all audio, transcripts, known words, vocabulary, and review history?",
                            isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete Everything", role: .destructive) { deleteAll() }
        }
        .alert("Could Not Delete Data", isPresented: Binding(get: { errorMessage != nil },
                                                              set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
    }

    private func deleteAll() {
        player.stop()
        do {
            let paths = try modelContext.fetch(FetchDescriptor<AudioDocument>()).map(\.localRelativePath)
            try modelContext.delete(model: ReviewRecord.self)
            try modelContext.delete(model: VocabularyItem.self)
            try modelContext.delete(model: KnownExpression.self)
            try modelContext.delete(model: SubtitleSegment.self)
            try modelContext.delete(model: Transcript.self)
            try modelContext.delete(model: AudioDocument.self)
            try modelContext.delete(model: UserProfile.self)
            try modelContext.save()
            for path in paths { try? FileManager.default.removeItem(at: AudioStorage.url(for: path)) }
            backendURL = ""
            backendToken = ""
            lockScreenSubtitles = false
            UserDefaults.standard.set(false, forKey: "didSeedDemo")
            BackendConfiguration.token = nil
        } catch {
            modelContext.rollback()
            errorMessage = error.localizedDescription
        }
    }
}
