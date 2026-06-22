import SwiftUI
import SwiftData

@main
struct FernApp: App {
    @State private var lock = BiometricLock()

    var body: some Scene {
        WindowGroup {
            LockGate {
                RootView()
            }
            .environment(lock)
            // Follows the system appearance — light paper, or its dark inverse.
        }
        .modelContainer(Persistence.shared)
    }
}
