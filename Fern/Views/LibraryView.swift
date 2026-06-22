import SwiftUI
import SwiftData

struct LibraryView: View {
    @Query(sort: \Entry.createdAt, order: .reverse) private var entries: [Entry]

    private var sections: [DaySection] { DayGrouping.sections(from: entries) }

    var body: some View {
        ZStack {
            PaperBackground()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(sections) { section in
                        Text(section.day.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                            .sectionLabel()
                            .padding(.top, 22).padding(.bottom, 6)
                        ForEach(section.entries) { entry in
                            EntryRow(entry: entry)
                            Rule()
                        }
                    }
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 40)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .navigationTitle("Library")
    }
}

#Preview {
    NavigationStack { LibraryView() }
        .modelContainer(SampleData.previewContainer())
}
