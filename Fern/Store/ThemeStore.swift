import SwiftUI

/// The selected paper tone + accent, persisted in UserDefaults. A shared
/// singleton so `Paper.*` can read it, and also injected via the environment
/// so Settings can bind to it. Because this is @Observable and `Paper.*`
/// reads it during body evaluation, theme changes re-render dependents via
/// Observation — no `.id` keying at the root (that destroyed all view state).
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
    /// Dim everything but the paragraph you're writing.
    var focusMode: Bool {
        didSet { UserDefaults.standard.set(focusMode, forKey: "fern.write.focus") }
    }
    /// Keep the caret line vertically centered as you type.
    var typewriter: Bool {
        didSet { UserDefaults.standard.set(typewriter, forKey: "fern.write.typewriter") }
    }
    /// Hide Markdown marks except on the line you're editing (live preview).
    var foldMarkers: Bool {
        didSet { UserDefaults.standard.set(foldMarkers, forKey: "fern.write.fold") }
    }
    /// Left- or right-handed layout — mirrors the ink & formatting bars so the
    /// writing hand never covers the controls.
    var handedness: Handedness {
        didSet { UserDefaults.standard.set(handedness.rawValue, forKey: "fern.hand") }
    }
    /// Gap between ruled / dot-grid lines, in points.
    var ruleSpacing: Double {
        didSet { UserDefaults.standard.set(ruleSpacing, forKey: "fern.rule.spacing") }
    }

    private init() {
        tone = PaperTone(rawValue: UserDefaults.standard.string(forKey: "fern.theme.tone") ?? "") ?? .mist
        accent = AccentTone(rawValue: UserDefaults.standard.string(forKey: "fern.theme.accent") ?? "") ?? .sienna
        displayFont = DisplayFont(rawValue: UserDefaults.standard.string(forKey: "fern.theme.font") ?? "") ?? .fraunces
        paperRule = PaperRule(rawValue: UserDefaults.standard.string(forKey: "fern.theme.rule") ?? "") ?? .plain
        focusMode = UserDefaults.standard.bool(forKey: "fern.write.focus")
        typewriter = UserDefaults.standard.bool(forKey: "fern.write.typewriter")
        foldMarkers = UserDefaults.standard.object(forKey: "fern.write.fold") as? Bool ?? true
        handedness = Handedness(rawValue: UserDefaults.standard.string(forKey: "fern.hand") ?? "") ?? .right
        let savedSpacing = UserDefaults.standard.double(forKey: "fern.rule.spacing")
        ruleSpacing = savedSpacing > 0 ? savedSpacing : 30
    }
}
