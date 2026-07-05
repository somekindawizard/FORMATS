import SwiftUI
import SwiftData
import UIKit
import PencilKit

/// A distraction-free, read-only view of an entry — the Markdown rendered and
/// typeset, no editing chrome.
struct ReadingView: View {
    let entry: Entry
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.modelContext) private var context
    @Query private var allEntries: [Entry]
    @State private var linkedEntry: Entry?
    @State private var speech = ReadAloud.shared
    @State private var scrollY: CGFloat = 0
    @State private var scrollProxy: ScrollViewProxy?

    /// The masthead title hands off to the nav bar as it scrolls away.
    private var mastheadHandoff: Double {
        min(1, max(0, Double((scrollY - 44) / 44)))
    }

    /// Notes that link to this one via [[title]].
    private var backlinks: [Entry] {
        let title = entry.displayTitle
        guard !title.isEmpty else { return [] }
        let needle = "[[\(title)]]".lowercased()
        return allEntries.filter { $0.id != entry.id && $0.body.lowercased().contains(needle) }
    }

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

    private var cover: UIImage? {
        guard !entry.coverPhotoName.isEmpty else { return nil }
        return PhotoStore.load(entry.coverPhotoName)
    }

    private var inkDrawing: PKDrawing? {
        guard let d = DrawingStore.load(entry.id), !d.strokes.isEmpty,
              d.bounds.width > 1, d.bounds.height > 1 else { return nil }
        return d
    }

    private var outline: [RenderedBody.Heading] { RenderedBody.outline(entry.body) }

    var body: some View {
        ZStack {
            PaperBackground()
            ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if let cover {
                        Image(uiImage: cover)
                            .resizable().scaledToFill()
                            .frame(maxWidth: .infinity)
                            .frame(height: sizeClass == .regular ? 300 : 220)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Paper.line, lineWidth: 1))
                            .padding(.bottom, 4)
                    }
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
                            .opacity(1 - mastheadHandoff)
                    }
                    RenderedBody(markdown: entry.body, wash: entry.photoWash,
                                 onToggleTask: toggleTask, detectData: true)

                    if let inkDrawing {
                        InkReplay(drawing: inkDrawing,
                                  maxWidth: sizeClass == .regular ? 460 : .infinity)
                            .padding(.top, 8)
                    }

                    if !backlinks.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Image(systemName: "leaf")
                                .font(.system(size: 12)).foregroundStyle(Paper.inkFaint)
                                .frame(maxWidth: .infinity).padding(.vertical, 10)
                            Text("Mentioned in").sectionLabel()
                            ForEach(backlinks) { note in
                                Button { linkedEntry = note } label: {
                                    HStack(spacing: 8) {
                                        Image(systemName: "arrow.turn.up.left")
                                            .font(.system(size: 11)).foregroundStyle(Paper.accent)
                                        Text(note.displayTitle)
                                            .font(.bodySerif).foregroundStyle(Paper.ink)
                                        Spacer()
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.top, 20)
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
            .onScrollGeometryChange(for: CGFloat.self) { geo in
                geo.contentOffset.y + geo.contentInsets.top
            } action: { _, y in scrollY = y }
            .onAppear { scrollProxy = proxy }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .tint(Paper.accent)
        .toolbar {
            if outline.count >= 2 {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        ForEach(outline) { h in
                            Button {
                                Haptics.tap()
                                withAnimation(.easeInOut(duration: 0.4)) {
                                    scrollProxy?.scrollTo(h.id, anchor: .top)
                                }
                            } label: {
                                Text(String(repeating: "   ", count: max(0, h.level - 1)) + h.title)
                            }
                        }
                    } label: {
                        Image(systemName: "list.bullet.indent").foregroundStyle(Paper.accent)
                    }
                    .accessibilityLabel("Outline")
                }
            }
            ToolbarItem(placement: .principal) {
                Text(entry.displayTitle)
                    .font(.headlineSerif)
                    .foregroundStyle(Paper.ink)
                    .lineLimit(1)
                    .opacity(mastheadHandoff)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Haptics.tap()
                    speech.toggle(MarkdownRender.plainText(entry.body))
                } label: {
                    Image(systemName: speech.isSpeaking ? "stop.circle" : "speaker.wave.2")
                        .foregroundStyle(Paper.accent)
                }
                .accessibilityLabel(speech.isSpeaking ? "Stop reading" : "Read aloud")
            }
        }
        .onDisappear { speech.stop() }
        .environment(\.openURL, OpenURLAction { url in
            if url.scheme == "fern", url.host == "note" {
                let title = url.lastPathComponent.removingPercentEncoding ?? url.lastPathComponent
                if let match = allEntries.first(where: {
                    $0.displayTitle.caseInsensitiveCompare(title) == .orderedSame
                        || $0.title.caseInsensitiveCompare(title) == .orderedSame
                }) {
                    linkedEntry = match
                }
                return .handled
            }
            return .systemAction
        })
        .sheet(item: $linkedEntry) { note in
            NavigationStack { ReadingView(entry: note) }
        }
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

    /// Reading-mode typography now lives on `MarkdownRender.Style.reader`
    /// (shared across apps built on the editor). Kept here as an alias so
    /// existing call sites and the styler don't have to change.
    static var readerStyle: MarkdownRender.Style { .reader }
}
