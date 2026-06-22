import UIKit
import Markdown

/// Pure-logic walker: Markdown source → NSAttributedString styled per
/// `MarkdownTheme`. Syntax marks (`**`, `*`, `#`, backticks, `>`) are
/// preserved in the visible text and **dimmed** so the user sees what
/// they typed but the formatting reads correctly.
enum MarkdownStyler {

    static func attributed(for source: String) -> NSAttributedString {
        let doc = Document(parsing: source)
        let out = NSMutableAttributedString()
        var walker = Walker(out: out)
        walker.visit(doc)
        return out
    }

    // MARK: – Walker

    private struct Walker: MarkupWalker {
        let out: NSMutableAttributedString
        var stack: [Style] = [.body]

        mutating func visitText(_ text: Text) {
            append(text.string, style: stack.last ?? .body)
        }

        mutating func visitEmphasis(_ e: Emphasis) {
            appendMark("*")
            push((stack.last ?? .body).adding(.italic)); defer { pop() }
            descendInto(e)
            appendMark("*")
        }

        mutating func visitStrong(_ s: Strong) {
            appendMark("**")
            push((stack.last ?? .body).adding(.bold)); defer { pop() }
            descendInto(s)
            appendMark("**")
        }

        mutating func visitInlineCode(_ c: InlineCode) {
            appendMark("`")
            append(c.code, style: .code)
            appendMark("`")
        }

        mutating func visitHeading(_ h: Heading) {
            appendMark(String(repeating: "#", count: h.level) + " ")
            push(.heading(h.level)); defer { pop() }
            descendInto(h)
            append("\n", style: .body)
        }

        mutating func visitBlockQuote(_ bq: BlockQuote) {
            appendMark("> ")
            push(.blockquote); defer { pop() }
            descendInto(bq)
            append("\n", style: .body)
        }

        mutating func visitParagraph(_ p: Paragraph) {
            descendInto(p)
            append("\n", style: .body)
        }

        mutating func visitOrderedList(_ list: OrderedList) {
            let children = Array(list.children)
            for (i, item) in children.enumerated() {
                appendMark("\(i + 1). ")
                descendInto(item)
                if i < children.count - 1 { append("\n", style: .body) }
            }
            append("\n", style: .body)
        }

        mutating func visitUnorderedList(_ list: UnorderedList) {
            let children = Array(list.children)
            for (i, item) in children.enumerated() {
                appendMark("• ")
                descendInto(item)
                if i < children.count - 1 { append("\n", style: .body) }
            }
            append("\n", style: .body)
        }

        // MARK: – Helpers

        private mutating func descendInto(_ markup: Markup) {
            for child in markup.children { visit(child) }
        }

        private mutating func push(_ s: Style) { stack.append(s) }
        private mutating func pop() { _ = stack.popLast() }

        private mutating func append(_ s: String, style: Style) {
            out.append(NSAttributedString(string: s, attributes: style.attributes()))
        }

        private mutating func appendMark(_ s: String) {
            var attrs = (stack.last ?? .body).attributes()
            attrs[.foregroundColor] = MarkdownTheme.faint
            out.append(NSAttributedString(string: s, attributes: attrs))
        }
    }

    // MARK: – Style descriptor

    private enum Style {
        case body, code, blockquote
        case heading(Int)
        indirect case modified(Style, traits: Traits)

        struct Traits: OptionSet {
            let rawValue: Int
            static let bold   = Traits(rawValue: 1 << 0)
            static let italic = Traits(rawValue: 1 << 1)
        }

        var traits: Traits {
            if case .modified(_, let t) = self { return t }
            return []
        }

        func adding(_ t: Traits) -> Style { .modified(self, traits: traits.union(t)) }

        func attributes() -> [NSAttributedString.Key: Any] {
            switch self {
            case .body:
                return [
                    .font: fontWithTraits(MarkdownTheme.body(), traits: traits),
                    .foregroundColor: MarkdownTheme.ink,
                    .paragraphStyle: MarkdownTheme.paragraphStyle()
                ]
            case .code:
                return [
                    .font: MarkdownTheme.mono(),
                    .foregroundColor: MarkdownTheme.ink,
                    .paragraphStyle: MarkdownTheme.paragraphStyle()
                ]
            case .blockquote:
                return [
                    .font: fontWithTraits(MarkdownTheme.body(), traits: traits.union(.italic)),
                    .foregroundColor: MarkdownTheme.inkSoft,
                    .paragraphStyle: MarkdownTheme.blockquoteParagraphStyle()
                ]
            case .heading(let lvl):
                return [
                    .font: MarkdownTheme.heading(level: lvl),
                    .foregroundColor: MarkdownTheme.ink,
                    .paragraphStyle: MarkdownTheme.headingParagraphStyle()
                ]
            case .modified(let inner, _):
                var attrs = inner.attributes()
                if let f = attrs[.font] as? UIFont {
                    attrs[.font] = fontWithTraits(f, traits: traits)
                }
                return attrs
            }
        }
    }

    private static func fontWithTraits(_ base: UIFont, traits: Style.Traits) -> UIFont {
        if traits.contains([.bold, .italic]) { return MarkdownTheme.boldItalic() }
        if traits.contains(.bold)   { return MarkdownTheme.bold() }
        if traits.contains(.italic) { return MarkdownTheme.italic() }
        return base
    }
}
