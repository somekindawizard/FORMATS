import Foundation

/// Parses a Markdown/text file into a Redwood document's (title, body).
/// Understands Fern's export shape — an optional `---` YAML front-matter block,
/// then a `# Title` heading, then the body — and falls back to the filename
/// when there's no leading heading.
enum RWImport {

    static func parse(text raw: String, filename: String) -> (title: String, body: String) {
        var text = raw.replacingOccurrences(of: "\r\n", with: "\n")

        // Strip a leading YAML front-matter block (Fern writes one).
        if text.hasPrefix("---\n"), let end = text.range(of: "\n---\n", range: text.index(text.startIndex, offsetBy: 3)..<text.endIndex) {
            text = String(text[end.upperBound...])
        }
        text = text.drop(while: \.isNewline).description

        // A leading "# Heading" becomes the title; the rest is the body.
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        if let first = lines.first, first.hasPrefix("# ") {
            let title = first.dropFirst(2).trimmingCharacters(in: .whitespaces)
            let body = lines.dropFirst().joined(separator: "\n").drop(while: \.isNewline)
            return (title, String(body))
        }

        // No heading — name it after the file.
        let name = (filename as NSString).deletingPathExtension
        return (name, text)
    }
}
