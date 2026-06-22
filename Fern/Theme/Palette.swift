import SwiftUI
import UIKit

/// Resolves to one color in light mode, its inverse in dark mode.
private func adaptive(_ light: RGB, _ dark: RGB) -> Color {
    Color(uiColor: UIColor { trait in
        let c = trait.userInterfaceStyle == .dark ? dark : light
        return UIColor(red: CGFloat(c.0), green: CGFloat(c.1), blue: CGFloat(c.2), alpha: 1)
    })
}

/// Fern's visual language. Surfaces and accent follow the chosen theme
/// (`ThemeStore`); ink stays constant for legibility. Inverted for dark mode.
enum Paper {

    private static var tone: PaperTone.Palette { ThemeStore.shared.tone.palette }

    // MARK: Surfaces (themed)
    static var bg: Color     { adaptive(tone.bgL, tone.bgD) }
    static var raised: Color { adaptive(tone.raisedL, tone.raisedD) }
    static var sunken: Color { adaptive(tone.sunkenL, tone.sunkenD) }
    static var line: Color   { adaptive(tone.lineL, tone.lineD) }

    // MARK: Ink (constant)
    static let ink      = adaptive((0.110, 0.102, 0.090), (0.949, 0.937, 0.910))
    static let inkSoft  = adaptive((0.357, 0.341, 0.314), (0.718, 0.698, 0.651))
    static let inkFaint = adaptive((0.541, 0.525, 0.486), (0.498, 0.475, 0.435))

    // MARK: Accent (themed)
    static var accent: Color {
        let a = ThemeStore.shared.accent
        return adaptive(a.light, a.dark)
    }
}
