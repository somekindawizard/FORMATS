import SwiftUI
import SwiftData

@main
struct FernApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.light)   // Fern is light-mode only, by design
        }
        .modelContainer(Persistence.shared)
    }
}
