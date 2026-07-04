import SwiftUI
import UIKit
import PencilKit

/// Exports a note as a paginated US-Letter PDF — title, date, the Markdown body
/// with inline photos, and the Apple Pencil ink. Renders the note to one tall
/// image, then slices it across pages.
enum PDFExporter {
    private static let pageSize = CGSize(width: 612, height: 792)   // US Letter @72dpi
    private static let margin: CGFloat = 44

    @MainActor
    static func pdf(for entry: Entry) -> URL? {
        let contentWidth = pageSize.width - margin * 2
        let renderer = ImageRenderer(content:
            PrintPage(entry: entry).frame(width: contentWidth))
        renderer.scale = 3
        guard let full = renderer.uiImage, let cg = full.cgImage else { return nil }

        let scale = full.scale
        let pageContentHeight = pageSize.height - margin * 2
        let totalHeight = full.size.height

        let safeName = entry.displayTitle
            .components(separatedBy: CharacterSet(charactersIn: "/\\:?%*|\"<>")).joined()
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(safeName.isEmpty ? "Fern note" : safeName).pdf")

        let pdf = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: pageSize))
        do {
            try pdf.writePDF(to: url) { ctx in
                var y: CGFloat = 0
                while y < totalHeight {
                    ctx.beginPage()
                    let sliceHeight = min(pageContentHeight, totalHeight - y)
                    let cropRect = CGRect(x: 0, y: y * scale,
                                          width: full.size.width * scale, height: sliceHeight * scale)
                    if let slice = cg.cropping(to: cropRect) {
                        UIImage(cgImage: slice).draw(in: CGRect(x: margin, y: margin,
                                                                width: contentWidth, height: sliceHeight))
                    }
                    y += pageContentHeight
                }
            }
            return url
        } catch {
            return nil
        }
    }
}

/// The note laid out for print — forced light so it reads black-on-white.
private struct PrintPage: View {
    let entry: Entry

    private var drawing: UIImage? {
        guard let d = DrawingStore.load(entry.id), !d.strokes.isEmpty,
              d.bounds.width > 1, d.bounds.height > 1 else { return nil }
        return d.image(from: d.bounds, scale: 3)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(entry.createdAt.formatted(.dateTime.weekday(.wide).month(.wide).day().year()))
                .font(.system(size: 11, weight: .semibold, design: .serif))
                .textCase(.uppercase).tracking(1.5)
                .foregroundStyle(.secondary)

            if !entry.title.trimmingCharacters(in: .whitespaces).isEmpty {
                Text(entry.title)
                    .font(.system(size: 26, weight: .semibold, design: .serif))
            }

            RenderedBody(markdown: entry.body, wash: entry.photoWash)

            if let drawing {
                Image(uiImage: drawing)
                    .resizable().scaledToFit()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .foregroundStyle(.black)
        .environment(\.colorScheme, .light)
    }
}
