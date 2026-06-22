import SwiftData

@Model
final class Tag {
    // Uniqueness by name is enforced in code when tagging (Plan 3),
    // not via @Attribute(.unique), which can trap SwiftData schema setup
    // on a fresh in-memory container in iOS 26.
    var name: String

    init(name: String) {
        self.name = name
    }
}
