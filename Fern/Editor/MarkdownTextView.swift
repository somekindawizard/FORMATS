import SwiftUI
import UIKit

/// SwiftUI wrapper around UITextView that styles Markdown inline as it's typed.
///
/// Critically, styling is applied **in place** — we only change attributes on
/// the existing text storage, never reassign the string. Reassigning the
/// string on each keystroke (as an earlier version did) collapsed spaces and
/// reflowed lines because the Markdown was being re-rendered. Here the user's
/// exact characters are untouched.
struct MarkdownTextView: UIViewRepresentable {
    @Binding var text: String
    var controller: MarkdownEditorController? = nil
    /// Render inline photos in the theme-toned wash.
    var wash: Bool = false
    /// Entry id, so the Pencil ink layer can persist per note.
    var entryID: UUID? = nil

    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView(usingTextLayoutManager: true) // TextKit 2
        tv.delegate = context.coordinator
        context.coordinator.lastWash = wash
        controller?.textView = tv
        controller?.photoWash = wash
        tv.backgroundColor = .clear
        tv.textContainerInset = UIEdgeInsets(top: 8, left: 4, bottom: 80, right: 4)
        tv.textContainer.lineFragmentPadding = 0
        tv.alwaysBounceVertical = true
        tv.autocorrectionType = .yes
        tv.smartQuotesType = .yes
        tv.smartDashesType = .yes
        tv.tintColor = MarkdownTheme.accent
        tv.allowsEditingTextAttributes = false
        tv.isFindInteractionEnabled = true   // native find & replace
        tv.typingAttributes = MarkdownStyler.baseAttributes()
        tv.attributedText = EditorPhotos.attributed(fromMarkdown: text, width: Self.contentWidth(tv), wash: wash)
        if let entryID { controller?.setupCanvas(on: tv, entryID: entryID) }
        return tv
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        controller?.photoWash = wash
        // Rebuild when the source changed from outside the view (e.g. loading a
        // note) or when the photo wash toggled. Compare serialized Markdown so
        // inline photo attachments don't read as a perpetual mismatch.
        let washChanged = context.coordinator.lastWash != wash
        if washChanged || EditorPhotos.markdown(from: uiView.attributedText) != text {
            context.coordinator.lastWash = wash
            let selected = uiView.selectedRange
            uiView.attributedText = EditorPhotos.attributed(fromMarkdown: text,
                                                            width: Self.contentWidth(uiView), wash: wash)
            let len = uiView.textStorage.length
            uiView.selectedRange = NSRange(location: min(selected.location, len), length: 0)
        }
    }

    /// Usable text width, for sizing inline image attachments. Falls back to the
    /// screen width (minus the editor's padding) before the view has laid out,
    /// so photos in a freshly-opened note aren't sized tiny.
    static func contentWidth(_ tv: UITextView) -> CGFloat {
        let container = tv.textContainer.size.width
        if container > 0 {
            return max(80, container - tv.textContainerInset.left - tv.textContainerInset.right)
        }
        return max(80, UIScreen.main.bounds.width - 52)
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: MarkdownTextView
        var lastWash = false
        init(parent: MarkdownTextView) { self.parent = parent }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = EditorPhotos.markdown(from: textView.attributedText)
            restyle(textView)
            parent.controller?.refreshCurrentWord()
            if ThemeStore.shared.typewriter { centerCaret(textView) }
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            parent.controller?.refreshCurrentWord()
            // Focus mode re-dims around the paragraph the caret moved into.
            if ThemeStore.shared.focusMode { restyle(textView) }
            if ThemeStore.shared.typewriter { centerCaret(textView) }
        }

        /// Keep the caret line vertically centered (typewriter scrolling).
        private func centerCaret(_ tv: UITextView) {
            guard let range = tv.selectedTextRange else { return }
            let caret = tv.caretRect(for: range.end)
            guard caret.midY.isFinite else { return }
            let target = caret.midY - tv.bounds.height / 2
            let maxY = max(0, tv.contentSize.height - tv.bounds.height + tv.contentInset.bottom)
            let y = min(max(target, -tv.contentInset.top), maxY)
            tv.setContentOffset(CGPoint(x: 0, y: y), animated: false)
        }

        /// Re-apply Markdown attributes over the existing characters.
        private func restyle(_ textView: UITextView) {
            // Don't disturb in-progress composition (emoji, CJK, autocorrect).
            guard textView.markedTextRange == nil else { return }

            let source = textView.text ?? ""
            let styled = MarkdownStyler.attributed(for: source)
            let storage = textView.textStorage

            // The styler preserves the string exactly, so lengths match and we
            // can swap attributes without touching characters or the caret.
            guard styled.length == storage.length else {
                let sel = textView.selectedRange
                textView.attributedText = styled
                textView.selectedRange = sel
                return
            }

            // Snapshot inline photo attachments — the base-attribute reset below
            // would otherwise strip them off their U+FFFC characters.
            var attachments: [(Int, PhotoAttachment)] = []
            storage.enumerateAttribute(.attachment, in: NSRange(location: 0, length: storage.length)) { v, r, _ in
                if let a = v as? PhotoAttachment { attachments.append((r.location, a)) }
            }

            let selected = textView.selectedRange
            let whole = NSRange(location: 0, length: storage.length)
            storage.beginEditing()
            storage.setAttributes(MarkdownStyler.baseAttributes(), range: whole)
            styled.enumerateAttributes(in: whole, options: []) { attrs, range, _ in
                storage.addAttributes(attrs, range: range)
            }
            let centered = NSMutableParagraphStyle()
            centered.alignment = .center
            centered.paragraphSpacing = 6
            centered.paragraphSpacingBefore = 6
            let nsString = storage.string as NSString
            for (loc, a) in attachments where loc < storage.length {
                storage.addAttribute(.attachment, value: a, range: NSRange(location: loc, length: 1))
                // Center the photo on its own line, magazine-style.
                let para = nsString.paragraphRange(for: NSRange(location: loc, length: 0))
                storage.addAttribute(.paragraphStyle, value: centered, range: para)
            }
            storage.endEditing()
            textView.selectedRange = selected
            textView.typingAttributes = MarkdownStyler.baseAttributes()

            if ThemeStore.shared.focusMode { applyFocus(textView) }
        }

        /// Dim everything but the caret's paragraph.
        private func applyFocus(_ textView: UITextView) {
            let storage = textView.textStorage
            let ns = storage.string as NSString
            let para = ns.paragraphRange(for: textView.selectedRange)
            let dim = MarkdownTheme.ink.withAlphaComponent(0.22)
            if para.location > 0 {
                storage.addAttribute(.foregroundColor, value: dim,
                                     range: NSRange(location: 0, length: para.location))
            }
            let after = NSMaxRange(para)
            if after < storage.length {
                storage.addAttribute(.foregroundColor, value: dim,
                                     range: NSRange(location: after, length: storage.length - after))
            }
        }
    }
}
