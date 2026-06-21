import Foundation

/// User-tunable options for a conversion run.
struct ConversionSettings: Equatable {

    enum ResizeMode: String, CaseIterable, Identifiable {
        case original = "Original size"
        case long2048 = "Long edge 2048"
        case long4096 = "Long edge 4096"
        case half     = "Half resolution"
        var id: String { rawValue }

        /// Returns the max pixel size for the long edge, given the source's
        /// longest dimension, or nil to leave untouched.
        func maxPixelSize(forLongest longest: CGFloat) -> CGFloat? {
            switch self {
            case .original: return nil
            case .long2048: return 2048
            case .long4096: return 4096
            case .half:     return max(1, longest / 2)
            }
        }
    }

    /// 0...1 lossy quality. Ignored by lossless formats.
    var quality: Double = 0.85

    /// Resize strategy.
    var resize: ResizeMode = .original

    /// Keep EXIF / IPTC / TIFF metadata, or strip it (incl. GPS) for privacy.
    var preserveMetadata: Bool = true

    /// Preserve the HDR gain map (ISO 21496-1) when both source and target
    /// support it. Falls back silently when not applicable.
    var preserveHDR: Bool = true

    /// A human label for the current quality.
    var qualityLabel: String {
        switch quality {
        case ..<0.35:  return "Compact"
        case ..<0.65:  return "Balanced"
        case ..<0.88:  return "High"
        default:       return "Maximum"
        }
    }
}
