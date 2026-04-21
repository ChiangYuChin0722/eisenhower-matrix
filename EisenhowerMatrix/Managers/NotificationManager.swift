import UserNotifications
import EventKit
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

// MARK: - EventKitManager

final class EventKitManager {
    static let shared = EventKitManager()
    private init() {}

    private let store         = EKEventStore()
    private let calendarTitle = "Eisenhower Matrix"

    var isAuthorized: Bool {
        let status = EKEventStore.authorizationStatus(for: .event)
        if #available(iOS 17.0, *) {
            return status == .fullAccess
        } else {
            return status == .authorized
        }
    }

    func requestAccess() async -> Bool {
        do {
            if #available(iOS 17.0, *) {
                return try await store.requestFullAccessToEvents()
            } else {
                return try await withCheckedThrowingContinuation { cont in
                    store.requestAccess(to: .event) { granted, error in
                        if let error = error { cont.resume(throwing: error) }
                        else                 { cont.resume(returning: granted) }
                    }
                }
            }
        } catch {
            return false
        }
    }

    private var eisenhowerCalendar: EKCalendar? {
        if let existing = store.calendars(for: .event).first(where: { $0.title == calendarTitle }) {
            return existing
        }
        let cal = EKCalendar(for: .event, eventStore: store)
        cal.title = calendarTitle
        let sources = store.sources
        if let src = sources.first(where: { $0.sourceType == .calDAV && $0.title.lowercased().contains("icloud") })
            ?? sources.first(where: { $0.sourceType == .calDAV })
            ?? sources.first(where: { $0.sourceType == .local }) {
            cal.source = src
        } else {
            return nil
        }
        try? store.saveCalendar(cal, commit: true)
        return cal
    }

    @discardableResult
    func upsertEvent(for task: EisTask) -> String? {
        guard isAuthorized, let dueDate = task.dueDate else { return nil }
        guard let calendar = eisenhowerCalendar else { return nil }

        let event: EKEvent
        if let existingId = task.calendarEventId,
           let existing = store.event(withIdentifier: existingId) {
            event = existing
        } else {
            event = EKEvent(eventStore: store)
            event.calendar = calendar
        }

        event.title = task.title
        let cal = Calendar.current
        let h   = cal.component(.hour,   from: dueDate)
        let m   = cal.component(.minute, from: dueDate)
        if h == 0 && m == 0 {
            event.isAllDay  = true
            event.startDate = dueDate
            event.endDate   = dueDate
        } else {
            event.isAllDay  = false
            event.startDate = dueDate
            event.endDate   = cal.date(byAdding: .hour, value: 1, to: dueDate) ?? dueDate
        }
        event.notes = task.notes.isEmpty ? nil : task.notes

        do {
            try store.save(event, span: .thisEvent, commit: true)
            return event.eventIdentifier
        } catch {
            return nil
        }
    }

    func deleteEvent(id: String) {
        guard isAuthorized else { return }
        if let event = store.event(withIdentifier: id) {
            try? store.remove(event, span: .thisEvent, commit: true)
        }
    }

    func loadEvents(for date: Date) -> [EKEvent] {
        guard isAuthorized else { return [] }
        let cal = Calendar.current
        let start = cal.startOfDay(for: date)
        guard let end = cal.date(byAdding: .day, value: 1, to: start) else { return [] }
        let calendars = store.calendars(for: .event).filter { $0.title != calendarTitle }
        guard !calendars.isEmpty else { return [] }
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: calendars)
        return store.events(matching: predicate).sorted { $0.startDate < $1.startDate }
    }
}
