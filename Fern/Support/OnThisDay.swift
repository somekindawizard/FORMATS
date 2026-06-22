import Foundation

/// Finds past entries that share today's month and day (a year or more ago) —
/// the "on this day" resurfacing that journalers love. Pure and testable.
enum OnThisDay {
    /// Entries from earlier years matching `asOf`'s month/day, newest first.
    static func entries(from entries: [Entry], asOf now: Date = .now,
                        calendar: Calendar = .current) -> [Entry] {
        let today = calendar.dateComponents([.month, .day, .year], from: now)
        return entries
            .filter { entry in
                let c = calendar.dateComponents([.month, .day, .year], from: entry.createdAt)
                return c.month == today.month && c.day == today.day && (c.year ?? 0) < (today.year ?? 0)
            }
            .sorted { $0.createdAt > $1.createdAt }
    }
}
