import SwiftUI
import SwiftData

struct LibraryView: View {
    @Query(sort: \Entry.createdAt, order: .reverse) private var entries: [Entry]

    private var sections: [DaySection] { DayGrouping.sections(from: entries) }

    var body: some View {
        ZStack {
            PaperBackground()
            if entries.isEmpty {
                EmptyStateFern()
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(sections) { section in
                            Text(section.day.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                                .sectionLabel()
                                .padding(.top, 22).padding(.bottom, 6)
                            ForEach(section.entries) { entry in
                                NavigationLink(value: entry) {
                                    EntryRow(entry: entry)
                                }
                                .buttonStyle(.plain)
                                Rule()
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
}

private struct EmptyStateFern: View {
    // Generated once per view life — cheap, deterministic.
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
