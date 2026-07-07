import Foundation

struct DaySection: Identifiable {
    let day: Date            // start of day
    let entries: [Entry]
    var id: Date { day }
}

enum DayGrouping {
    /// Group entries by calendar day of `date` (created by default — the
    /// library can also section by last-written or last-opened), days
    /// newest-first, entries newest-first within a day.
    static func sections(from entries: [Entry],
                         by date: KeyPath<Entry, Date> = \.createdAt,
                         calendar: Calendar = .current) -> [DaySection] {
        let groups = Dictionary(grouping: entries) { calendar.startOfDay(for: $0[keyPath: date]) }
        return groups
            .map { day, items in
                DaySection(day: day, entries: items.sorted { $0[keyPath: date] > $1[keyPath: date] })
            }
            .sorted { $0.day > $1.day }
    }
}
