import Foundation

/// The whole prompt library, assembled from the themed content files
/// (`Prompts+*.swift`, each of which extends this enum with a static array).
enum PromptLibrary {

    /// Every prompt across all packs.
    static let all: [Prompt] =
        reflective + nature + nier + genshin
        + poetry + dreams + letters + worldbuilding + sparks + seasonal

    /// Filter by kind and (optional) theme. `nil` theme means "all packs".
    static func prompts(kind: PromptKind, theme: PromptTheme?) -> [Prompt] {
        all.filter { $0.kind == kind && (theme == nil || $0.theme == theme) }
    }

    /// A deterministic pick for a kind+theme on a given day — the same all day,
    /// rotating over time. Journal and creative differ on the same date.
    static func daily(kind: PromptKind, theme: PromptTheme?,
                      on date: Date = .now, calendar: Calendar = .current) -> Prompt? {
        let pool = prompts(kind: kind, theme: theme)
        guard !pool.isEmpty else { return nil }
        let day = calendar.ordinality(of: .day, in: .era, for: date) ?? 0
        let offset = kind == .creative ? 9173 : 0
        let i = ((day + offset) % pool.count + pool.count) % pool.count
        return pool[i]
    }

    /// A random prompt of the kind+theme, optionally avoiding a repeat.
    static func random(kind: PromptKind, theme: PromptTheme?, excluding: String? = nil) -> Prompt? {
        var pool = prompts(kind: kind, theme: theme)
        if pool.count > 1, let excluding { pool.removeAll { $0.text == excluding } }
        return pool.randomElement()
    }
}
