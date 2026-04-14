import UserNotifications
import Foundation

final class NotificationManager {
    static let shared = NotificationManager()
    private init() {}

    func requestPermission() {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    /// Schedule a "due in 1 hour" reminder. Cancels any previous notification for this task.
    func scheduleNotification(for task: EisTask) {
        cancelNotification(for: task)
        guard let due = task.dueDate, !task.isCompleted else { return }
        guard let triggerDate = Calendar.current.date(byAdding: .hour, value: -1, to: due),
              triggerDate > Date() else { return }

        let content       = UNMutableNotificationContent()
        content.title     = "Due in 1 hour"
        content.body      = task.title
        content.sound     = .default

        let comps   = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let request = UNNotificationRequest(identifier: task.id.uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    func cancelNotification(for task: EisTask) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [task.id.uuidString])
    }

    func cancelAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
    }

    func getAuthorizationStatus(completion: @escaping (UNAuthorizationStatus) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async { completion(settings.authorizationStatus) }
        }
    }
}
