import SwiftUI
import SwiftData
import CloudKit

/// Handles accepting a shared-notebook invite (CKShare) — routed to the shared
/// notebook store, which is separate from the SwiftData library.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     userDidAcceptCloudKitShareWith metadata: CKShare.Metadata) {
        Task { await SharedNotebookStore.shared.accept(metadata) }
    }
}

@main
struct FernApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var lock = BiometricLock()
    @State private var promptStore = PromptStore()
    @State private var theme = ThemeStore.shared

    init() {
        Fonts.register()
        NameSync.start()
    }

    var body: some Scene {
        WindowGroup {
            LockGate {
                RootView()
            }
            .environment(lock)
            .environment(promptStore)
            .environment(theme)
            // Theme changes propagate via Observation: Paper.* reads the
            // @Observable ThemeStore during body evaluation, so every view
            // using it re-renders on change. (No `.id` hammer here — keying
            // the tree destroyed all state: it ejected you from an open note
            // and re-locked the app on any theme tweak.)
        }
        .modelContainer(Persistence.shared)
        .commands { FormatCommands() }
    }
}
