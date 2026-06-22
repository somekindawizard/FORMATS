import UserNotifications
import Foundation

/// Schedules a gentle daily notification at 7 pm carrying that day's journal
/// prompt. Local notifications only — no entitlement or Info.plist key needed.
/// We schedule a rolling window of upcoming days (each with its own prompt) and
/// refresh it on every launch so the text stays current.
enum PromptNotifier {
    static let enabledKey = "fern.notify.enabled"
    private static let fireHour = 19           // 7 pm
    private static let daysAhead = 14

    /// Default ON — the user asked for it.
    static var isEnabled: Bool {
        get { UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: enabledKey) }
    }

    /// Request permission if needed, then (re)schedule — or cancel if disabled.
    static func refresh() async {
        guard isEnabled else { cancelAll(); return }
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined:
            let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
            guard granted else { return }
        case .denied:
            return
        default:
            break
        }
        schedule()
    }

    private static func schedule() {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        let cal = Calendar.current
        let now = Date()

        for i in 0..<daysAhead {
            guard let day = cal.date(byAdding: .day, value: i, to: now) else { continue }
            var comps = cal.dateComponents([.year, .month, .day], from: day)
            comps.hour = fireHour
            comps.minute = 0
            // Skip a fire time that's already passed (only relevant for today).
            if let fireDate = cal.date(from: comps), fireDate <= now { continue }

            let prompt = PromptLibrary.daily(kind: .journal, theme: nil, on: day)
            let content = UNMutableNotificationContent()
            content.title = "Tonight's prompt"
            content.body = prompt?.text ?? "A blank page is waiting."
            content.sound = .default

            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            let request = UNNotificationRequest(identifier: "fern.prompt.\(i)",
                                                content: content, trigger: trigger)
            center.add(request)
        }
    }

    static func cancelAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}
