import SwiftUI

/// The visual language for Press: warm paper, ink-black serif type,
/// hairline rules, and a single restrained sienna accent.
enum Paper {

    // MARK: Surfaces
    /// The primary canvas — warm cream stock.
    static let bg        = Color(red: 0.957, green: 0.933, blue: 0.882)   // #F4EEE1
    /// Raised surfaces (cards, sheets) — a touch brighter, like fresh leaf.
    static let raised    = Color(red: 0.984, green: 0.969, blue: 0.933)   // #FBF7EE
    /// A slightly toned inset, for wells and pressed states.
    static let sunken    = Color(red: 0.929, green: 0.902, blue: 0.843)   // #EDE6D7

    // MARK: Ink
    /// Primary text and strokes — a warm near-black, never pure #000.
    static let ink       = Color(red: 0.110, green: 0.102, blue: 0.090)   // #1C1A17
    /// Secondary text.
    static let inkSoft   = Color(red: 0.369, green: 0.337, blue: 0.290)   // #5E564A
    /// Tertiary / hints.
    static let inkFaint  = Color(red: 0.541, green: 0.506, blue: 0.439)   // #8A8170
    /// Hairline rules and quiet borders.
    static let line      = Color(red: 0.855, green: 0.816, blue: 0.745)   // #DAD0BE

    // MARK: Accent
    /// Used sparingly — selection, progress, the occasional flourish.
    static let accent    = Color(red: 0.604, green: 0.290, blue: 0.176)   // #9A4A2D
}

extension Font {
    /// Editorial serif scale, drawn from the system New York face.
    static func serif(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }

    static let mastheadXL  = Font.system(size: 52, weight: .regular, design: .serif)
    static let masthead    = Font.system(size: 34, weight: .regular, design: .serif)
    static let titleSerif  = Font.system(size: 26, weight: .medium,  design: .serif)
    static let headline    = Font.system(size: 19, weight: .medium,  design: .serif)
    static let bodySerif   = Font.system(size: 17, weight: .regular, design: .serif)
    static let calloutSerif = Font.system(size: 15, weight: .regular, design: .serif)
    /// Used for labels in tracked small caps.
    static let label       = Font.system(size: 12, weight: .semibold, design: .serif)
    /// Monospaced for figures — byte counts, dimensions.
    static func figure(_ size: CGFloat = 14, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

extension Text {
    /// A tracked, uppercase section label in soft ink.
    func sectionLabel() -> some View {
        self.font(.label)
            .textCase(.uppercase)
            .tracking(1.6)
            .foregroundStyle(Paper.inkSoft)
    }
}
