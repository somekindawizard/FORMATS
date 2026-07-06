import LocalAuthentication
import SwiftUI

@Observable
final class BiometricLock {
    static let userDefaultsKey = "fern.lock.enabled"

    /// Whether the user has enabled the lock in Settings.
    var isEnabled: Bool {
        didSet { UserDefaults.standard.set(isEnabled, forKey: Self.userDefaultsKey) }
    }

    /// Whether the user is currently authenticated within this app session.
    var isUnlocked: Bool

    /// True while the lock-gate veil (welcome ritual or auth) covers the app.
    /// Kept in sync by LockGate; lets other layers defer presenting content
    /// (e.g. a Spotlight result sheet) until the gate has been passed.
    var gateVisible = false

    init() {
        let enabled = UserDefaults.standard.bool(forKey: Self.userDefaultsKey)
        self.isEnabled = enabled
        // If the lock isn't enabled, we're effectively unlocked.
        self.isUnlocked = !enabled
    }

    /// Trigger the system Face ID / passcode prompt. Returns true on success.
    @discardableResult
    func authenticate() async -> Bool {
        let ctx = LAContext()
        ctx.localizedReason = "Open Fern"
        var err: NSError?
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthentication, error: &err) else {
            isUnlocked = true // no biometrics available → degrade open
            return true
        }
        do {
            let ok = try await ctx.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: "Open Fern"
            )
            if ok { isUnlocked = true }
            return ok
        } catch {
            return false
        }
    }

    /// Called when the app is backgrounded so re-foregrounding re-locks.
    func relock() { if isEnabled { isUnlocked = false } }

    /// A standalone Face ID / passcode check, independent of the app lock —
    /// used to unlock an individual locked note. Degrades open if biometrics
    /// are unavailable.
    static func authenticateOnce(reason: String) async -> Bool {
        let ctx = LAContext()
        var err: NSError?
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthentication, error: &err) else {
            return true
        }
        return (try? await ctx.evaluatePolicy(.deviceOwnerAuthentication,
                                              localizedReason: reason)) ?? false
    }
}
