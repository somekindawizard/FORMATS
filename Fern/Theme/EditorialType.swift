import SwiftUI
import UIKit
import CoreText

extension UIFontDescriptor {
    /// Old-style (text) figures + common ligatures — the refined details that
    /// make numerals and letter pairs read like proper typesetting.
    func withEditorialFeatures(smallCaps: Bool = false) -> UIFontDescriptor {
        var features: [[UIFontDescriptor.FeatureKey: Int]] = [
            [.type: kNumberCaseType, .selector: kLowerCaseNumbersSelector],   // old-style figures
            [.type: kLigaturesType, .selector: kCommonLigaturesOnSelector]
        ]
        if smallCaps {
            features.append([.type: kLowerCaseType, .selector: kLowerCaseSmallCapsSelector])
        }
        return addingAttributes([.featureSettings: features])
    }
}

/// Serif type with the editorial features baked in, for SwiftUI (reader) use.
enum EditorialType {
    static func serifFont(_ size: CGFloat, weight: UIFont.Weight = .regular,
                          italic: Bool = false, smallCaps: Bool = false) -> UIFont {
        var desc = UIFont.systemFont(ofSize: size, weight: weight).fontDescriptor.withDesign(.serif)
            ?? UIFont.systemFont(ofSize: size, weight: weight).fontDescriptor
        if italic { desc = desc.withSymbolicTraits(.traitItalic) ?? desc }
        desc = desc.withEditorialFeatures(smallCaps: smallCaps)
        return UIFont(descriptor: desc, size: size)
    }

    static func font(_ size: CGFloat, weight: UIFont.Weight = .regular,
                     italic: Bool = false, smallCaps: Bool = false) -> Font {
        Font(serifFont(size, weight: weight, italic: italic, smallCaps: smallCaps) as CTFont)
    }
}
