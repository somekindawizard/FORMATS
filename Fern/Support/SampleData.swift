import SwiftData
import Foundation

enum SampleData {
    /// Insert a few entries so previews and a fresh install aren't empty.
    @MainActor
    static func seed(into context: ModelContext) {
        let cal = Calendar.current
        func daysAgo(_ n: Int, hour: Int = 8) -> Date {
            cal.date(byAdding: .day, value: -n, to: cal.startOfDay(for: .now))!
                .addingTimeInterval(TimeInterval(hour * 3600))
        }

        let e1 = Entry(
            title: "The light over Lady Bird",
            body: "I walked the trail before the heat came up and the water was perfectly still.",
            collection: .journal,
            createdAt: daysAgo(0, hour: 7),
            mood: .calm
        )
        let e2 = Entry(
            title: "Cicada draft",
            body: "all summer they rehearse / one note, then the whole orchestra at once",
            collection: .piece,
            createdAt: daysAgo(2),
            isPinned: true
        )
        let e3 = Entry(
            title: "On finishing things",
            body: "The hardest part was never the starting.",
            collection: .piece,
            createdAt: daysAgo(5)
        )
        [e1, e2, e3].forEach { context.insert($0) }
        try? context.save()
    }

    @MainActor
    static func previewContainer() -> ModelContainer {
        let container = Persistence.inMemory()
        seed(into: container.mainContext)
        return container
    }
}
