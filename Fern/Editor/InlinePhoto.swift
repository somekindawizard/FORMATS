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
/// A block in reading mode: a run of prose, a photo, a section fleuron, or a
/// centered figure caption.
enum ReaderBlock {
    case text(String)
    case photo(String)
    case rule
    case caption(String)
    case quote(String)   // raw "> …" lines, rendered centered italic
}

struct RenderedBody: View {
    let markdown: String
    let wash: Bool
    /// Typography/colors — reader defaults; the share card passes a larger, fixed-light style.
    var style: MarkdownRender.Style = ReadingView.readerStyle
    /// Disabled for PDF export / the card (ImageRenderer can't snapshot the UIKit drop cap).
    var dropCap: Bool = true
    /// Fixed inline-photo width (card). When nil, adapts to the size class.
    var photoWidth: CGFloat? = nil
    var captionFont: Font = .calloutSerif
    var ruleSize: CGFloat = 13
    var spacing: CGFloat = 16
    @Environment(\.horizontalSizeClass) private var sizeClass

    private var blocks: [ReaderBlock] { RenderedBody.blocks(markdown) }
    private var firstTextIndex: Int? {
        blocks.firstIndex { if case .text = $0 { return true } else { return false } }
    }
    private var resolvedPhotoWidth: CGFloat? {
        photoWidth ?? (sizeClass == .regular ? 460 : nil)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: spacing) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { i, block in
                switch block {
                case .text(let s):
                    if dropCap && i == firstTextIndex && RenderedBody.dropCapEligible(s) {
                        DropCapText(markdown: s)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        Text(MarkdownRender.styled(s, style))
                            .lineSpacing(6)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                case .photo(let name):
                    WashedImage(name: name, wash: wash)
                        .frame(maxWidth: resolvedPhotoWidth ?? .infinity)
                        .frame(maxWidth: .infinity, alignment: .center)
                case .quote(let s):
                    Text(MarkdownRender.styled(s, style))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 4)
                case .caption(let s):
                    Text(s)
                        .font(captionFont).italic()
                        .foregroundStyle(style.soft)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, -8)
                case .rule:
                    Image(systemName: "leaf")
                        .font(.system(size: ruleSize))
                        .foregroundStyle(style.soft)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 8)
                }
            }
        }
    }

    // MARK: block parsing

    static func blocks(_ markdown: String) -> [ReaderBlock] {
        var out: [ReaderBlock] = []
        for seg in PhotoToken.segments(markdown) {
            switch seg {
            case .photo(let name):
                out.append(.photo(name))
            case .text(let text):
                var buffer: [String] = []
                var quoteBuffer: [String] = []
                func flushText() {
                    let s = buffer.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
                    if !s.isEmpty { out.append(.text(s)) }
                    buffer = []
                }
                func flushQuote() {
                    if !quoteBuffer.isEmpty { out.append(.quote(quoteBuffer.joined(separator: "\n"))) }
                    quoteBuffer = []
                }
                for line in text.components(separatedBy: "\n") {
                    let t = line.trimmingCharacters(in: .whitespaces)
                    if t.hasPrefix(">") {
                        flushText(); quoteBuffer.append(t)
                    } else if t.count >= 3, Set(t).count == 1, "-*_".contains(t.first!) {
                        flushText(); flushQuote(); out.append(.rule)
                    } else if t.hasPrefix("// ") {
                        flushText(); flushQuote(); out.append(.caption(String(t.dropFirst(3))))
                    } else {
                        flushQuote(); buffer.append(line)
                    }
                }
                flushText(); flushQuote()
            }
        }
        return out
    }

    /// A block can open with a drop cap if it's plain prose (not a heading/list).
    static func dropCapEligible(_ s: String) -> Bool {
        let t = s.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty, !t.hasPrefix("#"), !t.hasPrefix(">"),
              t.range(of: #"^([-*+]|\d+\.)\s"#, options: .regularExpression) == nil
        else { return false }
        return t.contains(where: { $0.isLetter })
    }
}
