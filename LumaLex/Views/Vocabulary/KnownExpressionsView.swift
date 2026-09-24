import SwiftData
import SwiftUI

struct KnownExpressionsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \KnownExpression.markedAt, order: .reverse) private var words: [KnownExpression]
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if words.isEmpty {
                ContentUnavailableView("No Marked Words", systemImage: "checkmark.circle",
                                       description: Text("Words marked as known while listening appear here."))
            } else {
                List {
                    ForEach(words) { item in Text(item.lemma) }
                        .onDelete(perform: unmark)
                }
            }
        }
        .navigationTitle("Known Words")
        .alert("Could Not Update Words", isPresented: Binding(get: { errorMessage != nil },
                                                               set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
    }

    private func unmark(at offsets: IndexSet) {
        for index in offsets { modelContext.delete(words[index]) }
        do { try modelContext.save() }
        catch {
            modelContext.rollback()
            errorMessage = error.localizedDescription
        }
    }
}

