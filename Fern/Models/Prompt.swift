import Foundation

enum PromptKind: String, Codable, CaseIterable, Identifiable {
    case journal, creative
    var id: String { rawValue }
    var title: String { self == .journal ? "Journal" : "Creative" }
}

enum PromptTheme: String, Codable, CaseIterable, Identifiable {
    case reflective, nature, nier, genshin
    case poetry, dreams, letters, worldbuilding, sparks, seasonal

    var id: String { rawValue }
    var title: String {
        switch self {
        case .reflective:   return "Reflective"
        case .nature:       return "Nature"
        case .nier:         return "NieR"
        case .genshin:      return "Genshin"
        case .poetry:       return "Poetry"
        case .dreams:       return "Dreams & Memory"
        case .letters:      return "Letters"
        case .worldbuilding: return "Worldbuilding"
        case .sparks:       return "Story Sparks"
        case .seasonal:     return "Seasonal"
        }
    }
}

/// One writing prompt. `text` is its stable identity (favorites/history key).
struct Prompt: Identifiable, Hashable {
    let text: String
    let kind: PromptKind
    let theme: PromptTheme
    var id: String { text }
}
