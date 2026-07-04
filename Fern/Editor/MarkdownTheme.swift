import UIKit

/// Fonts, colors, paragraph styles used by `MarkdownStyler` to render
/// CommonMark inline. Everything stylable from one place.
enum MarkdownTheme {

    // Colors — adaptive (light / inverted dark), matching Paper.* in Palette.swift.
    private static func dyn(_ l: (CGFloat, CGFloat, CGFloat),
                            _ d: (CGFloat, CGFloat, CGFloat)) -> UIColor {
        UIColor { trait in
            let c = trait.userInterfaceStyle == .dark ? d : l
            return UIColor(red: c.0, green: c.1, blue: c.2, alpha: 1)
        }
    }
    static let ink     = dyn((0.110, 0.102, 0.090), (0.949, 0.937, 0.910))
    static let inkSoft = dyn((0.357, 0.341, 0.314), (0.718, 0.698, 0.651))
    /// Used to dim Markdown syntax marks (`**`, `*`, `#`, etc.).
    static let faint   = dyn((0.541, 0.525, 0.486), (0.498, 0.475, 0.435))
    /// Follows the chosen theme accent.
    static var accent: UIColor {
        let a = ThemeStore.shared.accent
        return UIColor { trait in
            let c = trait.userInterfaceStyle == .dark ? a.dark : a.light
            return UIColor(red: CGFloat(c.0), green: CGFloat(c.1), blue: CGFloat(c.2), alpha: 1)
        }
    }

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
        // No left indent — quotes read as flush italic, editorial style.
        let p = NSMutableParagraphStyle()
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
