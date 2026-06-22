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

    private init() {
        tone = PaperTone(rawValue: UserDefaults.standard.string(forKey: "fern.theme.tone") ?? "") ?? .mist
        accent = AccentTone(rawValue: UserDefaults.standard.string(forKey: "fern.theme.accent") ?? "") ?? .sienna
    }

    var paletteKey: String { "\(tone.rawValue)-\(accent.rawValue)" }
}
