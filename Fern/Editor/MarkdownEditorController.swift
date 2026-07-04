import UIKit
import Observation

/// Bridges the accessory bar to the live `UITextView` so formatting acts on the
/// current selection / caret instead of appending at the end. Also surfaces the
/// word under the caret so the synonym strip can offer alternatives.
@Observable
final class MarkdownEditorController {
    @ObservationIgnored weak var textView: UITextView?

    /// The word the caret currently sits in (empty when between words). Observed
    /// by the synonym strip.
    var currentWord: String = ""

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

    /// Insert a prefix at the start of the caret's current line (for headings/quotes).
    func prefixLine(_ s: String) {
        guard let tv = textView, let sel = tv.selectedTextRange else { return }
        let caretOffset = tv.offset(from: tv.beginningOfDocument, to: sel.start)
        let ns = (tv.text ?? "") as NSString
        var lineStart = caretOffset
        while lineStart > 0 && ns.character(at: lineStart - 1) != 10 { lineStart -= 1 }
        if let pos = tv.position(from: tv.beginningOfDocument, offset: lineStart),
           let r = tv.textRange(from: pos, to: pos) {
            tv.replace(r, withText: s)
            notifyChange(tv)
        }
    }

    func dismissKeyboard() { textView?.resignFirstResponder() }

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
