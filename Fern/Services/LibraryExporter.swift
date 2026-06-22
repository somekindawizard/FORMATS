import Foundation

/// Exports every entry as a Markdown file and zips them into a single archive
/// for sharing/backup. Zipping uses NSFileCoordinator's `.forUploading` option,
/// which produces a `.zip` of a directory without any third-party dependency.
///
/// `documents(from:)` reads the SwiftData models (call on the main actor);
/// `makeArchive(docs:)` only touches files, so it can run off the main thread.
enum LibraryExporter {

    struct Doc: Sendable {
        let name: String
        let markdown: String
    }

    /// Render entries to Sendable name/markdown pairs (main-actor safe).
    static func documents(from entries: [Entry]) -> [Doc] {
        var used = Set<String>()
        return entries.map { entry in
            Doc(name: filename(for: entry, taken: &used),
                markdown: MarkdownExporter.markdown(for: entry))
        }
    }

    /// Write the docs as `.md` files and zip them. No SwiftData access.
    static func makeArchive(docs: [Doc]) -> URL? {
        let fm = FileManager.default
        let folder = fm.temporaryDirectory.appendingPathComponent("Fern Export", isDirectory: true)
        try? fm.removeItem(at: folder)
        guard (try? fm.createDirectory(at: folder, withIntermediateDirectories: true)) != nil else {
            return nil
        }

        for doc in docs {
            let url = folder.appendingPathComponent(doc.name).appendingPathExtension("md")
            try? doc.markdown.data(using: .utf8)?.write(to: url)
        }

        var archiveURL: URL?
        var coordError: NSError?
        NSFileCoordinator().coordinate(readingItemAt: folder, options: .forUploading, error: &coordError) { zippedURL in
            let dest = fm.temporaryDirectory.appendingPathComponent("Fern Export.zip")
            try? fm.removeItem(at: dest)
            if (try? fm.copyItem(at: zippedURL, to: dest)) != nil {
                archiveURL = dest
            }
        }
        return archiveURL
    }

    private static func filename(for entry: Entry, taken: inout Set<String>) -> String {
        let date = entry.createdAt.formatted(.iso8601.year().month().day().dateSeparator(.dash))
        let titlePart = entry.displayTitle
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .prefix(40)
        var name = "\(date) \(titlePart)".trimmingCharacters(in: .whitespaces)
        let original = name
        var n = 2
        while taken.contains(name) { name = "\(original) (\(n))"; n += 1 }
        taken.insert(name)
        return name
    }
}
