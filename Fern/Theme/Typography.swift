import SwiftUI

extension Font {
    /// Editorial serif scale, drawn from the system New York face.
    static func serif(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }

    static let mastheadXL   = Font.system(size: 52, weight: .regular, design: .serif)
    static let masthead     = Font.system(size: 34, weight: .regular, design: .serif)
    static let titleSerif   = Font.system(size: 26, weight: .medium,  design: .serif)
    static let headlineSerif = Font.system(size: 19, weight: .medium, design: .serif)
    static let bodySerif    = Font.system(size: 17, weight: .regular, design: .serif)
    static let calloutSerif = Font.system(size: 15, weight: .regular, design: .serif)
    /// Tracked small-caps section labels.
    static let label        = Font.system(size: 12, weight: .semibold, design: .serif)
    /// Monospaced for figures — word counts, dimensions.
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
