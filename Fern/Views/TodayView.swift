import SwiftUI
import SwiftData

struct TodayView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(PromptStore.self) private var promptStore
    @Query(sort: \Entry.createdAt, order: .reverse) private var entries: [Entry]

    @State private var draft: Entry?
    @State private var journalTheme: PromptTheme?
    @State private var creativeTheme: PromptTheme?
    @State private var journalPrompt: Prompt?
    @State private var creativePrompt: Prompt?

    @AppStorage("fern.userName") private var userName = ""
    @AppStorage("fern.lastMilestone") private var lastMilestone = 0
    @State private var milestone: Int?

    /// Streaks worth pausing for.
    private static let milestones: Set<Int> = [3, 7, 14, 21, 30, 50, 75, 100, 150, 200, 300, 365, 500, 1000]

    private var greeting: String {
        let h = Calendar.current.component(.hour, from: .now)
        switch h {
        case 5..<12:  return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<22: return "Good evening"
        default:      return "Hello"
        }
    }

    private var greetingLine: String {
        userName.isEmpty ? "\(greeting)." : "\(greeting), \(userName)."
    }

    // Cached and recomputed on appear (initial + pop-back) rather than as
    // computed properties: those re-scanned the whole corpus — splitting every
    // body written this week — on EVERY body evaluation, including once per
    // keystroke-autosave while typing in a pushed editor.
    @State private var wordsThisWeek = 0
    @State private var streak = 0
    @State private var streakAtRisk = false
    @State private var yearAgo: Entry?

    private func recomputeStats() {
        wordsThisWeek = WritingStats.wordsThisWeek(entries)
        streak = WritingStats.currentStreak(entries)
        streakAtRisk = WritingStats.streakAtRisk(entries)
        yearAgo = OnThisDay.entries(from: entries).first
        // Milestones celebrate the day you WRITE the milestone entry — not a
        // morning where yesterday's chain merely survives on grace.
        if !streakAtRisk { checkMilestone() }
    }

    var body: some View {
        ZStack {
            PaperBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                            .sectionLabel()
                        HStack(alignment: .center, spacing: 12) {
                            // Sidebar toggle — iPad/Mac only (iPhone uses the tab bar).
                            if sizeClass == .regular {
                                Button {
                                    withAnimation(.easeInOut(duration: 0.25)) {
                                        FernNav.shared.columnVisibility =
                                            FernNav.shared.columnVisibility == .detailOnly ? .all : .detailOnly
                                    }
                                } label: {
                                    Image(systemName: "sidebar.leading")
                                        .font(.system(size: 18, weight: .medium))
                                        .foregroundStyle(Paper.accent)
                                }
                                .accessibilityLabel("Toggle sidebar")
                            }
                            Text("Today")
                                .font(.display(30))
                                .foregroundStyle(Paper.ink)
                            Spacer()
                            ComposeButton(action: freeWrite,
                                          templates: Templates.all,
                                          onTemplate: startFromTemplate)
                        }
                        Text(greetingLine)
                            .font(.serif(17))
                            .foregroundStyle(Paper.inkSoft)
                    }
                    .padding(.top, 10)

                    PromptCard(kind: .journal, theme: $journalTheme, prompt: journalPrompt,
                               onShuffle: { shuffle(.journal) },
                               onBegin: { begin(.journal, prompt: journalPrompt) })

                    PromptCard(kind: .creative, theme: $creativeTheme, prompt: creativePrompt,
                               onShuffle: { shuffle(.creative) },
                               onBegin: { begin(.creative, prompt: creativePrompt) })

                    if wordsThisWeek > 0 || streak > 0 {
                        HStack(spacing: 0) {
                            statCell("\(wordsThisWeek)", "words this week")
                            Rectangle().fill(Paper.line).frame(width: 1, height: 36)
                            statCell(streak == 1 ? "1 day" : "\(streak) days",
                                     streakAtRisk ? "write today to keep it" : "writing streak")
                        }
                        .card(padding: 14)
                    }

                    if let past = yearAgo {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("One year ago today").sectionLabel()
                            NavigationLink(value: past) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(past.displayTitle)
                                        .font(.headlineSerif).foregroundStyle(Paper.ink)
                                    if !past.body.isEmpty {
                                        Text(past.body).font(.calloutSerif)
                                            .foregroundStyle(Paper.inkSoft).lineLimit(2)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                        .card()
                    }
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 40)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .overlay {
            if let m = milestone {
                StreakFlourish(days: m) {
                    lastMilestone = m
                    milestone = nil
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(for: Entry.self) { entry in
            EntryEditorView(entry: entry)
        }
        .navigationDestination(item: $draft) { entry in
            EntryEditorView(entry: entry)
        }
        .onAppear { loadInitialPrompts(); recomputeStats() }
        .onChange(of: journalTheme) { _, _ in refresh(.journal) }
        .onChange(of: creativeTheme) { _, _ in refresh(.creative) }
    }

    /// Show the flourish once when the streak crosses a milestone we haven't
    /// celebrated yet. If the streak lapses, allow the same milestone again.
    private func checkMilestone() {
        let s = streak
        if Self.milestones.contains(s), s > lastMilestone {
            milestone = s
        } else if s < lastMilestone {
            lastMilestone = s   // streak broke — reset so it can recur
        }
    }

    // MARK: prompts

    private func loadInitialPrompts() {
        if journalPrompt == nil {
            journalPrompt = PromptLibrary.daily(kind: .journal, theme: journalTheme)
            if let t = journalPrompt?.text { promptStore.recordShown(t) }
        }
        if creativePrompt == nil {
            creativePrompt = PromptLibrary.daily(kind: .creative, theme: creativeTheme)
            if let t = creativePrompt?.text { promptStore.recordShown(t) }
        }
    }

    private func refresh(_ kind: PromptKind) {
        let theme = kind == .journal ? journalTheme : creativeTheme
        let picked = PromptLibrary.daily(kind: kind, theme: theme)
        if kind == .journal { journalPrompt = picked } else { creativePrompt = picked }
        if let t = picked?.text { promptStore.recordShown(t) }
    }

    private func shuffle(_ kind: PromptKind) {
        let theme = kind == .journal ? journalTheme : creativeTheme
        let current = kind == .journal ? journalPrompt?.text : creativePrompt?.text
        guard let picked = PromptLibrary.random(kind: kind, theme: theme, excluding: current) else { return }
        if kind == .journal { journalPrompt = picked } else { creativePrompt = picked }
        promptStore.recordShown(picked.text)
    }

    /// A blank piece with no prompt — pure free writing.
    private func freeWrite() {
        Haptics.tap()
        let entry = Entry(title: "", body: "", collection: .piece)
        context.insert(entry)
        draft = entry
    }

    /// Start a new entry pre-filled from a template.
    private func startFromTemplate(_ template: WritingTemplate) {
        Haptics.tap()
        let entry = Entry(title: "", body: template.body, collection: template.collection)
        context.insert(entry)
        draft = entry
    }

    private func begin(_ kind: PromptKind, prompt: Prompt?) {
        let collection: Collection = kind == .journal ? .journal : .piece
        let entry = Entry(title: "", body: "", collection: collection)
        entry.prompt = prompt?.text
        if let theme = prompt?.theme { entry.tagNames = [theme.rawValue] }
        context.insert(entry)
        draft = entry
    }

    private func statCell(_ value: String, _ label: String) -> some View {
        VStack(spacing: 3) {
            Text(value).font(.figure(20)).foregroundStyle(Paper.accent)
            Text(label).font(.label).textCase(.uppercase).tracking(1.2)
                .foregroundStyle(Paper.inkFaint)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    NavigationStack { TodayView() }
        .environment(PromptStore())
        .modelContainer(SampleData.previewContainer())
}
