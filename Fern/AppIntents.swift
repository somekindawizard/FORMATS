import AppIntents
import Foundation

/// "New Fern entry" — usable from the Action Button, Shortcuts, Spotlight, and
/// Siri. Opens the app and drops you into a fresh blank piece. The app picks up
/// the flag on becoming active (see RootView).
struct NewFernEntryIntent: AppIntent {
    static var title: LocalizedStringResource = "New Fern Entry"
    static var description = IntentDescription("Start a new blank piece in Fern.")
    static var openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        UserDefaults.standard.set(true, forKey: "fern.quickCompose")
        return .result()
    }
}

struct FernShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: NewFernEntryIntent(),
            phrases: [
                "New \(.applicationName) entry",
                "Write in \(.applicationName)",
                "New note in \(.applicationName)"
            ],
            shortTitle: "New Entry",
            systemImageName: "square.and.pencil"
        )
    }
}
