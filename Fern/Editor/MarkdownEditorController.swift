import UIKit
import Observation
import PencilKit

/// Bridges the accessory bar to the live `UITextView` so formatting acts on the
/// current selection / caret instead of appending at the end. Also surfaces the
/// word under the caret so the synonym strip can offer alternatives, and hosts
/// the Apple Pencil ink layer over the page.
@Observable
final class MarkdownEditorController {
    @ObservationIgnored weak var textView: UITextView?

    // Ink layer — a PencilKit canvas overlaid on the text (see InkTools.swift).
    @ObservationIgnored var canvas: PKCanvasView?
    @ObservationIgnored var drawingEntryID: UUID?
    @ObservationIgnored var contentSizeObservation: NSKeyValueObservation?
    @ObservationIgnored var inkCoordinator: InkCoordinator?
    @ObservationIgnored var pencilCoordinator: PencilInteractionCoordinator?
    /// The last pen used before switching to the eraser (for double-tap toggle).
    @ObservationIgnored var previousPen: InkSettings.Pen = .pen
    /// Set by a Pencil squeeze / palette action to present the color wheel.
    var showColorWheel = false
    /// True while the ink layer is capturing Pencil input (drawing mode).
    var isDrawing = false
    /// When on, PencilKit's ruler is shown for straight lines.
    var showRuler = false
    /// The current pen/color/width selection.
    var ink = InkSettings()

    /// The word the caret currently sits in (empty when between words). Observed
    /// by the synonym strip.
    var currentWord: String = ""

    /// Whether inline photos should render in the theme-toned wash (mirrors the
    /// entry setting; used when inserting a new photo).
    @ObservationIgnored var photoWash = false

    /// Wrap the selection in a symmetric marker (e.g. ** or *). With no
    /// selection, insert the pair and place the caret between them.
    func wrap(_ marker: String) { wrapPair(marker, marker) }

    func wrapPair(_ open: String, _ close: String) {
        guard let tv = textView, let range = tv.selectedTextRange else { return }
        let selected = tv.text(in: range) ?? ""
        tv.replace(range, withText: open + selected + close)
        if selected.isEmpty,
           let caret = tv.selectedTextRange?.start,
           let between = tv.position(from: caret, offset: -close.count),
           let r = tv.textRange(from: between, to: between) {
            tv.selectedTextRange = r
        }
        notifyChange(tv)
    }

    /// Insert text at the caret (replacing any selection).
    func insert(_ s: String) {
        guard let tv = textView, let range = tv.selectedTextRange else { return }
        tv.replace(range, withText: s)
        notifyChange(tv)
    }

    // MARK: - Line-level formatting

    /// Any leading block marker we recognize, so toggling one replaces another.
    private static let markerPattern = "^(#{1,6} |> |- \\[[ xX]\\] |[-*+] |\\d+\\. )"

    /// Toggle a block prefix on the caret's line. If the line already starts
    /// with `prefix`, strip it; otherwise replace whatever marker is there.
    func setLinePrefix(_ prefix: String) {
        guard let tv = textView, let lineRange = currentLineRange(tv) else { return }
        let ns = (tv.text ?? "") as NSString
        let full = ns.substring(with: lineRange)
        let hadNewline = full.hasSuffix("\n")
        let core = hadNewline ? String(full.dropLast()) : full

        var existing = "", body = core
        if let r = core.range(of: Self.markerPattern, options: .regularExpression) {
            existing = String(core[r]); body = String(core[r.upperBound...])
        }
        let newCore = (existing == prefix) ? body : prefix + body
        replaceRange(lineRange, with: newCore + (hadNewline ? "\n" : ""), tv)
    }

    /// Cycle the caret line through no-heading → # → ## → ### → none.
    func cycleHeading() {
        guard let tv = textView, let lineRange = currentLineRange(tv) else { return }
        let core = ((tv.text ?? "") as NSString).substring(with: lineRange)
            .trimmingCharacters(in: .newlines)
        let hashes = core.prefix { $0 == "#" }.count
        let next = ["# ", "## ", "### ", ""][min(hashes, 3)]
        // Strip existing heading then apply next.
        setLinePrefixExact(heading: next)
    }

    /// Toggle a to-do line between unchecked and checked (or add one).
    func toggleTask() {
        guard let tv = textView, let lineRange = currentLineRange(tv) else { return }
        let core = ((tv.text ?? "") as NSString).substring(with: lineRange)
        if core.contains("- [ ] ") { replaceMarker("- [ ] ", "- [x] ", lineRange, tv) }
        else if core.localizedCaseInsensitiveContains("- [x] ") { replaceMarker("- [x] ", "- [ ] ", lineRange, tv) }
        else { setLinePrefix("- [ ] ") }
    }

    /// A thematic break on its own line.
    func insertRule() { insert("\n---\n") }

    /// Wrap the selection as a Markdown link, or drop a placeholder.
    func insertLink() {
        guard let tv = textView, let range = tv.selectedTextRange else { return }
        let text = tv.text(in: range) ?? ""
        let label = text.isEmpty ? "text" : text
        tv.replace(range, withText: "[\(label)](url)")
        notifyChange(tv)
    }

    // MARK: line helpers

    private func setLinePrefixExact(heading: String) {
        guard let tv = textView, let lineRange = currentLineRange(tv) else { return }
        let ns = (tv.text ?? "") as NSString
        let full = ns.substring(with: lineRange)
        let hadNewline = full.hasSuffix("\n")
        var core = hadNewline ? String(full.dropLast()) : full
        if let r = core.range(of: "^#{1,6} ", options: .regularExpression) {
            core = String(core[r.upperBound...])
        }
        replaceRange(lineRange, with: heading + core + (hadNewline ? "\n" : ""), tv)
    }

    private func replaceMarker(_ from: String, _ to: String, _ lineRange: NSRange, _ tv: UITextView) {
        let ns = (tv.text ?? "") as NSString
        let full = ns.substring(with: lineRange)
        replaceRange(lineRange, with: full.replacingOccurrences(of: from, with: to,
                                                                options: .caseInsensitive), tv)
    }

    private func currentLineRange(_ tv: UITextView) -> NSRange? {
        guard let sel = tv.selectedTextRange else { return nil }
        let caret = tv.offset(from: tv.beginningOfDocument, to: sel.start)
        let ns = (tv.text ?? "") as NSString
        return ns.lineRange(for: NSRange(location: min(caret, ns.length), length: 0))
    }

    private func replaceRange(_ nsRange: NSRange, with text: String, _ tv: UITextView) {
        guard let start = tv.position(from: tv.beginningOfDocument, offset: nsRange.location),
              let end = tv.position(from: start, offset: nsRange.length),
              let r = tv.textRange(from: start, to: end) else { return }
        tv.replace(r, withText: text)
        notifyChange(tv)
    }

    func dismissKeyboard() { textView?.resignFirstResponder() }

    /// Insert an inline photo (as an image attachment) at the caret. Serializes
    /// back to a `![](fern://name)` token via the text view's delegate.
    func insertPhoto(_ name: String) {
        guard let tv = textView, let sel = tv.selectedTextRange else { return }
        let loc = tv.offset(from: tv.beginningOfDocument, to: sel.start)
        let len = tv.offset(from: sel.start, to: sel.end)
        let width = MarkdownTextView.contentWidth(tv)
        let piece = NSMutableAttributedString(string: "\n", attributes: MarkdownStyler.baseAttributes())
        piece.append(NSAttributedString(attachment: EditorPhotos.attachment(name, width: width, wash: photoWash)))
        piece.append(NSAttributedString(string: "\n", attributes: MarkdownStyler.baseAttributes()))
        tv.textStorage.replaceCharacters(in: NSRange(location: loc, length: len), with: piece)
        if let pos = tv.position(from: tv.beginningOfDocument, offset: loc + piece.length) {
            tv.selectedTextRange = tv.textRange(from: pos, to: pos)
        }
        notifyChange(tv)
    }

    // MARK: - Synonyms

    /// Recompute `currentWord` from the caret. Called on selection/text changes.
    func refreshCurrentWord() {
        currentWord = wordRange()?.text ?? ""
    }

    /// Replace the caret's word, matching the original's capitalization.
    func replaceCurrentWord(with replacement: String) {
        guard let tv = textView, let found = wordRange(),
              let start = tv.position(from: tv.beginningOfDocument, offset: found.nsRange.location),
              let end = tv.position(from: start, offset: found.nsRange.length),
              let textRange = tv.textRange(from: start, to: end) else { return }
        tv.replace(textRange, withText: matchCase(of: found.text, to: replacement))
        notifyChange(tv)
        refreshCurrentWord()
    }

    /// The word straddling the caret, found by scanning outward over letters —
    /// deterministic where `tokenizer.rangeEnclosingPosition` returns nil at a
    /// word boundary (which quietly broke the synonym strip).
    private func wordRange() -> (nsRange: NSRange, text: String)? {
        guard let tv = textView, let sel = tv.selectedTextRange else { return nil }
        let caret = tv.offset(from: tv.beginningOfDocument, to: sel.end)
        let ns = (tv.text ?? "") as NSString
        func isWordChar(_ i: Int) -> Bool {
            guard i >= 0, i < ns.length, let u = Unicode.Scalar(ns.character(at: i)) else { return false }
            return CharacterSet.letters.contains(u) || u == "'" || u == "\u{2019}"
        }
        var lo = min(caret, ns.length), hi = min(caret, ns.length)
        while lo > 0 && isWordChar(lo - 1) { lo -= 1 }
        while hi < ns.length && isWordChar(hi) { hi += 1 }
        guard hi > lo else { return nil }
        let range = NSRange(location: lo, length: hi - lo)
        return (range, ns.substring(with: range))
    }

    /// Carry the original word's case onto the replacement (Title → Title, ALL → ALL).
    private func matchCase(of original: String, to replacement: String) -> String {
        if original == original.uppercased() && original.count > 1 {
            return replacement.uppercased()
        }
        if let first = original.first, first.isUppercase {
            return replacement.prefix(1).uppercased() + replacement.dropFirst()
        }
        return replacement
    }

    private func notifyChange(_ tv: UITextView) {
        tv.delegate?.textViewDidChange?(tv)
    }
}
