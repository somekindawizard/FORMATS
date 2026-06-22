import SwiftUI

/// An entry's intent. Both live in one library.
enum Collection: String, Codable, CaseIterable, Identifiable {
    case journal, piece
    var id: String { rawValue }
    var title: String { self == .journal ? "Journal" : "Pieces" }
}

/// Optional mood captured on an entry. Maps later to State of Mind (Plans 4/6).
enum Mood: String, Codable, CaseIterable, Identifiable {
    case calm, glad, tender, clear, restless, low
    var id: String { rawValue }
    var label: String { rawValue.capitalized }
    /// SF Symbol used in the mood chip.
    var symbol: String {
        switch self {
        case .calm:     return "leaf"
        case .glad:     return "sun.max"
        case .tender:   return "heart"
        case .clear:    return "circle"
        case .restless: return "wind"
        case .low:      return "cloud"
        }
    }
}
