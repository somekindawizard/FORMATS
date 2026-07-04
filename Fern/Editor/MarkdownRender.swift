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
        // Heading
        if let m = raw.range(of: #"^#{1,6}[ \t]+"#, options: .regularExpression) {
            let level = raw[raw.startIndex..<m.upperBound].prefix { $0 == "#" }.count
            return inline(String(raw[m.upperBound...]), font: s.heading(level), s, color: s.ink)
        }
        // Block quote
        if let m = raw.range(of: #"^>[ \t]?"#, options: .regularExpression) {
            var q = inline(String(raw[m.upperBound...]), font: s.body.italic(), s, color: s.soft)
            var bar = AttributedString("\u{2503} ")   // heavy vertical bar
            bar.foregroundColor = s.accent
            bar.font = s.body
            return bar + q
        }
        // Bulleted list
        if let m = raw.range(of: #"^[-*+][ \t]+"#, options: .regularExpression) {
            var dot = AttributedString("\u{2022}  ")
            dot.foregroundColor = s.accent
            dot.font = s.body
            return dot + inline(String(raw[m.upperBound...]), font: s.body, s, color: s.ink)
        }
        // Numbered list — keep the author's number
        if let m = raw.range(of: #"^(\d+)\.[ \t]+"#, options: .regularExpression) {
            var num = AttributedString(String(raw[raw.startIndex..<m.upperBound]).trimmingCharacters(in: .whitespaces) + "  ")
            num.foregroundColor = s.accent
            num.font = s.body
            return num + inline(String(raw[m.upperBound...]), font: s.body, s, color: s.ink)
        }
        return inline(raw, font: s.body, s, color: s.ink)
    }

    /// Inline emphasis via Foundation's parser (removes `**`, `*`, `` ` ``, `~~`),
    /// then map the presentation intents onto Fern's fonts.
    private static func inline(_ text: String, font: Font, _ s: Style, color: Color) -> AttributedString {
        var a: AttributedString
        if let parsed = try? AttributedString(
            markdown: text,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace,
                           failurePolicy: .returnPartiallyParsedIfPossible)) {
            a = parsed
        } else {
            a = AttributedString(text)
        }
        a.font = font
        a.foregroundColor = color
        for run in a.runs {
            guard let intent = run.inlinePresentationIntent else { continue }
            if intent.contains(.code) {
                a[run.range].font = s.mono
            } else if intent.contains(.stronglyEmphasized) && intent.contains(.emphasized) {
                a[run.range].font = font.bold().italic()
            } else if intent.contains(.stronglyEmphasized) {
                a[run.range].font = font.bold()
            } else if intent.contains(.emphasized) {
                a[run.range].font = font.italic()
            }
            if intent.contains(.strikethrough) {
                a[run.range].strikethroughStyle = .single
            }
        }
        return a
    }
}
