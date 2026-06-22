import UIKit

/// Fonts, colors, paragraph styles used by `MarkdownStyler` to render
/// CommonMark inline. Everything stylable from one place.
enum MarkdownTheme {

    // Colors — pulled from the same RGB values as Paper.* (UIColor for UITextView).
    static let ink     = UIColor(red: 0.110, green: 0.102, blue: 0.090, alpha: 1)
    static let inkSoft = UIColor(red: 0.357, green: 0.341, blue: 0.314, alpha: 1)
    /// Used to dim Markdown syntax marks (`**`, `*`, `#`, etc.).
    static let faint   = UIColor(red: 0.541, green: 0.525, blue: 0.486, alpha: 1)
    static let accent  = UIColor(red: 0.604, green: 0.290, blue: 0.176, alpha: 1)

    // Fonts — system "New York" serif, scaled to the editor's body size.
    static let bodySize: CGFloat = 18
    static func body() -> UIFont {
        UIFont(descriptor: serifDescriptor(weight: .regular), size: bodySize)
    }
    static func italic() -> UIFont {
        UIFont(descriptor: serifDescriptor(weight: .regular, italic: true), size: bodySize)
    }
    static func bold() -> UIFont {
        UIFont(descriptor: serifDescriptor(weight: .semibold), size: bodySize)
    }
    static func boldItalic() -> UIFont {
        UIFont(descriptor: serifDescriptor(weight: .semibold, italic: true), size: bodySize)
    }
    static func heading(level: Int) -> UIFont {
        let size: CGFloat = switch level {
        case 1: 30
        case 2: 24
        case 3: 21
        default: 19
        }
        return UIFont(descriptor: serifDescriptor(weight: .medium), size: size)
    }
    static func mono(size: CGFloat = bodySize - 1) -> UIFont {
        UIFont.monospacedSystemFont(ofSize: size, weight: .regular)
    }

    // Paragraph spacing — generous, page-like.
    static func paragraphStyle() -> NSParagraphStyle {
        let p = NSMutableParagraphStyle()
        p.lineSpacing = 4
        p.paragraphSpacing = 10
        p.lineHeightMultiple = 1.15
        return p
    }
    static func headingParagraphStyle() -> NSParagraphStyle {
        let p = NSMutableParagraphStyle()
        p.lineHeightMultiple = 1.1
        p.paragraphSpacingBefore = 12
        p.paragraphSpacing = 6
        return p
    }
    static func blockquoteParagraphStyle() -> NSParagraphStyle {
        let p = NSMutableParagraphStyle()
        p.firstLineHeadIndent = 18
        p.headIndent = 18
        p.paragraphSpacing = 10
        p.lineSpacing = 4
        return p
    }

    private static func serifDescriptor(weight: UIFont.Weight, italic: Bool = false) -> UIFontDescriptor {
        var desc = UIFont.systemFont(ofSize: bodySize, weight: weight)
            .fontDescriptor
            .withDesign(.serif) ?? UIFont.systemFont(ofSize: bodySize, weight: weight).fontDescriptor
        if italic {
            desc = desc.withSymbolicTraits(.traitItalic) ?? desc
        }
        return desc
    }
}
