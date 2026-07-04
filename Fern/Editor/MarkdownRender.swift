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
        // Block quote
        if let m = raw.range(of: #"^>[ \t]?"#, options: .regularExpression) {
            let q = inline(String(raw[m.upperBound...]), font: s.body.italic(), s, color: s.soft)
            var bar = AttributedString("\u{2503} ")   // heavy vertical bar
            bar.foregroundColor = s.accent
            bar.font = s.body
            return bar + q
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
        while i < chars.count {
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
