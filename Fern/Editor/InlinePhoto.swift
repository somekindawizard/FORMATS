import SwiftUI

/// Photos embedded in the body are written as a Markdown image with a custom
/// scheme — `![](fern://<filename>)` — so the document stays plain, portable
/// Markdown while Fern knows how to resolve and lay them out inline.
enum PhotoToken {
    static func make(_ name: String) -> String { "\n\n![](fern://\(name))\n\n" }

    /// Captures the filename inside a `fern://` image.
    static let pattern = #"!\[[^\]]*\]\(fern://([^)]+)\)"#

    enum Segment {
        case text(String)
        case photo(String)
    }

    /// Split a body into interleaved text runs and inline photos.
    static func segments(_ body: String) -> [Segment] {
        guard let re = try? NSRegularExpression(pattern: pattern) else { return [.text(body)] }
        let ns = body as NSString
        var out: [Segment] = []
        var cursor = 0
        re.enumerateMatches(in: body, range: NSRange(location: 0, length: ns.length)) { m, _, _ in
            guard let m else { return }
            if m.range.location > cursor {
                out.append(.text(ns.substring(with: NSRange(location: cursor,
                                                            length: m.range.location - cursor))))
            }
            out.append(.photo(ns.substring(with: m.range(at: 1))))
            cursor = NSMaxRange(m.range)
        }
        if cursor < ns.length { out.append(.text(ns.substring(from: cursor))) }
        return out
    }
}

/// An inline photo with rounded corners and an optional theme-toned wash: the
/// image is desaturated to black-and-white, then tinted into the app's accent
/// hue (kept low so it sits in the same muted value space as the theme).
struct WashedImage: View {
    let name: String
    var wash: Bool
    var cornerRadius: CGFloat = 16

    private var image: UIImage? {
        guard let ui = PhotoStore.load(name) else { return nil }
        return wash ? EditorPhotos.washed(ui) : ui
    }

    var body: some View {
        if let image {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Paper.line, lineWidth: 1))
        }
    }
}

/// The reading-mode body: text runs rendered as clean Markdown with inline
/// photos placed where they sit in the document.
struct RenderedBody: View {
    let markdown: String
    let wash: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            ForEach(Array(PhotoToken.segments(markdown).enumerated()), id: \.offset) { _, seg in
                switch seg {
                case .text(let t):
                    let trimmed = t.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        Text(MarkdownRender.styled(trimmed, ReadingView.readerStyle))
                            .lineSpacing(6)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                case .photo(let name):
                    WashedImage(name: name, wash: wash)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
    }
}
