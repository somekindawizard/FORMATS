import SwiftUI

/// Renders Fern's Markdown into a clean, styled `AttributedString` with the
/// syntax marks **removed** — for read-only surfaces (share cards, reading mode)
/// where raw `**` / `#` / `-` should never show. The live editor keeps its own
/// in-place styler that leaves the marks visible.
enum MarkdownRender {

    struct Style {
        var body: Font
        var heading: (Int) -> Font        // by level 1...6
        var mono: Font
        var ink: Color
        var soft: Color
        var accent: Color
    }

    /// All Markdown syntax stripped to readable plain text — for list previews
    /// and search snippets where styling isn't wanted, just clean words.
    static func plainText(_ source: String) -> String {
        var s = source
        let blockMarkers = [
            #"(?m)^[ \t]{0,3}#{1,6}[ \t]+"#,        // headings
            #"(?m)^[ \t]{0,3}>[ \t]?"#,             // block quotes
            #"(?m)^[ \t]{0,3}- \[[ xX]\][ \t]+"#,   // task boxes
            #"(?m)^[ \t]{0,3}[-*+][ \t]+"#,         // bullets
            #"(?m)^[ \t]{0,3}\d+\.[ \t]+"#,         // numbered
            #"(?m)^\s*(-{3,}|\*{3,}|_{3,})\s*$"#     // rules
        ]
        for p in blockMarkers {
            s = s.replacingOccurrences(of: p, with: "", options: .regularExpression)
        }
        let inline = [
            (#"!\[[^\]]*\]\(fern://[^)]+\)"#, ""),   // inline photo tokens
            (#"\[\[([^\]]+)\]\]"#, "$1"),            // wiki-links → title
            (#"\[([^\]]+)\]\([^)]+\)"#, "$1"),       // links → label
            (#"\*\*(.+?)\*\*"#, "$1"),
            (#"(?<!\*)\*(?!\*)([^*\n]+)\*(?!\*)"#, "$1"),
            (#"~~(.+?)~~"#, "$1"),
            (#"==(.+?)=="#, "$1"),
            (#"`([^`\n]+)`"#, "$1")
        ]
        for (p, r) in inline {
            s = s.replacingOccurrences(of: p, with: r, options: .regularExpression)
        }
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Data detectors — turn bare URLs and phone numbers into tappable links,
    /// leaving any Markdown links already present untouched. Reading mode only.
    static func autolink(_ attr: AttributedString, accent: Color) -> AttributedString {
        var out = attr
        let plain = String(attr.characters)
        guard !plain.isEmpty,
              let detector = try? NSDataDetector(
                types: NSTextCheckingResult.CheckingType([.link, .phoneNumber]).rawValue)
        else { return attr }
        let matches = detector.matches(in: plain, range: NSRange(location: 0, length: (plain as NSString).length))
        for m in matches {
            guard let swiftRange = Range(m.range, in: plain) else { continue }
            let lower = plain.distance(from: plain.startIndex, to: swiftRange.lowerBound)
            let upper = plain.distance(from: plain.startIndex, to: swiftRange.upperBound)
            let start = out.index(out.startIndex, offsetByCharacters: lower)
            let end = out.index(out.startIndex, offsetByCharacters: upper)
            let range = start..<end
            if out[range].link != nil { continue }   // don't stomp Markdown links
            var url: URL?
            if m.resultType == .link { url = m.url }
            else if m.resultType == .phoneNumber, let phone = m.phoneNumber {
                url = URL(string: "tel:\(phone.filter { !$0.isWhitespace && $0 != "-" && $0 != "(" && $0 != ")" })")
            }
            if let url {
                out[range].link = url
                out[range].foregroundColor = accent
                out[range].underlineStyle = .single
            }
        }
        return out
    }

    /// A styled string for the whole document, blocks separated by newlines.
    static func styled(_ source: String, _ s: Style) -> AttributedString {
        var out = AttributedString("")
        let lines = source.components(separatedBy: "\n")
        for (i, raw) in lines.enumerated() {
            out += line(raw, s)
            if i < lines.count - 1 { out += AttributedString("\n") }
        }
        return out
    }

    /// One line: strip a leading block marker, then render inline emphasis.
    private static func line(_ raw: String, _ s: Style) -> AttributedString {
        // Horizontal rule (--- *** ___)
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        if trimmed.count >= 3, Set(trimmed).count == 1, "-*_".contains(trimmed.first!) {
            var rule = AttributedString(String(repeating: "\u{2500}", count: 28))
            rule.foregroundColor = s.soft.opacity(0.45)
            rule.font = s.body
            return rule
        }
        // Heading
        if let m = raw.range(of: #"^#{1,6}[ \t]+"#, options: .regularExpression) {
            let level = raw[raw.startIndex..<m.upperBound].prefix { $0 == "#" }.count
            return inline(String(raw[m.upperBound...]), font: s.heading(level), s, color: s.ink)
        }
        // Task list  - [ ] / - [x]
        if let m = raw.range(of: #"^[ \t]{0,3}- \[[ xX]\][ \t]+"#, options: .regularExpression) {
            let done = raw.range(of: #"\[[xX]\]"#, options: .regularExpression) != nil
            var box = AttributedString(done ? "\u{2611}  " : "\u{2610}  ")   // ☑ / ☐
            box.foregroundColor = done ? s.accent : s.soft
            box.font = s.body
            var rest = inline(String(raw[m.upperBound...]), font: s.body, s, color: done ? s.soft : s.ink)
            if done { rest.strikethroughStyle = .single }
            return box + rest
        }
        // Block quote — flush italic, no bar or indent.
        if let m = raw.range(of: #"^>[ \t]?"#, options: .regularExpression) {
            return inline(String(raw[m.upperBound...]), font: s.body.italic(), s, color: s.soft)
        }
        // Bulleted list
        if let m = raw.range(of: #"^[ \t]{0,3}[-*+][ \t]+"#, options: .regularExpression) {
            var dot = AttributedString("\u{2022}  ")
            dot.foregroundColor = s.accent
            dot.font = s.body
            return dot + inline(String(raw[m.upperBound...]), font: s.body, s, color: s.ink)
        }
        // Numbered list — keep the author's number
        if let m = raw.range(of: #"^[ \t]{0,3}(\d+)\.[ \t]+"#, options: .regularExpression) {
            var num = AttributedString(String(raw[raw.startIndex..<m.upperBound]).trimmingCharacters(in: .whitespaces) + "  ")
            num.foregroundColor = s.accent
            num.font = s.body
            return num + inline(String(raw[m.upperBound...]), font: s.body, s, color: s.ink)
        }
        return inline(raw, font: s.body, s, color: s.ink)
    }

    /// Inline emphasis, scanned by hand so `==highlight==` works alongside the
    /// standard `**bold**`, `*italic*`, `~~strike~~`, `` `code` ``.
    private static func inline(_ text: String, font: Font, _ s: Style, color: Color) -> AttributedString {
        let delimiters = ["**", "~~", "==", "`", "*"]   // longest first
        var out = AttributedString()
        let chars = Array(text)
        var i = 0
        var plain = ""
        func flush() {
            guard !plain.isEmpty else { return }
            var a = AttributedString(plain); a.font = font; a.foregroundColor = color
            out += a; plain = ""
        }
        func starts(_ d: String, at idx: Int) -> Bool {
            let dc = Array(d)
            guard idx + dc.count <= chars.count else { return false }
            return Array(chars[idx..<idx + dc.count]) == dc
        }
        func indexOf(_ ch: Character, from: Int) -> Int? {
            var k = from
            while k < chars.count { if chars[k] == ch { return k }; k += 1 }
            return nil
        }
        func indexOfString(_ s: String, from: Int) -> Int? {
            var k = from
            while k < chars.count { if starts(s, at: k) { return k }; k += 1 }
            return nil
        }
        while i < chars.count {
            // Wiki-link: [[Note title]] → tappable link to that note.
            if starts("[[", at: i), let close = indexOfString("]]", from: i + 2) {
                flush()
                let title = String(chars[(i + 2)..<close])
                var link = AttributedString(title)
                link.font = font
                link.foregroundColor = s.accent
                if let encoded = title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                   let url = URL(string: "fern://note/\(encoded)") {
                    link.link = url
                }
                out += link
                i = close + 2
                continue
            }
            // Link: [label](url) — but not an image ![..](..)
            if chars[i] == "[", !(i > 0 && chars[i - 1] == "!"),
               let bracket = indexOf("]", from: i + 1),
               bracket + 1 < chars.count, chars[bracket + 1] == "(",
               let paren = indexOf(")", from: bracket + 2) {
                flush()
                let label = String(chars[(i + 1)..<bracket])
                let urlString = String(chars[(bracket + 2)..<paren])
                var link = AttributedString(label)
                link.font = font
                link.foregroundColor = s.accent
                link.underlineStyle = .single
                if let url = URL(string: urlString) { link.link = url }
                out += link
                i = paren + 1
                continue
            }
            if let d = delimiters.first(where: { starts($0, at: i) }) {
                let open = i + d.count
                var j = open
                var close = -1
                while j < chars.count { if starts(d, at: j) { close = j; break }; j += 1 }
                if close >= 0 {
                    flush()
                    var inner = AttributedString(String(chars[open..<close]))
                    inner.font = font; inner.foregroundColor = color
                    switch d {
                    case "**": inner.font = font.bold()
                    case "*":  inner.font = font.italic()
                    case "~~": inner.strikethroughStyle = .single
                    case "==": inner.backgroundColor = s.accent.opacity(0.18)
                    case "`":  inner.font = s.mono
                    default: break
                    }
                    out += inner
                    i = close + d.count
                    continue
                }
            }
            plain.append(chars[i]); i += 1
        }
        flush()
        return out
    }
}
