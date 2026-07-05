import SwiftUI
import SwiftData

struct LibraryView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Entry.createdAt, order: .reverse) private var entries: [Entry]
    @State private var selectedTag: String?
    @State private var selectedNotebook: String?
    @State private var draftsOnly = false

    private var allTags: [String] {
        Array(Set(entries.flatMap(\.tagNames))).sorted()
    }
    private var notebooks: [String] {
        Array(Set(entries.compactMap(\.notebook))).sorted()
    }

    private var filtered: [Entry] {
        entries.filter { e in
            (selectedTag == nil || e.tagNames.contains(selectedTag!))
            && (selectedNotebook == nil || e.notebook == selectedNotebook)
            && (!draftsOnly || (e.collection == .piece && !e.isFinished))
        }
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
                VStack(spacing: 0) {
                    if !allTags.isEmpty {
                        tagBar.padding(.horizontal, 22)
                    }
                    List {
                        if !pinned.isEmpty {
                            Section {
                                ForEach(pinned) { row($0) }
                            } header: {
                                Text("Pinned").sectionLabel()
                            }
                        }
                        ForEach(sections) { section in
                            Section {
                                ForEach(section.entries) { row($0) }
                            } header: {
                                Text(section.day.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                                    .sectionLabel()
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .textCase(nil)
                }
            }
        }
        .navigationTitle("Library")
        .toolbar {
            if !notebooks.isEmpty || draftsOnly || selectedNotebook != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("All notebooks") { selectedNotebook = nil }
                        ForEach(notebooks, id: \.self) { nb in
                            Button { selectedNotebook = nb } label: {
                                if selectedNotebook == nb { Label(nb, systemImage: "checkmark") }
                                else { Text(nb) }
                            }
                        }
                        Divider()
                        Button { draftsOnly.toggle() } label: {
                            if draftsOnly { Label("Drafts only", systemImage: "checkmark") }
                            else { Text("Drafts only") }
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .foregroundStyle(Paper.accent)
                    }
                }
            }
        }
        .navigationDestination(for: Entry.self) { entry in
            EntryEditorView(entry: entry)
        }
    }

    private func row(_ entry: Entry) -> some View {
        NavigationLink(value: entry) { EntryRow(entry: entry) }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 2, leading: 22, bottom: 2, trailing: 22))
            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                Button { togglePin(entry) } label: {
                    Label(entry.isPinned ? "Unpin" : "Pin",
                          systemImage: entry.isPinned ? "star.slash.fill" : "star.fill")
                }
                .tint(Paper.accent)
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button(role: .destructive) { delete(entry) } label: {
                    Label("Delete", systemImage: "trash")
                }
                Button { toggleLock(entry) } label: {
                    Label(entry.isLocked ? "Unlock" : "Lock",
                          systemImage: entry.isLocked ? "lock.open.fill" : "lock.fill")
                }
                .tint(Paper.inkSoft)
            }
    }

    private func togglePin(_ entry: Entry) {
        Haptics.tap()
        entry.isPinned.toggle()
        try? context.save()
    }

    private func toggleLock(_ entry: Entry) {
        Haptics.tap()
        entry.isLocked.toggle()
        try? context.save()
    }

    private func delete(_ entry: Entry) {
        Haptics.tap(.medium)
        for name in entry.photoFileNames { PhotoStore.delete(name) }
        DrawingStore.delete(entry.id)
        SpotlightIndexer.deindex(id: entry.id)
        context.delete(entry)
        try? context.save()
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
