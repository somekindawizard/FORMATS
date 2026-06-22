import Foundation

/// A small, curated set of gentle writing prompts. One is chosen per calendar
/// day, deterministically, so "today's prompt" is stable through the day but
/// rotates over time. Never nagging — the user can always ignore it.
enum Prompts {
    static let all: [String] = [
        "What has quietly stayed with you?",
        "Describe the light wherever you are right now.",
        "What did today ask of you?",
        "Write down something you noticed that no one else did.",
        "What are you slowly changing your mind about?",
        "Name a small mercy from the last day or two.",
        "What would you tell yourself a year ago?",
        "What's a sentence you keep coming back to?",
        "Describe a sound from today.",
        "What felt true this week, even briefly?",
        "Who were you with, and what did you carry away?",
        "What's unfinished, and how does that sit with you?",
        "Write about a doorway — literal or not.",
        "What did you make room for today?",
        "What are you grateful for that's easy to overlook?"
    ]

    /// Deterministic prompt for a given day.
    static func forToday(_ now: Date = .now, calendar: Calendar = .current) -> String {
        let day = calendar.ordinality(of: .day, in: .era, for: now) ?? 0
        return all[((day % all.count) + all.count) % all.count]
    }
}
