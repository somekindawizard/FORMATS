import SwiftUI
import SwiftData

/// Browse favorited prompts and recently-shown ones; start writing from any.
struct SavedPromptsView: View {
    @Environment(\.modelContext) private var context
    @Environment(PromptStore.self) private var store
    @State private var draft: Entry?

    private var historyPrompts: [Prompt] {
        // Resolve recent texts back to known prompts (skip any no longer present).
        let byText = Dictionary(PromptLibrary.all.map { ($0.text, $0) }, uniquingKeysWith: { a, _ in a })
        return store.history.compactMap { byText[$0] }
    }

    var body: some View {
        ZStack {
            PaperBackground()
            List {
                if !store.favoritePrompts.isEmpty {
                    Section {
                        ForEach(store.favoritePrompts) { row($0) }
                    } header: { Text("Favorites").sectionLabel() }
                }
                if !historyPrompts.isEmpty {
                    Section {
                        ForEach(historyPrompts) { row($0) }
                    } header: { Text("Recently shown").sectionLabel() }
                }
                if store.favoritePrompts.isEmpty && historyPrompts.isEmpty {
                    Text("Favorite a prompt with the heart on Today, and it'll live here.")
                        .font(.calloutSerif).foregroundStyle(Paper.inkSoft)
                        .listRowBackground(Color.clear)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .textCase(nil)
        }
        .navigationTitle("Saved prompts")
        .navigationDestination(item: $draft) { entry in
            EntryEditorView(entry: entry)
        }
    }

    private func row(_ prompt: Prompt) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(prompt.text).font(.bodySerif).foregroundStyle(Paper.ink)
            HStack(spacing: 16) {
                Text(prompt.theme.title).font(.label).foregroundStyle(Paper.inkFaint)
                Button("Write") { write(prompt) }
                    .font(.calloutSerif).foregroundStyle(Paper.accent)
                Spacer()
                Button {
                    store.toggleFavorite(prompt.text)
                } label: {
                    Image(systemName: store.isFavorite(prompt.text) ? "heart.fill" : "heart")
                        .font(.system(size: 13)).foregroundStyle(Paper.accent)
                }
            }
        }
        .padding(.vertical, 6)
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 2, leading: 22, bottom: 2, trailing: 22))
    }

    private func write(_ prompt: Prompt) {
        let collection: Collection = prompt.kind == .journal ? .journal : .piece
        let entry = Entry(title: "", body: "", collection: collection)
        entry.prompt = prompt.text
        entry.tagNames = [prompt.theme.rawValue]
        context.insert(entry)
        draft = entry
    }
}
