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
                if entry.isPinned {
                    Image(systemName: "star.fill")
                        .font(.system(size: 9)).foregroundStyle(Paper.accent)
                }
                if entry.isLocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 9)).foregroundStyle(Paper.inkFaint)
                }
                if let mood = entry.mood {
                    Text("· \(mood.label.lowercased())")
                        .font(.label).foregroundStyle(Paper.accent)
                }
                if let symbol = entry.weatherSymbol, let temp = entry.weatherTempC {
                    HStack(spacing: 2) {
                        Image(systemName: symbol).font(.system(size: 9))
                        Text("\(Int(temp.rounded()))°").font(.label)
                    }
                    .foregroundStyle(Paper.inkFaint)
                }
                if entry.collection == .piece && !entry.isFinished {
                    Text("· draft").font(.label).foregroundStyle(Paper.inkFaint)
                }
                if let nb = entry.notebook {
                    Text("· \(nb)").font(.label).foregroundStyle(Paper.inkFaint)
                }
            }
            Text(entry.displayTitle).font(.headlineSerif).foregroundStyle(Paper.ink)
            if entry.isLocked {
                Text("Locked").font(.calloutSerif).italic().foregroundStyle(Paper.inkFaint)
            } else {
                if !entry.body.isEmpty {
                    Text(entry.body).font(.calloutSerif).foregroundStyle(Paper.inkSoft)
                        .lineLimit(2)
                }
                if !entry.tagNames.isEmpty {
                    Text(entry.tagNames.map { "#\($0)" }.joined(separator: "  "))
                        .font(.label).foregroundStyle(Paper.inkFaint)
                }
            }
        }
        .padding(.vertical, 6)
    }
}
