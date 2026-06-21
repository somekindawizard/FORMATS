import Foundation
import UniformTypeIdentifiers

/// A target format the user can convert *to*. Encodability is decided at
/// runtime against what the OS reports it can write (see `FormatCatalog`),
/// so new system encoders — e.g. anything iOS adds in a future release —
/// appear automatically without a code change.
struct ImageFormat: Identifiable, Hashable {

    enum Family { case raster, document }

    /// The uniform type identifier, e.g. "public.heic".
    let uti: String
    /// Display name, e.g. "HEIC".
    let name: String
    /// Preferred file extension, e.g. "heic".
    let ext: String
    /// One-line editorial description.
    let blurb: String
    /// A compact note on why you'd reach for it.
    let useCase: String

    let family: Family
    let lossy: Bool
    let supportsAlpha: Bool
    let supportsHDR: Bool
    let supportsAnimation: Bool
    let supportsWideGamut: Bool

    var id: String { uti }

    var type: UTType? { UTType(uti) }

    /// Whether a quality slider is meaningful for this format.
    var hasQuality: Bool { lossy }
}
