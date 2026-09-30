import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct LibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var player: AudioPlayerService
    @Query(sort: \AudioDocument.importedAt, order: .reverse) private var audio: [AudioDocument]
    @State private var importingAudio = false
    @State private var isBusy = false
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if audio.isEmpty {
                ContentUnavailableView("No Audio Yet", systemImage: "waveform",
                                       description: Text("Import an MP3, M4A, WAV, or other supported audio file."))
            } else {
                List {
                    ForEach(audio) { document in
                        NavigationLink {
                            PlayerView(documentID: document.id)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(document.title)
                                Text(document.importedAt, style: .date)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onDelete(perform: deleteAudio)
                }
            }
        }
        .navigationTitle("Library")
        .toolbar {
            Button("Import Audio", systemImage: "plus") { importingAudio = true }
                .disabled(isBusy)
        }
        .fileImporter(isPresented: $importingAudio, allowedContentTypes: [.audio]) { result in
            guard case .success(let url) = result else { return }
            isBusy = true
            Task {
                var importedPath: String?
                do {
                    let imported = try await Task.detached(priority: .userInitiated) {
                        try await AudioStorage.importAudio(from: url)
                    }.value
                    importedPath = imported.path
                    let document = AudioDocument(title: url.deletingPathExtension().lastPathComponent,
                                                 localRelativePath: imported.path, duration: imported.duration)
                    modelContext.insert(document)
                    try modelContext.save()
                } catch {
                    modelContext.rollback()
                    if let importedPath {
                        try? FileManager.default.removeItem(at: AudioStorage.url(for: importedPath))
                    }
                    errorMessage = error.localizedDescription
                }
                isBusy = false
            }
        }
        .alert("Library Error", isPresented: Binding(get: { errorMessage != nil },
                                                      set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
    }

    private func deleteAudio(at offsets: IndexSet) {
        let selected = offsets.map { audio[$0] }
        for document in selected {
            if player.documentID == document.id { player.stop() }
            do {
                let documentID = document.id
                let ownedTranscripts = try modelContext.fetch(
                    FetchDescriptor<Transcript>(predicate: #Predicate { $0.audioDocumentID == documentID }))
                let transcriptIDs = ownedTranscripts.map(\.id)
                for transcript in ownedTranscripts { modelContext.delete(transcript) }
                if !transcriptIDs.isEmpty {
                    let ownedSegments = try modelContext.fetch(
                        FetchDescriptor<SubtitleSegment>(predicate: #Predicate { transcriptIDs.contains($0.transcriptID) }))
                    for segment in ownedSegments { modelContext.delete(segment) }
                }
                modelContext.delete(document)
            } catch {
                modelContext.rollback()
                errorMessage = error.localizedDescription
                return
            }
        }
        do {
            try modelContext.save()
            for document in selected {
                try? FileManager.default.removeItem(at: AudioStorage.url(for: document.localRelativePath))
            }
        } catch {
            modelContext.rollback()
            errorMessage = error.localizedDescription
        }
    }
}
