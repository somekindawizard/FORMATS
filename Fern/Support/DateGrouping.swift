import Foundation

struct DaySection: Identifiable {
    let day: Date            // start of day
    let entries: [Entry]
    var id: Date { day }
}

enum DayGrouping {
    /// Group entries by calendar day, days newest-first, entries newest-first within a day.
    static func sections(from entries: [Entry], calendar: Calendar = .current) -> [DaySection] {
        let groups = Dictionary(grouping: entries) { calendar.startOfDay(for: $0.createdAt) }
        return groups
            .map { day, items in
                DaySection(day: day, entries: items.sorted { $0.createdAt > $1.createdAt })
            }
            .sorted { $0.day > $1.day }
    }
}
