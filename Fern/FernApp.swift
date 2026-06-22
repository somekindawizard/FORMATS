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
            .preferredColorScheme(.light)   // Fern is light-mode only, by design
        }
        .modelContainer(Persistence.shared)
    }
}
