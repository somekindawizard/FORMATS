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

    /// Consecutive days on which at least one entry was created, ending today
    /// or yesterday. A chain that ended yesterday isn't broken — you just
    /// haven't written *yet* today ("streak at risk") — so an unbroken 30-day
    /// run reads 30 at breakfast, not 0. Only a full missed day resets it.
    static func currentStreak(_ entries: [Entry], asOf now: Date = .now,
                              calendar: Calendar = .current) -> Int {
        let days = Set(entries.map { calendar.startOfDay(for: $0.createdAt) })
        guard !days.isEmpty else { return 0 }
        var day = calendar.startOfDay(for: now)
        if !days.contains(day) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: day),
                  days.contains(yesterday) else { return 0 }
            day = yesterday
        }
        var streak = 0
        while days.contains(day) {
            streak += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = prev
        }
        return streak
    }

    /// True when the streak is alive only by grace of yesterday — nothing
    /// written yet today. Lets the UI whisper "write today to keep it."
    static func streakAtRisk(_ entries: [Entry], asOf now: Date = .now,
                             calendar: Calendar = .current) -> Bool {
        let today = calendar.startOfDay(for: now)
        let wroteToday = entries.contains { calendar.startOfDay(for: $0.createdAt) == today }
        return !wroteToday && currentStreak(entries, asOf: now, calendar: calendar) > 0
    }
}
