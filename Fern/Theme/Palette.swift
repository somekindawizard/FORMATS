import SwiftUI
import UIKit

/// Resolves to one color in light mode, its inverse in dark mode.
private func adaptive(_ light: (Double, Double, Double),
                      _ dark: (Double, Double, Double)) -> Color {
    Color(uiColor: UIColor { trait in
        let c = trait.userInterfaceStyle == .dark ? dark : light
        return UIColor(red: CGFloat(c.0), green: CGFloat(c.1), blue: CGFloat(c.2), alpha: 1)
    })
}

/// Fern's visual language: cool soft paper, warm near-black ink, hairline
/// rules, and a single restrained sienna accent — inverted for dark mode
/// (dark warm paper, cream ink, a brighter terracotta accent).
enum Paper {

    // MARK: Surfaces
    /// Primary canvas — "Mist" (light) / warm charcoal (dark).
    static let bg      = adaptive((0.965, 0.961, 0.945), (0.102, 0.094, 0.082))  // #F6F5F1 / #1A1815
    /// Raised surfaces (cards, sheets).
    static let raised  = adaptive((1.000, 1.000, 1.000), (0.141, 0.133, 0.125))  // #FFFFFF / #242220
    /// A toned inset for wells and pressed states.
    static let sunken  = adaptive((0.925, 0.918, 0.886), (0.063, 0.059, 0.051))  // #ECEAE2 / #100F0D

    // MARK: Ink
    /// Primary text and strokes — near-black (light) / warm cream (dark).
    static let ink      = adaptive((0.110, 0.102, 0.090), (0.949, 0.937, 0.910)) // #1C1A17 / #F2EFE8
    /// Secondary text.
    static let inkSoft  = adaptive((0.357, 0.341, 0.314), (0.718, 0.698, 0.651)) // #5B5750 / #B7B2A6
    /// Tertiary / hints / dimmed Markdown syntax marks.
    static let inkFaint = adaptive((0.541, 0.525, 0.486), (0.498, 0.475, 0.435)) // #8A867C / #7F796F
    /// Hairline rules and quiet borders.
    static let line     = adaptive((0.922, 0.914, 0.882), (0.204, 0.196, 0.176)) // #EBE9E1 / #34322D

    // MARK: Accent
    /// Used sparingly — selection, the active tab, a pinned star, the fern mark.
    static let accent   = adaptive((0.604, 0.290, 0.176), (0.761, 0.412, 0.247)) // #9A4A2D / #C2693F
}
