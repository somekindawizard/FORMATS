import UIKit

/// Assembles a project's binder into one manuscript — combined Markdown, and a
/// paginated, print-ready PDF.
enum RedwoodCompiler {

    struct Options {
        var includeTitles = true      // document titles as headings
        var foldersAsHeadings = true  // folder names as part/section headings
    }

    /// Documents (and folders) of a project in binder reading order.
    private static func ordered(_ all: [RWDocument], parent: UUID?, depth: Int) -> [(RWDocument, Int)] {
        var out: [(RWDocument, Int)] = []
        for n in all.filter({ $0.parentID == parent }).sorted(by: { $0.order < $1.order }) {
            out.append((n, depth))
            if n.isFolder { out += ordered(all, parent: n.id, depth: depth + 1) }
        }
        return out
    }

    /// The whole manuscript as one Markdown string.
    static func markdown(project: RWProject, docs: [RWDocument], options: Options = Options()) -> String {
        var lines: [String] = []
        for (node, depth) in ordered(docs, parent: nil, depth: 0) {
            if node.isFolder {
                if options.foldersAsHeadings {
                    let hashes = String(repeating: "#", count: min(depth + 1, 3))
                    lines.append("\(hashes) \(node.displayTitle)")
                    lines.append("")
                }
            } else {
                if options.includeTitles && !node.title.trimmingCharacters(in: .whitespaces).isEmpty {
                    let hashes = String(repeating: "#", count: min(depth + 2, 4))
                    lines.append("\(hashes) \(node.title)")
                    lines.append("")
                }
                let body = node.body.trimmingCharacters(in: .whitespacesAndNewlines)
                if !body.isEmpty { lines.append(body); lines.append("") }
            }
        }
        return lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines) + "\n"
    }

    static func wordCount(_ markdown: String) -> Int {
        markdown.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
    }

    // MARK: PDF

    /// A book-style attributed rendering (Georgia serif; headings scaled).
    /// Inline emphasis is flattened for the PDF; the Markdown export keeps it.
    private static func attributed(_ markdown: String) -> NSAttributedString {
        let out = NSMutableAttributedString()
        let body = UIFont(name: "Georgia", size: 12) ?? .systemFont(ofSize: 12)
        let bodyPara = NSMutableParagraphStyle()
        bodyPara.lineSpacing = 3
        bodyPara.paragraphSpacing = 8
        bodyPara.firstLineHeadIndent = 18
        bodyPara.alignment = .justified

        func headingFont(_ level: Int) -> UIFont {
            let size: CGFloat = level <= 1 ? 22 : (level == 2 ? 17 : 14)
            let base = UIFont(name: "Georgia-Bold", size: size) ?? .boldSystemFont(ofSize: size)
            return base
        }
        let headPara = NSMutableParagraphStyle()
        headPara.paragraphSpacingBefore = 14
        headPara.paragraphSpacing = 6

        for rawLine in markdown.components(separatedBy: "\n") {
            let line = rawLine
            if let m = line.range(of: #"^#{1,6}[ \t]+"#, options: .regularExpression) {
                let level = line[line.startIndex..<m.upperBound].prefix { $0 == "#" }.count
                let text = MarkdownRender.plainText(String(line[m.upperBound...]))
                out.append(NSAttributedString(string: text + "\n", attributes: [
                    .font: headingFont(level),
                    .foregroundColor: UIColor.label,
                    .paragraphStyle: headPara
                ]))
            } else {
                let text = MarkdownRender.plainText(line)
                out.append(NSAttributedString(string: text + "\n", attributes: [
                    .font: body,
                    .foregroundColor: UIColor.label,
                    .paragraphStyle: bodyPara
                ]))
            }
        }
        return out
    }

    /// Render a compiled Markdown string to a multi-page US-Letter PDF.
    /// Takes a plain `String` (Sendable) so it can run off the main actor.
    static func pdf(markdown: String) -> Data {
        let text = attributed(markdown)
        let page = CGRect(x: 0, y: 0, width: 612, height: 792)          // US Letter @72dpi
        let margin = UIEdgeInsets(top: 64, left: 60, bottom: 64, right: 60)
        let printable = page.inset(by: margin)

        let data = NSMutableData()
        UIGraphicsBeginPDFContextToData(data, page, nil)
        let framesetter = CTFramesetterCreateWithAttributedString(text)
        var cursor = 0

        while cursor < text.length {
            UIGraphicsBeginPDFPage()
            guard let ctx = UIGraphicsGetCurrentContext() else { break }
            ctx.textMatrix = .identity
            ctx.translateBy(x: 0, y: page.height)
            ctx.scaleBy(x: 1, y: -1)

            let flippedRect = CGRect(x: printable.minX,
                                     y: page.height - printable.maxY,
                                     width: printable.width,
                                     height: printable.height)
            let path = CGPath(rect: flippedRect, transform: nil)
            let frame = CTFramesetterCreateFrame(framesetter, CFRange(location: cursor, length: 0), path, nil)
            CTFrameDraw(frame, ctx)
            let visible = CTFrameGetVisibleStringRange(frame)
            if visible.length == 0 { break }        // avoid an infinite loop
            cursor += visible.length
        }
        UIGraphicsEndPDFContext()
        return data as Data
    }

    // MARK: file helpers

    static func writeTemp(_ contents: String, name: String) -> URL? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        do { try contents.write(to: url, atomically: true, encoding: .utf8); return url }
        catch { return nil }
    }

    static func writeTemp(_ data: Data, name: String) -> URL? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        do { try data.write(to: url); return url } catch { return nil }
    }

    /// A filesystem-safe base name from the project title.
    static func safeName(_ title: String) -> String {
        let cleaned = title.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "/", with: "-")
        return cleaned.isEmpty ? "Manuscript" : cleaned
    }
}
