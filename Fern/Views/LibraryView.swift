import SwiftUI
import SwiftData

struct LibraryView: View {
    @Query(sort: \Entry.createdAt, order: .reverse) private var entries: [Entry]
    @State private var selectedTag: String?

    private var allTags: [String] {
        Array(Set(entries.flatMap(\.tagNames))).sorted()
    }

    private var filtered: [Entry] {
        guard let tag = selectedTag else { return entries }
        return entries.filter { $0.tagNames.contains(tag) }
    }

    private var pinned: [Entry] { filtered.filter(\.isPinned) }
    private var sections: [DaySection] {
        DayGrouping.sections(from: filtered.filter { !$0.isPinned })
    }

    var body: some View {
        ZStack {
            PaperBackground()
            if entries.isEmpty {
                EmptyStateFern()
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        if !allTags.isEmpty { tagBar }

                        if !pinned.isEmpty {
                            Text("Pinned").sectionLabel()
                                .padding(.top, 18).padding(.bottom, 6)
                            ForEach(pinned) { entry in
                                row(entry); Rule()
                            }
                        }

                        ForEach(sections) { section in
                            Text(section.day.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                                .sectionLabel()
                                .padding(.top, 22).padding(.bottom, 6)
                            ForEach(section.entries) { entry in
                                row(entry); Rule()
                            }
                        }
                    }
                    .padding(.horizontal, 22)
                    .padding(.bottom, 40)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .navigationTitle("Library")
        .navigationDestination(for: Entry.self) { entry in
            EntryEditorView(entry: entry)
        }
    }

    private func row(_ entry: Entry) -> some View {
        NavigationLink(value: entry) { EntryRow(entry: entry) }
            .buttonStyle(.plain)
    }

    private var tagBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                tagChip("All", active: selectedTag == nil) { selectedTag = nil }
                ForEach(allTags, id: \.self) { tag in
                    tagChip("#\(tag)", active: selectedTag == tag) {
                        selectedTag = (selectedTag == tag) ? nil : tag
                    }
                }
            }
            .padding(.vertical, 14)
        }
    }

    private func tagChip(_ label: String, active: Bool, _ tap: @escaping () -> Void) -> some View {
        Button(action: tap) {
            Text(label)
                .font(.calloutSerif)
                .foregroundStyle(active ? Paper.bg : Paper.inkSoft)
                .padding(.vertical, 6).padding(.horizontal, 12)
                .background(
                    Capsule().fill(active ? Paper.ink : Paper.raised)
                        .overlay(Capsule().stroke(Paper.line, lineWidth: active ? 0 : 1))
                )
        }
        .buttonStyle(.plain)
    }
}

private struct EmptyStateFern: View {
    private let fern = BarnsleyFern(seed: 4_211, count: 18_000)
    var body: some View {
        VStack(spacing: 12) {
            BarnsleyFernView(fern: fern)
                .frame(width: 220, height: 300)
            Text("Begin a new entry from Today.")
                .font(.calloutSerif)
                .foregroundStyle(Paper.inkSoft)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    NavigationStack { LibraryView() }
        .modelContainer(SampleData.previewContainer())
}
