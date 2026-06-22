import UIKit

/// Bridges the accessory bar to the live `UITextView` so formatting acts on the
/// current selection / caret instead of appending at the end.
final class MarkdownEditorController {
    weak var textView: UITextView?

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

    private func notifyChange(_ tv: UITextView) {
        tv.delegate?.textViewDidChange?(tv)
    }
}
