import SwiftUI

typealias RGB = (Double, Double, Double)

/// Paper tone presets — vary the surface hues (bg/raised/sunken/line). Ink
/// stays constant so text remains legible across tones. Each has a light value
/// and its dark-mode inverse.
enum PaperTone: String, CaseIterable, Identifiable {
    case mist, linen, cloud, slate
    var id: String { rawValue }
    var title: String { rawValue.capitalized }

    struct Palette {
        let bgL, bgD, raisedL, raisedD, sunkenL, sunkenD, lineL, lineD: RGB
    }

    var palette: Palette {
        switch self {
        case .mist:
            return Palette(bgL: (0.965, 0.961, 0.945), bgD: (0.102, 0.094, 0.082),
                           raisedL: (1.000, 1.000, 1.000), raisedD: (0.141, 0.133, 0.125),
                           sunkenL: (0.925, 0.918, 0.886), sunkenD: (0.063, 0.059, 0.051),
                           lineL: (0.922, 0.914, 0.882), lineD: (0.204, 0.196, 0.176))
        case .linen:
            return Palette(bgL: (0.957, 0.937, 0.906), bgD: (0.110, 0.098, 0.078),
                           raisedL: (1.000, 0.992, 0.980), raisedD: (0.149, 0.133, 0.110),
                           sunkenL: (0.918, 0.894, 0.855), sunkenD: (0.070, 0.060, 0.045),
                           lineL: (0.910, 0.886, 0.847), lineD: (0.212, 0.192, 0.160))
        case .cloud:
            return Palette(bgL: (0.945, 0.949, 0.953), bgD: (0.086, 0.090, 0.094),
                           raisedL: (1.000, 1.000, 1.000), raisedD: (0.130, 0.135, 0.141),
                           sunkenL: (0.906, 0.914, 0.922), sunkenD: (0.055, 0.059, 0.063),
                           lineL: (0.898, 0.906, 0.914), lineD: (0.188, 0.196, 0.204))
        case .slate:
            return Palette(bgL: (0.929, 0.925, 0.918), bgD: (0.094, 0.094, 0.090),
                           raisedL: (0.988, 0.984, 0.976), raisedD: (0.137, 0.137, 0.133),
                           sunkenL: (0.890, 0.886, 0.878), sunkenD: (0.059, 0.059, 0.055),
                           lineL: (0.882, 0.878, 0.870), lineD: (0.196, 0.196, 0.192))
        }
    }

    var swatch: Color {
        let p = palette.bgL
        return Color(red: p.0, green: p.1, blue: p.2)
    }
}

/// Accent presets — light value + brightened dark-mode value.
enum AccentTone: String, CaseIterable, Identifiable {
    case sienna, sage, indigo, plum, ochre
    var id: String { rawValue }
    var title: String { rawValue.capitalized }

    var light: RGB {
        switch self {
        case .sienna: return (0.604, 0.290, 0.176)
        case .sage:   return (0.357, 0.467, 0.337)
        case .indigo: return (0.271, 0.357, 0.580)
        case .plum:   return (0.510, 0.298, 0.459)
        case .ochre:  return (0.659, 0.471, 0.129)
        }
    }
    var dark: RGB {
        switch self {
        case .sienna: return (0.761, 0.412, 0.247)
        case .sage:   return (0.553, 0.690, 0.522)
        case .indigo: return (0.494, 0.604, 0.851)
        case .plum:   return (0.741, 0.502, 0.682)
        case .ochre:  return (0.851, 0.659, 0.302)
        }
    }
    var swatch: Color { Color(red: light.0, green: light.1, blue: light.2) }
}
