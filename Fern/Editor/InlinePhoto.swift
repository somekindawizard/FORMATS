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
}

struct RenderedBody: View {
    let markdown: String
    let wash: Bool
    @Environment(\.horizontalSizeClass) private var sizeClass

    private var blocks: [ReaderBlock] { RenderedBody.blocks(markdown) }
    private var firstTextIndex: Int? {
        blocks.firstIndex { if case .text = $0 { return true } else { return false } }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { i, block in
                switch block {
                case .text(let s):
                    Text(RenderedBody.styled(s, dropCap: i == firstTextIndex))
                        .lineSpacing(6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                case .photo(let name):
                    WashedImage(name: name, wash: wash)
                        .frame(maxWidth: sizeClass == .regular ? 460 : .infinity)
                        .frame(maxWidth: .infinity, alignment: .center)
                case .caption(let s):
                    Text(s)
                        .font(.calloutSerif).italic()
                        .foregroundStyle(Paper.inkSoft)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, -8)
                case .rule:
                    Image(systemName: "leaf")
                        .font(.system(size: 13))
                        .foregroundStyle(Paper.inkFaint)
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
                func flush() {
                    let s = buffer.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
                    if !s.isEmpty { out.append(.text(s)) }
                    buffer = []
                }
                for line in text.components(separatedBy: "\n") {
                    let t = line.trimmingCharacters(in: .whitespaces)
                    if t.count >= 3, Set(t).count == 1, "-*_".contains(t.first!) {
                        flush(); out.append(.rule)
                    } else if t.hasPrefix("// ") {
                        flush(); out.append(.caption(String(t.dropFirst(3))))
                    } else {
                        buffer.append(line)
                    }
                }
                flush()
            }
        }
        return out
    }

    /// Render a prose block; optionally raise a decorative initial (drop cap).
    static func styled(_ s: String, dropCap: Bool) -> AttributedString {
        var a = MarkdownRender.styled(s, ReadingView.readerStyle)
        guard dropCap, !s.hasPrefix("#"),
              let idx = a.characters.firstIndex(where: { $0.isLetter }) else { return a }
        let next = a.index(afterCharacter: idx)
        a[idx..<next].font = .custom("Fraunces", size: 46).weight(.semibold)
        a[idx..<next].foregroundColor = Paper.accent
        return a
    }
}
