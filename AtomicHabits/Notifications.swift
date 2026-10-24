import Foundation
import UserNotifications

/// Anchor reminders (Cue — "make it obvious"): a local notification that
/// fires at each habit's cue time, worded around its anchor
/// ("After you finish lunch…"). Permission is requested only when the user
/// taps "Set anchor reminder"; denial is handled gracefully — scheduling
/// simply no-ops and the app never crashes or nags.
enum AnchorNotifications {
    static func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    static func identifier(for habit: Habit) -> String {
        "anchor-\(habit.id.uuidString)"
    }

    /// Parse "HH:mm" into hour/minute components.
    static func components(from cueTime: String) -> (hour: Int, minute: Int)? {
        let parts = cueTime.split(separator: ":")
        guard parts.count == 2, let h = Int(parts[0]), let m = Int(parts[1]),
              (0...23).contains(h), (0...59).contains(m) else { return nil }
        return (h, m)
    }

    static func schedule(for habit: Habit) {
        guard let hm = components(from: habit.cueTime) else { return }
        let content = UNMutableNotificationContent()
        content.title = habit.title
        if habit.anchor.isEmpty {
            content.body = "Your cue: \(habit.cuePlace.isEmpty ? "time to cast a vote." : "at \(habit.cuePlace).")"
        } else {
            content.body = "After you \(habit.anchor) — \(habit.title.lowercased())."
        }
        content.sound = .default
        var date = DateComponents()
        date.hour = hm.hour
        date.minute = hm.minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: date, repeats: true)
        let request = UNNotificationRequest(identifier: identifier(for: habit),
                                            content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { _ in
            // Denied permission or any scheduling error: silently no-op.
        }
    }

    static func cancel(for habit: Habit) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [identifier(for: habit)])
    }

    static func rescheduleAll(_ habits: [Habit]) {
        for habit in habits where !habit.cueTime.isEmpty {
            schedule(for: habit)
        }
    }
}
