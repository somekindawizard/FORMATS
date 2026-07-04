import UIKit
import CoreImage

/// A text attachment that remembers which stored photo it represents, so the
/// editor's attributed text can be serialized back to `![](fern://name)`.
final class PhotoAttachment: NSTextAttachment {
    let filename: String
    init(filename: String) { self.filename = filename; super.init(data: nil, ofType: nil) }
    required init?(coder: NSCoder) { self.filename = ""; super.init(coder: coder) }

    /// Set a **fixed** display size for the given available width — magazine
    /// sizing on wide layouts, full-bleed on iPhone. Called once when built and
    /// again only when the editor's width actually changes (rotation / sidebar /
    /// Split View), never per layout pass — computing it per pass created a
    /// feedback loop that made the page jitter while typing.
    func fit(toWidth avail: CGFloat) {
        guard let image, image.size.width > 0, avail > 1 else { return }
        let scale: CGFloat = avail > 500 ? 0.6 : 1.0
        let w = min(avail * scale, image.size.width)
        let h = image.size.height * (w / image.size.width)
        bounds = CGRect(x: 0, y: 0, width: w, height: h)
    }
}

/// Bridges the Markdown body (with `fern://` photo tokens) to the live editor's
/// attributed text (with inline image attachments) and back. Lets you *see*
/// embedded photos while writing while keeping the stored document plain
/// Markdown.
enum EditorPhotos {

    /// Centers a photo on its own line, magazine-style.
    static var centeredParagraph: NSParagraphStyle {
        let p = NSMutableParagraphStyle()
        p.alignment = .center
        p.paragraphSpacing = 6
        p.paragraphSpacingBefore = 6
        return p
    }

    /// Markdown → attributed text: photo tokens become inline image attachments,
    /// everything else is styled by `MarkdownStyler`.
    static func attributed(fromMarkdown md: String, width: CGFloat, wash: Bool = false) -> NSAttributedString {
        let result = NSMutableAttributedString()
        for seg in PhotoToken.segments(md) {
            switch seg {
            case .text(let t):
                result.append(MarkdownStyler.attributed(for: t))
            case .photo(let name):
                let a = NSMutableAttributedString(attachment: attachment(name, width: width, wash: wash))
                a.addAttribute(.paragraphStyle, value: centeredParagraph,
                               range: NSRange(location: 0, length: a.length))
                result.append(a)
            }
        }
        return result
    }

    /// Attributed text → Markdown: image attachments become photo tokens.
    static func markdown(from attr: NSAttributedString) -> String {
        let ns = attr.string as NSString
        let out = NSMutableString()
        attr.enumerateAttribute(.attachment, in: NSRange(location: 0, length: attr.length)) { value, range, _ in
            if let a = value as? PhotoAttachment {
                out.append("![](fern://\(a.filename))")
            } else {
                out.append(ns.substring(with: range))
            }
        }
        return out as String
    }

    /// An image attachment sized to the editor width, with rounded corners.
    static func attachment(_ name: String, width: CGFloat, wash: Bool = false) -> PhotoAttachment {
        let att = PhotoAttachment(filename: name)
        if let raw = PhotoStore.load(name) {
            let img = wash ? washed(raw) : raw
            // Render at a generous resolution (decoupled from the display size,
            // which `fit(toWidth:)` sets) so the downscaled image stays crisp.
            let renderW = max(1, min(img.size.width, 1400))
            let renderH = img.size.height * (renderW / img.size.width)
            att.image = rounded(img, size: CGSize(width: renderW, height: renderH),
                                radius: renderW * 0.022)
            att.fit(toWidth: width)   // fixed display bounds
        } else {
            att.bounds = CGRect(x: 0, y: 0, width: width, height: 44)
        }
        return att
    }

    private static func rounded(_ image: UIImage, size: CGSize, radius: CGFloat) -> UIImage {
        UIGraphicsImageRenderer(size: size).image { _ in
            let rect = CGRect(origin: .zero, size: size)
            UIBezierPath(roundedRect: rect, cornerRadius: radius).addClip()
            image.draw(in: rect)
        }
    }

    private static let ciContext = CIContext(options: nil)

    /// A theme-toned, **airy** black-and-white wash: desaturate, lift the
    /// exposure and drop contrast for a faded high-key look, then tint with a
    /// pastel (lightened) version of the accent. Parameters are tunable live via
    /// the Wash Lab dev screen.
    static func washed(_ image: UIImage, params: WashParams = .current) -> UIImage {
        guard let ci = CIImage(image: image) else { return image }
        let a = ThemeStore.shared.accent.light
        // tintMix 0 → cream/white, 1 → full accent.
        let m = CGFloat(params.tintMix)
        let tint = CIColor(red: (1 - m) + m * CGFloat(a.0),
                           green: (1 - m) + m * CGFloat(a.1),
                           blue: (1 - m) + m * CGFloat(a.2))
        let out = ci
            .applyingFilter("CIColorControls", parameters: [
                kCIInputSaturationKey: 0.0,
                kCIInputBrightnessKey: params.brightness,
                kCIInputContrastKey: params.contrast])
            .applyingFilter("CIColorMonochrome", parameters: [
                "inputColor": tint, "inputIntensity": params.intensity])
            .applyingFilter("CIExposureAdjust", parameters: [kCIInputEVKey: params.exposure])
        guard let cg = ciContext.createCGImage(out, from: out.extent) else { return image }
        return UIImage(cgImage: cg, scale: image.scale, orientation: image.imageOrientation)
    }
}

/// Tunable parameters for the photo wash. Persisted so the Wash Lab dev screen
/// can dial them in live and the whole app reflects the change.
struct WashParams: Equatable, Codable {
    var brightness: Double = 0.01
    var contrast: Double = 0.94
    var exposure: Double = 0.35
    var intensity: Double = 1.00
    var tintMix: Double = 0.60

    static var current: WashParams {
        guard let data = UserDefaults.standard.data(forKey: "fern.wash"),
              let p = try? JSONDecoder().decode(WashParams.self, from: data) else { return WashParams() }
        return p
    }
    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: "fern.wash")
        }
    }
    /// A one-line, paste-friendly summary of the current values.
    var summary: String {
        String(format: "brightness %.2f · contrast %.2f · exposure %.2f · intensity %.2f · tintMix %.2f",
               brightness, contrast, exposure, intensity, tintMix)
    }
}
