import SwiftUI
import UIKit
import PencilKit

/// A distraction-free, read-only view of an entry — the Markdown rendered and
/// typeset, no editing chrome.
struct ReadingView: View {
    let entry: Entry
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.modelContext) private var context

    private var wordCount: Int {
        MarkdownRender.plainText(entry.body)
            .split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
    }
    private var readMinutes: Int { max(1, Int((Double(wordCount) / 220).rounded(.up))) }

    /// Dateline · read-time, natural case (the small-caps font does the styling).
    private var kicker: String {
        let date = entry.createdAt.formatted(.dateTime.weekday(.wide).month(.wide).day().year())
        return wordCount > 0 ? "\(date) · \(readMinutes) min read" : date
    }

    private var ink: UIImage? {
        guard let d = DrawingStore.load(entry.id), !d.strokes.isEmpty,
              d.bounds.width > 1, d.bounds.height > 1 else { return nil }
        return d.image(from: d.bounds, scale: UIScreen.main.scale)
    }

    var body: some View {
        ZStack {
            PaperBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    // Small-caps dateline kicker above the title.
                    Text(kicker)
                        .font(EditorialType.font(13, smallCaps: true))
                        .tracking(1.6)
                        .foregroundStyle(Paper.inkSoft)
                    if !entry.title.trimmingCharacters(in: .whitespaces).isEmpty {
                        Text(entry.title)
                            .font(.masthead)
                            .foregroundStyle(Paper.ink)
                            .padding(.bottom, 2)
                    }
                    RenderedBody(markdown: entry.body, wash: entry.photoWash,
                                 onToggleTask: toggleTask)

                    if let ink {
                        Image(uiImage: ink)
                            .resizable().scaledToFit()
                            .frame(maxWidth: sizeClass == .regular ? 460 : .infinity)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 8)
                    }
                }
                .padding(.horizontal, 26)
                .padding(.top, 12)
                .padding(.bottom, 60)
                // Optimal measure — hold the column to a readable line length,
                // centered on wide screens.
                .frame(maxWidth: 680)
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .tint(Paper.accent)
    }

    /// Flip the index-th checkbox in the body and save.
    private func toggleTask(_ index: Int) {
        guard let regex = try? NSRegularExpression(pattern: #"- \[[ xX]\]"#) else { return }
        let ns = entry.body as NSString
        let matches = regex.matches(in: entry.body, range: NSRange(location: 0, length: ns.length))
        guard index < matches.count else { return }
        let range = matches[index].range
        let current = ns.substring(with: range)
        let flipped = current.contains("[ ]") ? "- [x]" : "- [ ]"
        Haptics.tap()
        entry.body = ns.replacingCharacters(in: range, with: flipped)
        entry.updatedAt = .now
        try? context.save()
    }

    /// Reading-mode typography — the same serif scale as the app, syntax removed.
    /// Computed so a live theme/accent change is reflected.
    static var readerStyle: MarkdownRender.Style {
        MarkdownRender.Style(
        body: EditorialType.font(18),
        heading: { level in
            switch level {
            case 1:  return EditorialType.font(28, weight: .semibold)
            case 2:  return EditorialType.font(23, weight: .semibold)
            default: return EditorialType.font(20, weight: .semibold)
            }
        },
        mono: .system(size: 16, design: .monospaced),
        ink: Paper.ink, soft: Paper.inkSoft, accent: Paper.accent)
    }
}
