import SwiftUI

/// The accessory above the keyboard. A synonym strip rides on top (offering
/// alternatives for the word under the caret), with the Markdown glyph row and
/// word count below.
struct AccessoryBar: View {
    @Bindable var controller: MarkdownEditorController

    var body: some View {
        VStack(spacing: 0) {
            SynonymStrip(controller: controller)

            HStack(spacing: 0) {
                // Word count + keyboard-dismiss go on the dominant side so
                // they're a thumb's reach away.
                if trailing { dismissGroup; Divider().frame(height: 22) }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 20) {
                        icon("textformat.size")       { controller.cycleHeading() }
                        icon("bold")                  { controller.wrap("**") }
                        icon("italic")                { controller.wrap("*") }
                        icon("strikethrough")         { controller.wrap("~~") }
                        icon("highlighter")           { controller.wrap("==") }
                        icon("chevron.left.forwardslash.chevron.right") { controller.wrap("`") }
                        divider
                        icon("list.bullet")           { controller.setLinePrefix("- ") }
                        icon("list.number")           { controller.setLinePrefix("1. ") }
                        icon("checklist")             { controller.toggleTask() }
                        icon("text.quote")            { controller.setLinePrefix("> ") }
                        divider
                        icon("link")                  { controller.insertLink() }
                        icon("minus")                 { controller.insertRule() }
                        if controller.requestPhoto != nil {
                            icon("photo") { controller.requestPhoto?() }
                        }
                    }
                    .padding(.horizontal, 20)
                }

                if !trailing { Divider().frame(height: 22); dismissGroup }
            }
            .frame(height: 44)
        }
        .background(
            Rectangle().fill(Paper.raised.opacity(0.96))
                .overlay(Rectangle().frame(height: 1).foregroundStyle(Paper.line), alignment: .top)
        )
    }

    private var trailing: Bool { ThemeStore.shared.handedness.controlsTrailing }

    private var dismissGroup: some View {
        HStack(spacing: 0) {
            Text("\(controller.wordCount)")
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(Paper.inkFaint)
                .padding(.horizontal, 12)
            Button { controller.dismissKeyboard() } label: {
                Image(systemName: "keyboard.chevron.compact.down")
                    .font(.system(size: 16))
                    .foregroundStyle(Paper.inkSoft)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 14)
        }
    }

    private var divider: some View {
        Rectangle().fill(Paper.line).frame(width: 1, height: 20)
    }

    @ViewBuilder
    private func icon(_ system: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.system(size: 16))
                .foregroundStyle(Paper.inkSoft)
                .frame(minWidth: 26, minHeight: 30)
                .contentShape(Rectangle())
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
