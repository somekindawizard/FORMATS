import SwiftUI

/// Persists the prompts a writer has favorited and the ones they've seen,
/// in UserDefaults (keyed by prompt text). Shared via the environment.
@Observable
final class PromptStore {
    private static let favKey  = "fern.prompts.favorites"
    private static let histKey = "fern.prompts.history"
    private static let historyCap = 60

    private(set) var favorites: Set<String>
    private(set) var history: [String]   // most-recent first

    init() {
        favorites = Set(UserDefaults.standard.stringArray(forKey: Self.favKey) ?? [])
        history = UserDefaults.standard.stringArray(forKey: Self.histKey) ?? []
    }

    func isFavorite(_ text: String) -> Bool { favorites.contains(text) }

    func toggleFavorite(_ text: String) {
        if favorites.contains(text) { favorites.remove(text) } else { favorites.insert(text) }
        UserDefaults.standard.set(Array(favorites), forKey: Self.favKey)
    }

    /// Record that a prompt was shown, moving it to the front of history.
    func recordShown(_ text: String) {
        guard !text.isEmpty else { return }
        history.removeAll { $0 == text }
        history.insert(text, at: 0)
        if history.count > Self.historyCap { history = Array(history.prefix(Self.historyCap)) }
        UserDefaults.standard.set(history, forKey: Self.histKey)
    }

    /// Favorited prompts resolved back to full `Prompt`s (for the saved list).
    var favoritePrompts: [Prompt] {
        PromptLibrary.all.filter { favorites.contains($0.text) }
    }
}
