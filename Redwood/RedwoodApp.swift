import SwiftUI
import SwiftData

/// Redwood — Fern's sibling for long-form writing. Same paper-and-ink soul,
/// built on the shared editor/render/theme layer; where Fern keeps a flat
/// journal, Redwood organizes a manuscript into a binder of folders and
/// documents.
@main
struct RedwoodApp: App {
    @State private var theme = ThemeStore.shared

    init() { Fonts.register() }

    var body: some Scene {
        WindowGroup {
            BinderView()
                .tint(Paper.accent)
                .environment(theme)
                // Re-render when the accent (paletteKey) changes so Paper.* colors refresh.
                .id(theme.paletteKey)
        }
        .modelContainer(for: [RWProject.self, RWDocument.self, RWSnapshot.self])
    }
}
