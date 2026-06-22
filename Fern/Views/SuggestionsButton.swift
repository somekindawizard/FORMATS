import SwiftUI
import SwiftData

// JournalingSuggestions is a device-only framework — it isn't in the Simulator
// SDK. Guard the import so the app still builds for the simulator and previews;
// the real picker compiles only for devices.
#if canImport(JournalingSuggestions)
import JournalingSuggestions

/// iPhone-only. Presents the system Journaling Suggestions picker and turns a
/// chosen suggestion into a new journal entry, seeded with its title and any
/// reflection prompt. The picker runs out-of-process and returns only the
/// content the user chose to share. Requires the
/// `com.apple.developer.journal.allow` entitlement.
struct SuggestionsButton: View {
    @Environment(\.modelContext) private var context
    var onCreated: (Entry) -> Void

    var body: some View {
        JournalingSuggestionsPicker {
            Label("Journaling suggestions", systemImage: "sparkles")
                .font(.calloutSerif)
        } onCompletion: { suggestion in
            await create(from: suggestion)
        }
        .tint(Paper.accent)
    }

    @MainActor
    private func create(from suggestion: JournalingSuggestion) async {
        var bodyText = ""
        let reflections = await suggestion.content(forType: JournalingSuggestion.Reflection.self)
        if let reflection = reflections.first {
            bodyText = reflection.prompt
        }
        let entry = Entry(title: suggestion.title, body: bodyText, collection: .journal)
        context.insert(entry)
        onCreated(entry)
    }
}

#else

/// Simulator fallback — Journaling Suggestions is unavailable there.
struct SuggestionsButton: View {
    var onCreated: (Entry) -> Void
    var body: some View { EmptyView() }
}

#endif
