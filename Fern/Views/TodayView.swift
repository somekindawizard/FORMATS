import SwiftUI
import SwiftData
import UIKit

struct TodayView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Entry.createdAt, order: .reverse) private var entries: [Entry]
    @State private var draft: Entry?

    private var greeting: String {
        let h = Calendar.current.component(.hour, from: .now)
        switch h {
        case 5..<12:  return "Good morning,"
        case 12..<17: return "Good afternoon,"
        case 17..<22: return "Good evening,"
        default:      return "Hello,"
        }
    }

    private var prompt: String { Prompts.forToday() }
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

                    // Prompt + begin
                    VStack(alignment: .leading, spacing: 10) {
                        Text("A prompt for today").sectionLabel()
                        Text(prompt)
                            .font(.titleSerif)
                            .foregroundStyle(Paper.ink)
                            .fixedSize(horizontal: false, vertical: true)
                        Button("Begin writing") { beginWriting() }
                            .buttonStyle(InkButtonStyle())
                            .padding(.top, 4)

                        // iPhone only — the system Journaling Suggestions picker.
                        if UIDevice.current.userInterfaceIdiom == .phone {
                            SuggestionsButton { entry in draft = entry }
                                .padding(.top, 2)
                        }
                    }
                    .card()

                    // Stats glance
                    if wordsThisWeek > 0 || streak > 0 {
                        HStack(spacing: 0) {
                            statCell("\(wordsThisWeek)", "words this week")
                            Rectangle().fill(Paper.line).frame(width: 1, height: 36)
                            statCell(streak == 1 ? "1 day" : "\(streak) days", "writing streak")
                        }
                        .card(padding: 14)
                    }

                    // On this day
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
    }

    private func beginWriting() {
        let entry = Entry(title: "", body: "", collection: .journal)
        entry.prompt = prompt
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
        .modelContainer(SampleData.previewContainer())
}
