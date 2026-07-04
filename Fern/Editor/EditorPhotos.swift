import UIKit

/// A text attachment that remembers which stored photo it represents, so the
/// editor's attributed text can be serialized back to `![](fern://name)`.
final class PhotoAttachment: NSTextAttachment {
    let filename: String
    init(filename: String) { self.filename = filename; super.init(data: nil, ofType: nil) }
    required init?(coder: NSCoder) { self.filename = ""; super.init(coder: coder) }
}

/// Bridges the Markdown body (with `fern://` photo tokens) to the live editor's
/// attributed text (with inline image attachments) and back. Lets you *see*
/// embedded photos while writing while keeping the stored document plain
/// Markdown.
enum EditorPhotos {

    /// Markdown → attributed text: photo tokens become inline image attachments,
    /// everything else is styled by `MarkdownStyler`.
    static func attributed(fromMarkdown md: String, width: CGFloat) -> NSAttributedString {
        let result = NSMutableAttributedString()
        for seg in PhotoToken.segments(md) {
            switch seg {
            case .text(let t):
                result.append(MarkdownStyler.attributed(for: t))
            case .photo(let name):
                result.append(NSAttributedString(attachment: attachment(name, width: width)))
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
    static func attachment(_ name: String, width: CGFloat) -> PhotoAttachment {
        let att = PhotoAttachment(filename: name)
        if let img = PhotoStore.load(name) {
            let w = max(1, min(width, img.size.width))
            let h = img.size.height * (w / img.size.width)
            att.image = rounded(img, size: CGSize(width: w, height: h))
            att.bounds = CGRect(x: 0, y: 0, width: w, height: h)
        } else {
            att.bounds = CGRect(x: 0, y: 0, width: width, height: 44)
        }
        return att
    }

    private static func rounded(_ image: UIImage, size: CGSize, radius: CGFloat = 14) -> UIImage {
        UIGraphicsImageRenderer(size: size).image { _ in
            let rect = CGRect(origin: .zero, size: size)
            UIBezierPath(roundedRect: rect, cornerRadius: radius).addClip()
            image.draw(in: rect)
        }
    }
}
