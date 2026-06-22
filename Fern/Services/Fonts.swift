import CoreText
import Foundation

/// Registers Fern's bundled display typeface (Fraunces — a warm, soft "old
/// style" serif). Called once at launch. Falls back to the system serif if the
/// resource is ever missing.
enum Fonts {
    static func register() {
        guard let url = Bundle.main.url(forResource: "Fraunces", withExtension: "ttf") else { return }
        CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
    }
}
