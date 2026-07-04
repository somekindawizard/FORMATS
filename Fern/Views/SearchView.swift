import SwiftUI
import SwiftData

struct SearchView: View {
    @Query(sort: \Entry.createdAt, order: .reverse) private var entries: [Entry]
    @State private var query = ""

    private var results: [Entry] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return [] }
        return entries.filter { e in
            e.title.lowercased().contains(q)
            || e.body.lowercased().contains(q)
            || e.inkText.lowercased().contains(q)
            || e.tagNames.contains { $0.lowercased().contains(q) }
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
