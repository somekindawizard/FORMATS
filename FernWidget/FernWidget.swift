import WidgetKit
import SwiftUI

// Self-contained paper-and-ink palette (the widget doesn't share the app's
// ThemeStore, so it uses the default Mist + Sienna look).
private let paper   = Color(red: 0.965, green: 0.961, blue: 0.945)
private let ink     = Color(red: 0.110, green: 0.102, blue: 0.090)
private let inkSoft = Color(red: 0.357, green: 0.341, blue: 0.314)
private let accent  = Color(red: 0.604, green: 0.290, blue: 0.176)

struct PromptEntry: TimelineEntry {
    let date: Date
    let prompt: String
}

struct PromptProvider: TimelineProvider {
    private func current() -> PromptEntry {
        let text = PromptLibrary.daily(kind: .journal, theme: nil)?.text ?? "A blank page is waiting."
        return PromptEntry(date: Date(), prompt: text)
    }

    func placeholder(in context: Context) -> PromptEntry {
        PromptEntry(date: Date(), prompt: "What has quietly stayed with you today?")
    }

    func getSnapshot(in context: Context, completion: @escaping (PromptEntry) -> Void) {
        completion(current())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PromptEntry>) -> Void) {
        let entry = current()
        // Refresh at the start of the next day so the prompt rotates.
        let nextMidnight = Calendar.current.startOfDay(
            for: Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        )
        completion(Timeline(entries: [entry], policy: .after(nextMidnight)))
    }
}

struct FernWidgetView: View {
    var entry: PromptEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: "leaf.fill").font(.system(size: 11)).foregroundStyle(accent)
                Text("TODAY'S PROMPT")
                    .font(.system(size: 10, weight: .semibold, design: .serif))
                    .tracking(1.2)
                    .foregroundStyle(inkSoft)
            }
            Text(entry.prompt)
                .font(.system(size: family == .systemSmall ? 15 : 20, design: .serif))
                .foregroundStyle(ink)
                .lineLimit(family == .systemSmall ? 4 : 5)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 0)
            if family != .systemSmall {
                Text("Fern")
                    .font(.system(size: 13, design: .serif))
                    .foregroundStyle(inkSoft)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(paper, for: .widget)
    }
}

struct FernPromptWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "FernPromptWidget", provider: PromptProvider()) { entry in
            FernWidgetView(entry: entry)
        }
        .configurationDisplayName("Today's Prompt")
        .description("A gentle writing prompt, refreshed daily.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct FernWidgetBundle: WidgetBundle {
    var body: some Widget {
        FernPromptWidget()
    }
}
