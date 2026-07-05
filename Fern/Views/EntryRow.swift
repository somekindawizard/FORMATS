import SwiftUI

struct EntryRow: View {
    let entry: Entry

    private var dateLabel: String {
        entry.createdAt.formatted(.dateTime.weekday(.abbreviated)).uppercased()
    }

    private var cover: UIImage? {
        guard !entry.isLocked, !entry.coverPhotoName.isEmpty else { return nil }
        return PhotoStore.load(entry.coverPhotoName)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            content
            if let cover {
                Image(uiImage: cover)
                    .resizable().scaledToFill()
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Paper.line, lineWidth: 1))
            }
        }
        .padding(.vertical, 6)
    }

    private var content: some View {
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
                    Text(MarkdownRender.plainText(entry.body))
                        .font(.calloutSerif).foregroundStyle(Paper.inkSoft)
                        .lineLimit(2)
                }
                if !entry.tagNames.isEmpty {
                    Text(entry.tagNames.map { "#\($0)" }.joined(separator: "  "))
                        .font(.label).foregroundStyle(Paper.inkFaint)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
