import SwiftUI
import UIKit

/// A distraction-free, read-only view of an entry — the Markdown rendered and
/// typeset, no editing chrome.
struct ReadingView: View {
    let entry: Entry

    var body: some View {
        ZStack {
            PaperBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text(entry.createdAt.formatted(.dateTime.weekday(.wide).month(.wide).day().year()))
                        .sectionLabel()
                    if !entry.title.trimmingCharacters(in: .whitespaces).isEmpty {
                        Text(entry.title)
                            .font(.masthead)
                            .foregroundStyle(Paper.ink)
                    }
                    ReadingText(markdown: entry.body)
                }
                .padding(.horizontal, 26)
                .padding(.top, 12)
                .padding(.bottom, 60)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// A self-sizing, non-editable UITextView that renders the styled Markdown,
/// flowing naturally inside a SwiftUI ScrollView.
private struct ReadingText: UIViewRepresentable {
    let markdown: String

    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView(usingTextLayoutManager: false) // TextKit 1 self-sizes reliably
        tv.isEditable = false
        tv.isScrollEnabled = false
        tv.backgroundColor = .clear
        tv.textContainerInset = .zero
        tv.textContainer.lineFragmentPadding = 0
        tv.setContentCompressionResistancePriority(.required, for: .vertical)
        tv.attributedText = MarkdownStyler.attributed(for: markdown)
        return tv
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        uiView.attributedText = MarkdownStyler.attributed(for: markdown)
    }

    /// Wrap to the width SwiftUI offers and report the height it needs — without
    /// this the text view lays out at its intrinsic width and clips both edges.
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        let width = proposal.width ?? uiView.bounds.width
        let fitted = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return CGSize(width: width, height: fitted.height)
    }
}
