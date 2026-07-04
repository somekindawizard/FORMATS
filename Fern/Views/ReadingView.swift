import SwiftUI
import UIKit

/// A distraction-free, read-only view of an entry — the Markdown rendered and
/// typeset, no editing chrome.
struct ReadingView: View {
    let entry: Entry

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
                    RenderedBody(markdown: entry.body, wash: entry.photoWash)
                }
                .padding(.horizontal, 26)
                .padding(.top, 12)
                .padding(.bottom, 60)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
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
