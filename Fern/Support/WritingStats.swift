import Foundation

/// Pure functions over a set of entries — words written this week and the
/// current daily writing streak. No SwiftData, fully testable.
enum WritingStats {

    /// Total word count of entries created within the current calendar week.
    static func wordsThisWeek(_ entries: [Entry], asOf now: Date = .now,
                              calendar: Calendar = .current) -> Int {
        guard let week = calendar.dateInterval(of: .weekOfYear, for: now) else { return 0 }
        return entries
            .filter { week.contains($0.createdAt) }
            .reduce(0) { $0 + $1.wordCount }
    }

    /// Consecutive days (ending today) on which at least one entry was created.
    /// If nothing was written today, the streak is 0.
    static func currentStreak(_ entries: [Entry], asOf now: Date = .now,
                              calendar: Calendar = .current) -> Int {
        let days = Set(entries.map { calendar.startOfDay(for: $0.createdAt) })
        guard !days.isEmpty else { return 0 }
        var streak = 0
        var day = calendar.startOfDay(for: now)
        while days.contains(day) {
            streak += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = prev
        }
        return streak
    }
}
