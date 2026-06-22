import SwiftUI
import SwiftData

@main
struct FernApp: App {
    @State private var lock = BiometricLock()
    @State private var promptStore = PromptStore()
    @State private var theme = ThemeStore.shared

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
