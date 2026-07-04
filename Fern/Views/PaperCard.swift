import SwiftUI
import UIKit

/// A shareable paper-and-ink card of an entry. Rendered to an image by
/// `ImageRenderer`. Uses fixed light colors so the shared image looks the same
/// regardless of the device's appearance.
struct PaperCard: View {
    let entry: Entry

    private let paper   = Color(red: 0.965, green: 0.961, blue: 0.945)
    private let ink     = Color(red: 0.110, green: 0.102, blue: 0.090)
    private let inkSoft = Color(red: 0.357, green: 0.341, blue: 0.314)
    private let accent  = Color(red: 0.604, green: 0.290, blue: 0.176)
    private let line    = Color(red: 0.922, green: 0.914, blue: 0.882)
    private let fern = BarnsleyFern(seed: 4_211, count: 14_000)

    /// The full body, Markdown rendered (no raw `**`/`#`). Falls back to the
    /// prompt for a still-blank piece.
    private var rendered: AttributedString {
        let body = entry.body.trimmingCharacters(in: .whitespacesAndNewlines)
        let source = body.isEmpty ? (entry.prompt ?? "") : entry.body
        guard !source.isEmpty else { return AttributedString("") }
        return MarkdownRender.styled(source, .init(
            body: .system(size: 34, design: .serif),
            heading: { level in .system(size: level <= 1 ? 46 : 40,
                                        weight: .semibold, design: .serif) },
            mono: .system(size: 31, design: .monospaced),
            ink: ink, soft: inkSoft, accent: accent))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text(entry.createdAt.formatted(.dateTime.month(.wide).day().year()))
                .font(.system(size: 26, weight: .semibold, design: .serif))
                .textCase(.uppercase).tracking(3)
                .foregroundStyle(inkSoft)

            Text(entry.displayTitle)
                .font(.system(size: 64, weight: .medium, design: .serif))
                .foregroundStyle(ink)
                .fixedSize(horizontal: false, vertical: true)

            let text = rendered
            if !text.characters.isEmpty {
                Text(text)
                    .foregroundStyle(inkSoft)
                    .lineSpacing(8)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !photos.isEmpty {
                cardPhotos
            }

            Spacer(minLength: 40)

            Rectangle().fill(line).frame(height: 1)

            HStack(alignment: .bottom) {
                Text("Fern")
                    .font(.system(size: 40, design: .serif))
                    .foregroundStyle(ink)
                + Text(".").font(.system(size: 40, design: .serif)).foregroundStyle(accent)
                Spacer()
                BarnsleyFernView(fern: fern, tint: accent, dotSize: 1.0, alpha: 0.7)
                    .frame(width: 130, height: 180)
            }
        }
        .padding(64)
        .frame(width: 1080, alignment: .topLeading)
        .frame(minHeight: 1080, alignment: .topLeading)
        .background(paper)
    }

    private var photos: [UIImage] {
        entry.photoFileNames.prefix(3).compactMap { PhotoStore.load($0) }
    }

    private var cardPhotos: some View {
        HStack(spacing: 16) {
            ForEach(Array(photos.enumerated()), id: \.offset) { _, img in
                Image(uiImage: img)
                    .resizable().scaledToFill()
                    .frame(width: photos.count == 1 ? 952 : 300,
                           height: photos.count == 1 ? 560 : 300)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            }
        }
    }
}
