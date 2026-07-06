import SwiftUI
import SwiftData

struct SearchView: View {
    @Environment(\.modelContext) private var context
    @State private var query = ""
    @State private var results: [Entry] = []
    @State private var searchTask: Task<Void, Never>?

    /// Debounced, store-scoped search. The old version held every entry live
    /// and lowercased every title+body+inkText per typed character — seconds
    /// of main-thread work per keystroke on a large journal. A `#Predicate`
    /// fetch pushes the matching into SQLite. Queries starting with `#`
    /// search tags (a value array SwiftData can't predicate over).
    private func runSearch(_ raw: String) {
        searchTask?.cancel()
        let q = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { results = []; return }
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            if q.hasPrefix("#") {
                let tag = String(q.dropFirst()).lowercased()
                let all = (try? context.fetch(FetchDescriptor<Entry>(
                    sortBy: [SortDescriptor(\Entry.createdAt, order: .reverse)]))) ?? []
                results = all.filter { $0.tagNames.contains { $0.contains(tag) } }
            } else {
                let predicate = #Predicate<Entry> { e in
                    e.title.localizedStandardContains(q)
                    || e.body.localizedStandardContains(q)
                    || e.inkText.localizedStandardContains(q)
                }
                var d = FetchDescriptor<Entry>(predicate: predicate,
                                               sortBy: [SortDescriptor(\Entry.createdAt, order: .reverse)])
                d.fetchLimit = 200
                results = (try? context.fetch(d)) ?? []
            }
        }
    }

    var body: some View {
        ZStack {
            PaperBackground()
            Group {
                if query.trimmingCharacters(in: .whitespaces).isEmpty {
                    hint("Search your entries")
                } else if results.isEmpty {
                    hint("Nothing matches “\(query)”")
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(results) { entry in
                                NavigationLink(value: entry) { EntryRow(entry: entry) }
                                    .buttonStyle(.plain)
                                Rule()
                            }
                        }
                        .padding(.horizontal, 22)
                        .padding(.bottom, 40)
                    }
                }
            }
        }
        .navigationTitle("Search")
        .searchable(text: $query, prompt: "Title, text, or #tag")
        .onChange(of: query) { _, q in runSearch(q) }
        .navigationDestination(for: Entry.self) { entry in
            EntryEditorView(entry: entry)
        }
    }

    private func hint(_ text: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "magnifyingglass").font(.title2).foregroundStyle(Paper.inkFaint)
            Text(text).font(.bodySerif).foregroundStyle(Paper.inkSoft)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 40)
    }
}
