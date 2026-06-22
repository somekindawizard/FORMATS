import SwiftUI

/// The thin accessory above the keyboard. Each glyph applies Markdown to the
/// current selection / caret via the editor controller; word count tracks text.
struct AccessoryBar: View {
    let controller: MarkdownEditorController
    let text: String

    private var wordCount: Int {
        text.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
    }

    var body: some View {
        HStack(spacing: 22) {
            glyph("B", weight: .bold)  { controller.wrap("**") }
            glyph("I", italic: true)    { controller.wrap("*") }
            glyph("\u{201C} \u{201D}")  { controller.wrapPair("\u{201C}", "\u{201D}") }
            glyph("#")                  { controller.prefixLine("# ") }
            glyph("\u{2014}")           { controller.insert("\u{2014}") }
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
}
