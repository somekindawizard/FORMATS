import SwiftUI

/// The selected paper tone + accent, persisted in UserDefaults. A shared
/// singleton so `Paper.*` can read it, and also injected via the environment
/// so Settings can bind to it. Changing either bumps `paletteKey`, which the
/// app root uses as an `.id` to re-render with the new colors.
@Observable
final class ThemeStore {
    static let shared = ThemeStore()

    var tone: PaperTone {
        didSet { UserDefaults.standard.set(tone.rawValue, forKey: "fern.theme.tone") }
    }
    var accent: AccentTone {
        didSet { UserDefaults.standard.set(accent.rawValue, forKey: "fern.theme.accent") }
    }
    var displayFont: DisplayFont {
        didSet { UserDefaults.standard.set(displayFont.rawValue, forKey: "fern.theme.font") }
    }
    var paperRule: PaperRule {
        didSet { UserDefaults.standard.set(paperRule.rawValue, forKey: "fern.theme.rule") }
    }

    private init() {
        tone = PaperTone(rawValue: UserDefaults.standard.string(forKey: "fern.theme.tone") ?? "") ?? .mist
        accent = AccentTone(rawValue: UserDefaults.standard.string(forKey: "fern.theme.accent") ?? "") ?? .sienna
        displayFont = DisplayFont(rawValue: UserDefaults.standard.string(forKey: "fern.theme.font") ?? "") ?? .fraunces
        paperRule = PaperRule(rawValue: UserDefaults.standard.string(forKey: "fern.theme.rule") ?? "") ?? .plain
    }

    var paletteKey: String { "\(tone.rawValue)-\(accent.rawValue)-\(displayFont.rawValue)-\(paperRule.rawValue)" }
}
