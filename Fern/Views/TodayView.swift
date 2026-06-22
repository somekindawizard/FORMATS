import SwiftUI
import SwiftData

struct TodayView: View {
    @Environment(\.modelContext) private var context
    @Environment(PromptStore.self) private var promptStore
    @Query(sort: \Entry.createdAt, order: .reverse) private var entries: [Entry]

    @State private var draft: Entry?
    @State private var journalTheme: PromptTheme?
    @State private var creativeTheme: PromptTheme?
    @State private var journalPrompt: Prompt?
    @State private var creativePrompt: Prompt?

    private var greeting: String {
        let h = Calendar.current.component(.hour, from: .now)
        switch h {
        case 5..<12:  return "Good morning,"
        case 12..<17: return "Good afternoon,"
        case 17..<22: return "Good evening,"
        default:      return "Hello,"
        }
    }

    private var onThisDay: [Entry] { OnThisDay.entries(from: entries) }
    private var wordsThisWeek: Int { WritingStats.wordsThisWeek(entries) }
    private var streak: Int { WritingStats.currentStreak(entries) }

    var body: some View {
        ZStack {
            PaperBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text(Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                        .sectionLabel()
                        .padding(.top, 8)
                    Text("\(greeting)\nAustin.")
                        .font(.masthead)
                        .foregroundStyle(Paper.ink)

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
                            statCell(streak == 1 ? "1 day" : "\(streak) days", "writing streak")
                        }
                        .card(padding: 14)
                    }

                    if let past = onThisDay.first {
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
        .navigationTitle("Today")
        .navigationDestination(for: Entry.self) { entry in
            EntryEditorView(entry: entry)
        }
        .navigationDestination(item: $draft) { entry in
            EntryEditorView(entry: entry)
        }
        .onAppear { loadInitialPrompts() }
        .onChange(of: journalTheme) { _, _ in refresh(.journal) }
        .onChange(of: creativeTheme) { _, _ in refresh(.creative) }
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
