import Foundation

/// Syncs the writer's name across their devices via iCloud key-value storage,
/// mirrored into `UserDefaults` so the `@AppStorage("fern.userName")` UI picks
/// it up. Small, single-value prefs like this belong in the KV store, not the
/// CloudKit document database.
enum NameSync {
    static let key = "fern.userName"
    private static let store = NSUbiquitousKeyValueStore.default

    /// Begin observing iCloud for external changes and pull the current value.
    static func start() {
        NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: store, queue: .main) { _ in pull() }
        store.synchronize()
        pull()
    }

    /// Copy iCloud's value into UserDefaults (so @AppStorage updates), if newer.
    static func pull() {
        guard let remote = store.string(forKey: key), !remote.isEmpty else { return }
        if UserDefaults.standard.string(forKey: key) != remote {
            UserDefaults.standard.set(remote, forKey: key)
        }
    }

    /// Push a locally-set name up to iCloud (and keep UserDefaults in step).
    static func push(_ name: String) {
        UserDefaults.standard.set(name, forKey: key)
        store.set(name, forKey: key)
        store.synchronize()
    }
}
