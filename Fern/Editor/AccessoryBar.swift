import SwiftUI

/// The thin accessory above the keyboard. Tapping a glyph inserts the
/// corresponding Markdown at the end of the text; word count auto-updates.
/// (Caret-aware insertion is a small follow-up — for v1, appending at end
/// is the right default for forward typing.)
struct AccessoryBar: View {
    @Binding var text: String

    private var wordCount: Int {
        text.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
    }

    var body: some View {
        HStack(spacing: 22) {
            glyph("B", weight: .bold)  { wrap("**") }
            glyph("I", italic: true)    { wrap("*") }
            glyph("“ ”")                { wrap("“", "”") }
            glyph("#")                  { lineStart("# ") }
            glyph("—")                  { insert("—") }
            Spacer()
            Text("\(wordCount) words")
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(Paper.inkFaint)
        }
        .padding(.horizontal, 20)
        .frame(height: 42)
        .background(
            Rectangle().fill(Paper.raised.opacity(0.96))
                .overlay(Rectangle().frame(height: 1).foregroundStyle(Paper.line), alignment: .top)
        )
    }

    // MARK: – Buttons

    @ViewBuilder
    private func glyph(_ s: String,
                       weight: Font.Weight = .regular,
                       italic: Bool = false,
                       _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(s)
                .font(.system(size: 17, weight: weight, design: .serif))
                .italic(italic)
                .foregroundStyle(Paper.inkSoft)
                .frame(minWidth: 24)
        }
        .buttonStyle(.plain)
    }

    // MARK: – Edits

    private func insert(_ s: String) { text.append(s) }

    private func wrap(_ open: String, _ close: String? = nil) {
        text.append("\(open)…\(close ?? open)")
    }

    private func lineStart(_ s: String) {
        if !text.hasSuffix("\n") && !text.isEmpty { text.append("\n") }
        text.append(s)
    }
}
