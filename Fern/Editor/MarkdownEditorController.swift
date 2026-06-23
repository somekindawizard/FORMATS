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

    // MARK: - Synonyms

    /// Recompute `currentWord` from the caret. Called on selection/text changes.
    func refreshCurrentWord() {
        currentWord = wordRange()?.text ?? ""
    }

    /// Replace the caret's word, matching the original's capitalization.
    func replaceCurrentWord(with replacement: String) {
        guard let tv = textView, let found = wordRange() else { return }
        tv.replace(found.range, withText: matchCase(of: found.text, to: replacement))
        notifyChange(tv)
        refreshCurrentWord()
    }

    /// The word range enclosing (or just behind) the caret, with its text.
    private func wordRange() -> (range: UITextRange, text: String)? {
        guard let tv = textView, let sel = tv.selectedTextRange,
              let range = tv.tokenizer.rangeEnclosingPosition(
                sel.end, with: .word, inDirection: .storage(.backward)),
              let text = tv.text(in: range), !text.isEmpty
        else { return nil }
        return (range, text)
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
