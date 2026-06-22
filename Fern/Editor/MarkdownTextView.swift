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

    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView(usingTextLayoutManager: true) // TextKit 2
        tv.delegate = context.coordinator
        controller?.textView = tv
        tv.backgroundColor = .clear
        tv.textContainerInset = UIEdgeInsets(top: 8, left: 4, bottom: 80, right: 4)
        tv.textContainer.lineFragmentPadding = 0
        tv.alwaysBounceVertical = true
        tv.autocorrectionType = .yes
        tv.smartQuotesType = .yes
        tv.smartDashesType = .yes
        tv.tintColor = MarkdownTheme.accent
        tv.allowsEditingTextAttributes = false
        tv.typingAttributes = MarkdownStyler.baseAttributes()
        tv.attributedText = MarkdownStyler.attributed(for: text)
        return tv
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        // Only when the source string changes from outside the view (e.g. the
        // accessory bar inserting Markdown). Not during normal typing.
        if uiView.text != text {
            let selected = uiView.selectedRange
            uiView.attributedText = MarkdownStyler.attributed(for: text)
            uiView.selectedRange = selected
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: MarkdownTextView
        init(parent: MarkdownTextView) { self.parent = parent }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text ?? ""
            restyle(textView)
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

            let selected = textView.selectedRange
            let whole = NSRange(location: 0, length: storage.length)
            storage.beginEditing()
            storage.setAttributes(MarkdownStyler.baseAttributes(), range: whole)
            styled.enumerateAttributes(in: whole, options: []) { attrs, range, _ in
                storage.addAttributes(attrs, range: range)
            }
            storage.endEditing()
            textView.selectedRange = selected
            textView.typingAttributes = MarkdownStyler.baseAttributes()
        }
    }
}
