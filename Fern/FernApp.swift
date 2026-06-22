import SwiftUI
import SwiftData

@main
struct FernApp: App {
    @State private var lock = BiometricLock()
    @State private var promptStore = PromptStore()

    var body: some Scene {
        WindowGroup {
            LockGate {
                RootView()
            }
            .environment(lock)
            .environment(promptStore)
            // Follows the system appearance — light paper, or its dark inverse.
        }
        .modelContainer(Persistence.shared)
    }
}
