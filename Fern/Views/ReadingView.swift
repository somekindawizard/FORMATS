import SwiftUI
import UIKit
import PencilKit

/// A distraction-free, read-only view of an entry — the Markdown rendered and
/// typeset, no editing chrome.
struct ReadingView: View {
    let entry: Entry
    @Environment(\.horizontalSizeClass) private var sizeClass

    private var wordCount: Int {
        MarkdownRender.plainText(entry.body)
            .split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
    }
    private var readMinutes: Int { max(1, Int((Double(wordCount) / 220).rounded(.up))) }

    private var ink: UIImage? {
        guard let d = DrawingStore.load(entry.id), !d.strokes.isEmpty,
              d.bounds.width > 1, d.bounds.height > 1 else { return nil }
        return d.image(from: d.bounds, scale: UIScreen.main.scale)
    }

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
                    if wordCount > 0 {
                        Text("\(wordCount) words · \(readMinutes) min read")
                            .font(.calloutSerif)
                            .foregroundStyle(Paper.inkFaint)
                    }
                    RenderedBody(markdown: entry.body, wash: entry.photoWash)

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
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .tint(Paper.accent)
    }

    /// Reading-mode typography — the same serif scale as the app, syntax removed.
    /// Computed so a live theme/accent change is reflected.
    static var readerStyle: MarkdownRender.Style {
        MarkdownRender.Style(
        body: .serif(18),
        heading: { level in
            switch level {
            case 1:  return .serif(28, .semibold)
            case 2:  return .serif(23, .semibold)
            default: return .serif(20, .semibold)
            }
        },
        mono: .system(size: 16, design: .monospaced),
        ink: Paper.ink, soft: Paper.inkSoft, accent: Paper.accent)
    }
}
