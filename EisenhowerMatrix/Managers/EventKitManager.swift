import EventKit
import Foundation

final class EventKitManager {
    static let shared = EventKitManager()
    private init() {}

    private let store = EKEventStore()
    private let calendarTitle = "Eisenhower Matrix"

    var isAuthorized: Bool {
        let status = EKEventStore.authorizationStatus(for: .event)
        if #available(iOS 17.0, *) {
            return status == .writeOnly || status == .fullAccess
        } else {
            return status == .authorized
        }
    }

    func requestAccess() async -> Bool {
        do {
            if #available(iOS 17.0, *) {
                return try await store.requestWriteOnlyAccessToEvents()
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
        // Prefer iCloud source, then any calDAV, then local
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

    /// Create or update an iOS Calendar event for the task.
    /// Returns the event identifier to store back on the task.
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
        let h = cal.component(.hour, from: dueDate)
        let m = cal.component(.minute, from: dueDate)
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
}
