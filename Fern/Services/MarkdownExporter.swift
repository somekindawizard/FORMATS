import Foundation

/// Turns an entry into portable Markdown with a small YAML front matter
/// block — the kind of `.md` file any other editor can open.
enum MarkdownExporter {

    static func markdown(for entry: Entry) -> String {
        var out = "---\n"
        out += "date: \(ISO8601DateFormatter().string(from: entry.createdAt))\n"
        out += "collection: \(entry.collection.rawValue)\n"
        if let mood = entry.mood { out += "mood: \(mood.rawValue)\n" }
        if let place = entry.placeName { out += "place: \(place)\n" }
        if !entry.tagNames.isEmpty {
            out += "tags: [\(entry.tagNames.joined(separator: ", "))]\n"
        }
        out += "---\n\n"

        let title = entry.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !title.isEmpty { out += "# \(title)\n\n" }
        out += entry.body
        if !entry.body.hasSuffix("\n") { out += "\n" }
        return out
    }
}
