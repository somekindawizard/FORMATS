import SwiftUI

/// A prompt on the Today screen: a theme picker, the prompt text, shuffle +
/// favorite controls, and a Begin button. Used once for journal, once for
/// creative.
struct PromptCard: View {
    let kind: PromptKind
    @Binding var theme: PromptTheme?
    let prompt: Prompt?
    let onShuffle: () -> Void
    let onBegin: () -> Void

    @Environment(PromptStore.self) private var store

    private var isFavorite: Bool {
        guard let prompt else { return false }
        return store.isFavorite(prompt.text)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(kind == .journal ? "A prompt for today" : "A spark to write")
                    .sectionLabel()
                Spacer()
                Menu {
                    Button("All themes") { theme = nil }
                    Divider()
                    ForEach(PromptTheme.allCases) { t in
                        Button(t.title) { theme = t }
                    }
                } label: {
                    HStack(spacing: 3) {
                        Text(theme?.title ?? "All themes")
                        Image(systemName: "chevron.down").font(.system(size: 9))
                    }
                    .font(.label)
                    .foregroundStyle(Paper.inkSoft)
                }
            }

            Text(prompt?.text ?? "—")
                .font(.titleSerif)
                .foregroundStyle(Paper.ink)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 20) {
                Button(action: onShuffle) {
                    Label("Shuffle", systemImage: "shuffle")
                        .font(.calloutSerif)
                        .foregroundStyle(Paper.inkSoft)
                }
                Button {
                    if let prompt { store.toggleFavorite(prompt.text) }
                } label: {
                    Image(systemName: isFavorite ? "heart.fill" : "heart")
                        .foregroundStyle(Paper.accent)
                }
                .disabled(prompt == nil)
                Spacer()
            }

            Button(kind == .journal ? "Begin writing" : "Begin a piece") { onBegin() }
                .buttonStyle(InkButtonStyle())
        }
        .card()
    }
}
