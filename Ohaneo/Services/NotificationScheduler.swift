import Foundation
import OhaneoCore
import UserNotifications

/// Schedules the once-a-day reminder for the next week. Each notification names
/// the day's item when it has already been prepared.
@MainActor
enum NotificationScheduler {
    private static let prefix = "daily-"
    private static var center: UNUserNotificationCenter { .current() }

    static func requestAuthorization() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
    }

    static func isAuthorized() async -> Bool {
        let settings = await center.notificationSettings()
        return settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
    }

    static func reschedule(preferences: StudyPreferences, preview: [(day: Date, item: StudyItem?)], calendar: Calendar = .current) async {
        let pending = await center.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix(prefix) }
        center.removePendingNotificationRequests(withIdentifiers: pending)

        guard preferences.notificationsEnabled, preferences.placement != nil, await isAuthorized() else { return }

        for entry in preview {
            var components = calendar.dateComponents([.year, .month, .day], from: entry.day)
            components.hour = preferences.notificationHour
            components.minute = preferences.notificationMinute

            let content = UNMutableNotificationContent()
            content.title = "오한어"
            content.body = body(for: entry.item)
            content.sound = nil

            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let id = prefix + (calendar.date(from: components)?.ISO8601Format() ?? UUID().uuidString)
            try? await center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
        }
    }

    private static func body(for item: StudyItem?) -> String {
        guard let item else { return "Today's Korean is ready." }
        switch item.kind {
        case .word: return "Today's word: \(item.korean)"
        case .phrase: return "Today's phrase: \(item.korean)"
        case .grammar: return "Today's grammar: \(item.korean)"
        }
    }
}
