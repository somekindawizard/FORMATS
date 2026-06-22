import SwiftData

enum Persistence {
    /// The app's store, schema is `Entry` only — fully CloudKit-compatible
    /// (every property optional or defaulted, no unique constraints, no
    /// relationships).
    ///
    /// The container uses SwiftData's default `.automatic` CloudKit mode: with
    /// no iCloud entitlement it's a local store; once the iCloud/CloudKit
    /// capability is added in Xcode, the same code syncs across the user's
    /// devices via their private iCloud — no code change required.
    static let shared: ModelContainer = {
        do {
            return try ModelContainer(for: Entry.self)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }()

    /// An in-memory container for previews.
    @MainActor
    static func inMemory() -> ModelContainer {
        try! ModelContainer(
            for: Entry.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }
}
