import SwiftUI
import UIKit
import PencilKit

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
    // Each entry grows its own fern — the note's fingerprint, stable across shares.
    private var fern: BarnsleyFern { BarnsleyFern.forID(entry.id, count: 14_000) }

    /// Card typography — large, fixed-light, with the editorial figure/ligature
    /// features. Fed to the same `RenderedBody` renderer the reader uses.
    private var cardStyle: MarkdownRender.Style {
        MarkdownRender.Style(
            body: EditorialType.font(34),
            heading: { level in EditorialType.font(level <= 1 ? 46 : 40, weight: .semibold) },
            mono: .system(size: 31, design: .monospaced),
            ink: ink, soft: inkSoft, accent: accent)
    }

    private var source: String {
        let body = entry.body.trimmingCharacters(in: .whitespacesAndNewlines)
        return body.isEmpty ? (entry.prompt ?? "") : entry.body
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text(entry.createdAt.formatted(.dateTime.weekday(.wide).month(.wide).day().year()))
                .font(EditorialType.font(24, smallCaps: true)).tracking(2.5)
                .foregroundStyle(inkSoft)

            Text(entry.displayTitle)
                .font(EditorialType.font(64, weight: .medium))
                .foregroundStyle(ink)
                .fixedSize(horizontal: false, vertical: true)

            if !source.isEmpty {
                RenderedBody(markdown: source, wash: entry.photoWash,
                             style: cardStyle, dropCap: false, photoWidth: 900,
                             captionFont: EditorialType.font(26, italic: true),
                             ruleSize: 30, spacing: 22)
            }

            if !loosePhotos.isEmpty {
                cardPhotos
            }

            if let drawing {
                Image(uiImage: drawing)
                    .resizable().scaledToFit()
                    .frame(maxWidth: .infinity)
                    .frame(maxHeight: 700)
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
        .environment(\.colorScheme, .light)   // card is always light, regardless of device
    }

    /// Attachments not embedded inline (those render in the body); shown at the foot.
    private var loosePhotos: [UIImage] {
        entry.photoFileNames
            .filter { !entry.body.contains("fern://\($0)") }
            .prefix(3).compactMap { PhotoStore.load($0) }
    }

    /// The note's Apple Pencil ink, rendered to an image for the card.
    private var drawing: UIImage? {
        guard let d = DrawingStore.load(entry.id), !d.strokes.isEmpty else { return nil }
        let bounds = d.bounds
        guard bounds.width > 1, bounds.height > 1 else { return nil }
        return d.image(from: bounds, scale: 2)
    }

    private var cardPhotos: some View {
        let imgs = loosePhotos
        return HStack(spacing: 16) {
            ForEach(Array(imgs.enumerated()), id: \.offset) { _, img in
                Image(uiImage: entry.photoWash ? EditorPhotos.washed(img) : img)
                    .resizable().scaledToFill()
                    .frame(width: imgs.count == 1 ? 952 : 300,
                           height: imgs.count == 1 ? 560 : 300)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            }
        }
    }
}
