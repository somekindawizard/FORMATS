import SwiftUI
import UIKit

/// Renders the opening prose block with a true floated **drop cap** — a large
/// initial the body text wraps around, via a TextKit exclusion path. (SwiftUI's
/// `Text` can't float, hence a `UITextView`.)
struct DropCapText: UIViewRepresentable {
    let markdown: String

    func makeCoordinator() -> Coordinator { Coordinator() }
    final class Coordinator { let cap = UILabel() }

    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView(usingTextLayoutManager: false)  // TextKit 1 — reliable exclusion paths
        tv.isEditable = false
        tv.isScrollEnabled = false
        tv.backgroundColor = .clear
        tv.textContainerInset = .zero
        tv.textContainer.lineFragmentPadding = 0
        tv.tintColor = MarkdownTheme.accent
        tv.addSubview(context.coordinator.cap)
        configure(tv, context.coordinator)
        return tv
    }

    func updateUIView(_ tv: UITextView, context: Context) { configure(tv, context.coordinator) }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        let width = proposal.width ?? uiView.bounds.width
        let fit = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return CGSize(width: width, height: fit.height)
    }

    private func configure(_ tv: UITextView, _ coord: Coordinator) {
        let full = DropCapRenderer.attributed(markdown)
        let ns = full.string as NSString

        var capIndex = 0
        while capIndex < ns.length {
            if let u = UnicodeScalar(ns.character(at: capIndex)), CharacterSet.letters.contains(u) { break }
            capIndex += 1
        }
        guard capIndex < ns.length else {
            tv.attributedText = full
            coord.cap.isHidden = true
            tv.textContainer.exclusionPaths = []
            return
        }

        let capLetter = ns.substring(with: NSRange(location: capIndex, length: 1))
        let body = NSMutableAttributedString(attributedString: full)
        body.deleteCharacters(in: NSRange(location: capIndex, length: 1))
        tv.attributedText = body

        let bodyFont = MarkdownTheme.body()
        let lineH = bodyFont.lineHeight
        let capSize = lineH * 2.7
        let capFont = UIFont(name: "Fraunces", size: capSize)
            ?? UIFont(descriptor: (UIFont.systemFont(ofSize: capSize, weight: .semibold)
                .fontDescriptor.withDesign(.serif) ?? UIFont.systemFont(ofSize: capSize).fontDescriptor),
                      size: capSize)

        coord.cap.isHidden = false
        coord.cap.text = capLetter
        coord.cap.font = capFont
        coord.cap.textColor = MarkdownTheme.accent

        let capW = ceil((capLetter as NSString).size(withAttributes: [.font: capFont]).width)
        // Wrap the body around the cap for ~2 lines.
        tv.textContainer.exclusionPaths = [
            UIBezierPath(rect: CGRect(x: 0, y: 0, width: capW + 10, height: lineH * 2.0))
        ]
        // Align the cap's cap-height with the first line's cap-height.
        let yOffset = (bodyFont.ascender - bodyFont.capHeight) - (capFont.ascender - capFont.capHeight)
        coord.cap.frame = CGRect(x: 0, y: yOffset, width: capW + 10, height: capSize)
    }
}

/// A compact UIKit renderer for the drop-cap block: strips Markdown syntax and
/// applies inline emphasis, matching the reader's serif look.
enum DropCapRenderer {
    static func attributed(_ text: String) -> NSMutableAttributedString {
        let para = NSMutableParagraphStyle()
        para.lineSpacing = 6
        para.paragraphSpacing = 8
        let base: [NSAttributedString.Key: Any] = [
            .font: MarkdownTheme.body(),
            .foregroundColor: MarkdownTheme.ink,
            .paragraphStyle: para
        ]
        let out = NSMutableAttributedString()
        let chars = Array(text)
        var i = 0
        var plain = ""
        func flush() {
            if !plain.isEmpty { out.append(NSAttributedString(string: plain, attributes: base)); plain = "" }
        }
        func starts(_ d: [Character], _ idx: Int) -> Bool {
            idx + d.count <= chars.count && Array(chars[idx..<idx + d.count]) == d
        }
        func indexOf(_ ch: Character, _ from: Int) -> Int? {
            var k = from; while k < chars.count { if chars[k] == ch { return k }; k += 1 }; return nil
        }
        let markers = ["**", "~~", "==", "`", "*"]
        while i < chars.count {
            // Links
            if chars[i] == "[", !(i > 0 && chars[i - 1] == "!"),
               let close = indexOf("]", i + 1), close + 1 < chars.count, chars[close + 1] == "(",
               let paren = indexOf(")", close + 2) {
                flush()
                let label = String(chars[(i + 1)..<close])
                let a = NSMutableAttributedString(string: label, attributes: base)
                let r = NSRange(location: 0, length: a.length)
                a.addAttribute(.foregroundColor, value: MarkdownTheme.accent, range: r)
                a.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: r)
                if let u = URL(string: String(chars[(close + 2)..<paren])) { a.addAttribute(.link, value: u, range: r) }
                out.append(a); i = paren + 1; continue
            }
            if let d = markers.first(where: { starts(Array($0), i) }) {
                let dc = Array(d); let open = i + dc.count
                var j = open; var closeIdx = -1
                while j < chars.count { if starts(dc, j) { closeIdx = j; break }; j += 1 }
                if closeIdx >= 0 {
                    flush()
                    let a = NSMutableAttributedString(string: String(chars[open..<closeIdx]), attributes: base)
                    let r = NSRange(location: 0, length: a.length)
                    switch d {
                    case "**": a.addAttribute(.font, value: MarkdownTheme.bold(), range: r)
                    case "*":  a.addAttribute(.font, value: MarkdownTheme.italic(), range: r)
                    case "~~": a.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: r)
                    case "==": a.addAttribute(.backgroundColor, value: MarkdownTheme.accent.withAlphaComponent(0.18), range: r)
                    case "`":  a.addAttribute(.font, value: MarkdownTheme.mono(), range: r)
                    default: break
                    }
                    out.append(a); i = closeIdx + dc.count; continue
                }
            }
            plain.append(chars[i]); i += 1
        }
        flush()
        return out
    }
}
