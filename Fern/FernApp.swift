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
            // Re-render the whole tree when the paper tone / accent changes so
            // the computed Paper.* colors are picked up everywhere.
            .id(theme.paletteKey)
            // Follows the system appearance — light paper, or its dark inverse.
        }
        .modelContainer(Persistence.shared)
    }
}
