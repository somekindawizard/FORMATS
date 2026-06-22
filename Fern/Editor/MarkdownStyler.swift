import UIKit

/// Styles Markdown **in place**: returns an attributed string whose characters
/// are byte-for-byte the source (so the editor never rewrites what you typed —
/// spaces and line breaks are preserved). It only assigns fonts/colors over
/// ranges found by lightweight scanning. Syntax marks (`**`, `*`, `#`, `>`,
/// backticks) stay visible but dimmed.
enum MarkdownStyler {

    /// The default body attributes — also used to reset before re-styling.
    static func baseAttributes() -> [NSAttributedString.Key: Any] {
        [
            .font: MarkdownTheme.body(),
            .foregroundColor: MarkdownTheme.ink,
            .paragraphStyle: MarkdownTheme.paragraphStyle()
        ]
    }

    static func attributed(for source: String) -> NSAttributedString {
        let text = NSMutableAttributedString(string: source, attributes: baseAttributes())
        let ns = source as NSString
        let whole = NSRange(location: 0, length: ns.length)

        func dim(_ range: NSRange) {
            guard range.location >= 0, NSMaxRange(range) <= ns.length else { return }
            text.addAttribute(.foregroundColor, value: MarkdownTheme.faint, range: range)
        }

        func eachMatch(_ pattern: String, _ options: NSRegularExpression.Options = [],
                       _ body: (NSTextCheckingResult) -> Void) {
            guard let re = try? NSRegularExpression(pattern: pattern, options: options) else { return }
            re.enumerateMatches(in: source, range: whole) { match, _, _ in
                if let match { body(match) }
            }
        }

        func addTrait(_ trait: UIFontDescriptor.SymbolicTraits, over range: NSRange) {
            text.enumerateAttribute(.font, in: range, options: []) { value, sub, _ in
                let base = (value as? UIFont) ?? MarkdownTheme.body()
                var traits = base.fontDescriptor.symbolicTraits
                traits.insert(trait)
                if let desc = base.fontDescriptor.withSymbolicTraits(traits) {
                    text.addAttribute(.font, value: UIFont(descriptor: desc, size: base.pointSize), range: sub)
                }
            }
        }

        // Headings: leading #'s + space, whole line in heading font.
        eachMatch("^(#{1,6})[ \\t]+(.+)$", [.anchorsMatchLines]) { m in
            let hashes = m.range(at: 1)
            let level = min(hashes.length, 6)
            let lineRange = NSRange(location: hashes.location, length: NSMaxRange(m.range) - hashes.location)
            text.addAttribute(.font, value: MarkdownTheme.heading(level: level), range: lineRange)
            text.addAttribute(.foregroundColor, value: MarkdownTheme.ink, range: lineRange)
            text.addAttribute(.paragraphStyle, value: MarkdownTheme.headingParagraphStyle(), range: m.range)
            dim(NSRange(location: hashes.location, length: hashes.length + 1)) // #'s + the space
        }

        // Block quotes: leading > .
        eachMatch("^(>[ \\t]?)(.*)$", [.anchorsMatchLines]) { m in
            text.addAttribute(.foregroundColor, value: MarkdownTheme.inkSoft, range: m.range)
            text.addAttribute(.paragraphStyle, value: MarkdownTheme.blockquoteParagraphStyle(), range: m.range)
            addTrait(.traitItalic, over: m.range)
            dim(m.range(at: 1))
        }

        // Bold **…**
        eachMatch("\\*\\*(.+?)\\*\\*") { m in
            addTrait(.traitBold, over: m.range)
            dim(NSRange(location: m.range.location, length: 2))
            dim(NSRange(location: NSMaxRange(m.range) - 2, length: 2))
        }

        // Italic *…* (single asterisks, not adjacent to another *)
        eachMatch("(?<!\\*)\\*(?!\\*)([^*\\n]+)\\*(?!\\*)") { m in
            addTrait(.traitItalic, over: m.range)
            dim(NSRange(location: m.range.location, length: 1))
            dim(NSRange(location: NSMaxRange(m.range) - 1, length: 1))
        }

        // Inline code `…`
        eachMatch("`([^`\\n]+)`") { m in
            text.addAttribute(.font, value: MarkdownTheme.mono(), range: m.range)
            dim(NSRange(location: m.range.location, length: 1))
            dim(NSRange(location: NSMaxRange(m.range) - 1, length: 1))
        }

        return text
    }
}
