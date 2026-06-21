import SwiftUI

/// Fern's visual language: cool soft paper, warm near-black ink,
/// hairline rules, and a single restrained sienna accent.
/// Retuned from the sibling Press app to a cleaner, cooler paper.
enum Paper {

    // MARK: Surfaces
    /// Primary canvas — "Mist", a soft de-greened paper white.
    static let bg      = Color(red: 0.965, green: 0.961, blue: 0.945)  // #F6F5F1
    /// Raised surfaces (cards, sheets) — clean white.
    static let raised  = Color(red: 1.000, green: 1.000, blue: 1.000)  // #FFFFFF
    /// A slightly toned inset for wells and pressed states.
    static let sunken  = Color(red: 0.925, green: 0.918, blue: 0.886)  // #ECEAE2

    // MARK: Ink
    /// Primary text and strokes — a warm near-black, never pure #000.
    static let ink      = Color(red: 0.110, green: 0.102, blue: 0.090) // #1C1A17
    /// Secondary text.
    static let inkSoft  = Color(red: 0.357, green: 0.341, blue: 0.314) // #5B5750
    /// Tertiary / hints / dimmed Markdown syntax marks.
    static let inkFaint = Color(red: 0.541, green: 0.525, blue: 0.486) // #8A867C
    /// Hairline rules and quiet borders.
    static let line     = Color(red: 0.922, green: 0.914, blue: 0.882) // #EBE9E1

    // MARK: Accent
    /// Used sparingly — selection, the active tab, a pinned star, the fern mark.
    static let accent   = Color(red: 0.604, green: 0.290, blue: 0.176) // #9A4A2D
}
