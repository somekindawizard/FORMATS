import UIKit
import ImageIO
import UniformTypeIdentifiers

/// A picked image staged in the app's temporary directory, with the few
/// facts we need to display and convert it.
struct SourceImage: Identifiable, Hashable {
    let id = UUID()
    /// A stable file URL inside the app's temp area.
    let url: URL
    /// The detected source UTI.
    let uti: String
    /// Pixel dimensions of the primary image.
    let pixelSize: CGSize
    /// Byte size on disk.
    let byteSize: Int
    /// Whether the source carries an HDR gain map.
    let hasGainMap: Bool
    /// A small preview.
    let thumbnail: UIImage

    /// Original display name without extension.
    let displayName: String

    var formatName: String {
        FormatCatalog.describe(uti: uti)?.name
            ?? UTType(uti)?.localizedDescription
            ?? (URL(fileURLWithPath: url.path).pathExtension.uppercased())
    }

    static func == (lhs: SourceImage, rhs: SourceImage) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

/// The product of a successful conversion.
struct ConversionResult: Identifiable, Hashable {
    let id = UUID()
    let url: URL
    let format: ImageFormat
    let originalBytes: Int
    let outputBytes: Int
    let thumbnail: UIImage
    let sourceName: String

    /// Signed size delta as a fraction, e.g. -0.62 means 62% smaller.
    var sizeDelta: Double {
        guard originalBytes > 0 else { return 0 }
        return Double(outputBytes - originalBytes) / Double(originalBytes)
    }

    static func == (lhs: ConversionResult, rhs: ConversionResult) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
