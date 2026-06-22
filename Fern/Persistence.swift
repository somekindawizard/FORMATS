import SwiftData

enum Persistence {
    /// The app's shared on-device container. CloudKit is layered on in Plan 7.
    static let shared: ModelContainer = {
        do {
            return try ModelContainer(for: Entry.self, Tag.self, Attachment.self)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }()

    /// An in-memory container for previews and tests.
    @MainActor
    static func inMemory() -> ModelContainer {
        try! ModelContainer(
            for: Entry.self, Tag.self, Attachment.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }
}
