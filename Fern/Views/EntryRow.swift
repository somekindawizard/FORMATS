import SwiftUI

struct EntryRow: View {
    let entry: Entry

    private var dateLabel: String {
        entry.createdAt.formatted(.dateTime.weekday(.abbreviated)).uppercased()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(dateLabel).sectionLabel()
                if entry.collection == .piece {
                    Text("· \(entry.collection.title.lowercased())")
                        .font(.label).foregroundStyle(Paper.inkFaint)
                }
                if entry.isPinned {
                    Image(systemName: "star.fill")
                        .font(.system(size: 9)).foregroundStyle(Paper.accent)
                }
                if let mood = entry.mood {
                    Text("· \(mood.label.lowercased())")
                        .font(.label).foregroundStyle(Paper.accent)
                }
            }
            Text(entry.title).font(.headlineSerif).foregroundStyle(Paper.ink)
            if !entry.body.isEmpty {
                Text(entry.body).font(.calloutSerif).foregroundStyle(Paper.inkSoft)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 6)
    }
}
