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
            // One page per pool — CoreText's per-page typesetting objects are
            // released promptly instead of piling up for the whole manuscript.
            let advanced: Int = autoreleasepool {
                UIGraphicsBeginPDFPage()
                guard let ctx = UIGraphicsGetCurrentContext() else { return 0 }
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
                return CTFrameGetVisibleStringRange(frame).length
            }
            if advanced == 0 { break }        // avoid an infinite loop
            cursor += advanced
        }
        UIGraphicsEndPDFContext()
        return data as Data
    }

    // MARK: EPUB

    /// A reflowable EPUB 3 of the manuscript — one chapter per document.
    static func epub(project: RWProject, docs: [RWDocument], options: Options = Options(),
                     author: String, modified: String) -> Data {
        let chapters = ordered(docs, parent: nil, depth: 0)
            .filter { !$0.0.isFolder }
            .map { $0.0 }
        let bookID = UUID().uuidString

        var zip = ZipWriter()
        // mimetype MUST be first and stored uncompressed.
        zip.add("mimetype", bytes: Array("application/epub+zip".utf8))
        zip.add("META-INF/container.xml", bytes: Array(containerXML.utf8))
        zip.add("OEBPS/style.css", bytes: Array(epubCSS.utf8))

        var manifest = #"    <item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav"/>\#n"#
        manifest += #"    <item id="css" href="style.css" media-type="text/css"/>\#n"#
        var spine = ""
        var navItems = ""

        for (i, doc) in chapters.enumerated() {
            let title = xmlEscape(doc.displayTitle)
            let file = "chap\(i).xhtml"
            let xhtml = """
            <?xml version="1.0" encoding="utf-8"?>
            <!DOCTYPE html>
            <html xmlns="http://www.w3.org/1999/xhtml">
            <head><title>\(title)</title><link rel="stylesheet" href="style.css" type="text/css"/></head>
            <body>
            <h1>\(title)</h1>
            \(xhtmlBody(doc.body))
            </body></html>
            """
            zip.add("OEBPS/\(file)", bytes: Array(xhtml.utf8))
            manifest += #"    <item id="c\#(i)" href="\#(file)" media-type="application/xhtml+xml"/>\#n"#
            spine += #"    <itemref idref="c\#(i)"/>\#n"#
            navItems += "      <li><a href=\"\(file)\">\(title)</a></li>\n"
        }

        let nav = """
        <?xml version="1.0" encoding="utf-8"?>
        <!DOCTYPE html>
        <html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops">
        <head><title>Contents</title><link rel="stylesheet" href="style.css" type="text/css"/></head>
        <body>
        <nav epub:type="toc" id="toc"><h1>Contents</h1>
        <ol>
        \(navItems)    </ol></nav>
        </body></html>
        """
        zip.add("OEBPS/nav.xhtml", bytes: Array(nav.utf8))

        let opf = """
        <?xml version="1.0" encoding="utf-8"?>
        <package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="bookid">
          <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
            <dc:identifier id="bookid">urn:uuid:\(bookID)</dc:identifier>
            <dc:title>\(xmlEscape(project.title))</dc:title>
            <dc:language>en</dc:language>
            <dc:creator>\(xmlEscape(author))</dc:creator>
            <meta property="dcterms:modified">\(modified)</meta>
          </metadata>
          <manifest>
        \(manifest)  </manifest>
          <spine>
        \(spine)  </spine>
        </package>
        """
        zip.add("OEBPS/content.opf", bytes: Array(opf.utf8))
        return zip.finalize()
    }

    private static let containerXML = """
    <?xml version="1.0" encoding="utf-8"?>
    <container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
      <rootfiles>
        <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
      </rootfiles>
    </container>
    """

    private static let epubCSS = """
    body { font-family: Georgia, 'Times New Roman', serif; line-height: 1.5; margin: 5% 7%; }
    h1 { font-size: 1.6em; margin: 1.4em 0 0.6em; }
    h2 { font-size: 1.3em; } h3 { font-size: 1.1em; }
    p { margin: 0 0 0.8em; text-indent: 1.2em; }
    blockquote { font-style: italic; margin: 1em 2em; }
    hr { border: 0; text-align: center; margin: 1.4em 0; }
    code { font-family: monospace; }
    """

    private static func xmlEscape(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
         .replacingOccurrences(of: "<", with: "&lt;")
         .replacingOccurrences(of: ">", with: "&gt;")
         // Escape quotes too — link URLs go into an href="…" attribute, and a
         // quote (or already-escaped &amp; from a query string) in the URL made
         // the XHTML malformed, so strict EPUB readers rejected the chapter.
         .replacingOccurrences(of: "\"", with: "&quot;")
         .replacingOccurrences(of: "'", with: "&#39;")
    }

    /// Markdown → a run of XHTML block elements (headings, paragraphs, lists,
    /// quotes, rules) with inline emphasis. Inline photos are dropped.
    private static func xhtmlBody(_ markdown: String) -> String {
        var html = ""
        var listOpen = false, listOrdered = false
        func closeList() {
            if listOpen { html += listOrdered ? "</ol>\n" : "</ul>\n"; listOpen = false }
        }
        for raw in markdown.components(separatedBy: "\n") {
            let t = raw.trimmingCharacters(in: .whitespaces)
            if t.isEmpty { closeList(); continue }
            if let m = t.range(of: #"^#{1,6}\s+"#, options: .regularExpression) {
                closeList()
                let level = min(t.prefix { $0 == "#" }.count, 6)
                html += "<h\(level)>\(inlineHTML(String(t[m.upperBound...])))</h\(level)>\n"
            } else if t.count >= 3, Set(t).count == 1, "-*_".contains(t.first!) {
                closeList(); html += "<hr/>\n"
            } else if t.hasPrefix(">") {
                closeList()
                let inner = String(t.dropFirst()).trimmingCharacters(in: .whitespaces)
                html += "<blockquote><p>\(inlineHTML(inner))</p></blockquote>\n"
            } else if let m = t.range(of: #"^[-*+]\s+"#, options: .regularExpression) {
                if !listOpen || listOrdered { closeList(); html += "<ul>\n"; listOpen = true; listOrdered = false }
                html += "<li>\(inlineHTML(String(t[m.upperBound...])))</li>\n"
            } else if let m = t.range(of: #"^\d+\.\s+"#, options: .regularExpression) {
                if !listOpen || !listOrdered { closeList(); html += "<ol>\n"; listOpen = true; listOrdered = true }
                html += "<li>\(inlineHTML(String(t[m.upperBound...])))</li>\n"
            } else {
                closeList(); html += "<p>\(inlineHTML(t))</p>\n"
            }
        }
        closeList()
        return html
    }

    private static func inlineHTML(_ text: String) -> String {
        var s = xmlEscape(text)
        func sub(_ pattern: String, _ repl: String) {
            s = s.replacingOccurrences(of: pattern, with: repl, options: .regularExpression)
        }
        sub(#"!\[[^\]]*\]\(fern://[^)]+\)"#, "")                 // drop inline photos
        sub(#"\[\[([^\]]+)\]\]"#, "$1")                          // wiki-links → text
        sub(#"\[([^\]]+)\]\(([^)]+)\)"#, "<a href=\"$2\">$1</a>")
        sub(#"\*\*(.+?)\*\*"#, "<strong>$1</strong>")
        sub(#"(?<!\*)\*(?!\*)([^*]+)\*(?!\*)"#, "<em>$1</em>")
        sub(#"~~(.+?)~~"#, "<del>$1</del>")
        sub(#"==(.+?)=="#, "<mark>$1</mark>")
        sub(#"`([^`]+)`"#, "<code>$1</code>")
        return s
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
