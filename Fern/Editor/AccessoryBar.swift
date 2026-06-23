import SwiftUI

/// The accessory above the keyboard. A synonym strip rides on top (offering
/// alternatives for the word under the caret), with the Markdown glyph row and
/// word count below.
struct AccessoryBar: View {
    @Bindable var controller: MarkdownEditorController
    let text: String

    private var wordCount: Int {
        text.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
    }

    var body: some View {
        VStack(spacing: 0) {
            SynonymStrip(controller: controller)

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
        }
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

/// A horizontally scrolling row of synonyms for the caret's current word. Looks
/// them up (debounced) as the word changes; hides itself when there's nothing
/// to offer. Tapping a synonym swaps the word in place.
private struct SynonymStrip: View {
    @Bindable var controller: MarkdownEditorController
    @State private var synonyms: [String] = []

    var body: some View {
        Group {
            if !synonyms.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        Image(systemName: "text.book.closed")
                            .font(.system(size: 11))
                            .foregroundStyle(Paper.inkFaint)
                        ForEach(synonyms, id: \.self) { word in
                            Button { controller.replaceCurrentWord(with: word) } label: {
                                Text(word)
                                    .font(.calloutSerif)
                                    .foregroundStyle(Paper.accent)
                                    .padding(.vertical, 5).padding(.horizontal, 12)
                                    .background(Capsule().fill(Paper.accent.opacity(0.08)))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .frame(height: 38)
                .overlay(Rectangle().frame(height: 1).foregroundStyle(Paper.line), alignment: .bottom)
                .transition(.opacity)
            }
        }
        .task(id: controller.currentWord) {
            let word = controller.currentWord
            guard word.count >= 3 else { synonyms = []; return }
            // Debounce so we don't look up mid-keystroke.
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            let found = await Thesaurus.synonyms(for: word)
            guard !Task.isCancelled, controller.currentWord == word else { return }
            withAnimation(.easeOut(duration: 0.2)) { synonyms = found }
        }
    }
}
