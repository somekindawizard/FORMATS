import SwiftUI

@main
struct FernApp: App {
    var body: some Scene {
        WindowGroup {
            Text("Fern")
                .preferredColorScheme(.light)   // Fern is light-mode only, by design
        }
    }
}
