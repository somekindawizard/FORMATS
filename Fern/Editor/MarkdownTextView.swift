import SwiftUI
import UIKit

/// SwiftUI wrapper around UITextView (TextKit 2) that styles Markdown
/// inline as it's typed: headings/bold/italic/code/lists/blockquotes
/// render in their target font while the syntax marks stay visible
/// in faint ink. Two-way bound to a String.
struct MarkdownTextView: UIViewRepresentable {
    @Binding var text: String

    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView(usingTextLayoutManager: true) // TextKit 2
        tv.delegate = context.coordinator
        tv.backgroundColor = .clear
        tv.textContainerInset = UIEdgeInsets(top: 8, left: 4, bottom: 80, right: 4)
        tv.textContainer.lineFragmentPadding = 0
        tv.alwaysBounceVertical = true
        tv.autocorrectionType = .yes
        tv.smartQuotesType = .yes
        tv.smartDashesType = .yes
        tv.tintColor = MarkdownTheme.accent
        tv.allowsEditingTextAttributes = false
        tv.attributedText = MarkdownStyler.attributed(for: text)
        return tv
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        // Only re-style when the source string differs from what the view shows.
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
            let newText = textView.text ?? ""
            parent.text = newText
            // Re-style preserving the caret.
            let selected = textView.selectedRange
            let styled = MarkdownStyler.attributed(for: newText)
            if styled.string != textView.attributedText.string ||
               !attributesEqual(styled, textView.attributedText) {
                textView.attributedText = styled
                textView.selectedRange = selected
            }
        }

        private func attributesEqual(_ a: NSAttributedString, _ b: NSAttributedString) -> Bool {
            guard a.length == b.length else { return false }
            // Cheap shallow equality: compare a few stride samples.
            let stride = max(1, a.length / 8)
            for i in Swift.stride(from: 0, to: a.length, by: stride) {
                if a.attributes(at: i, effectiveRange: nil) as NSDictionary !=
                   b.attributes(at: i, effectiveRange: nil) as NSDictionary {
                    return false
                }
            }
            return true
        }
    }
}
