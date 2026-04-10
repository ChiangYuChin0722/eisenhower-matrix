import Foundation

// MARK: - Shared widget data model
// The main app (TaskStore) writes this JSON to the App Group UserDefaults.
// The widget extension reads it here.

private let appGroupSuite = "group.com.eisenhower.matrix"
private let snapshotKey   = "widgetSnapshot"

struct WidgetSnapshot: Codable {
    let totalCount:         Int
    let completedCount:     Int
    let pendingCount:       Int
    let currentStreak:      Int
    let upcomingDeadlines:  [WidgetDeadline]

    // MARK: Load from shared defaults
    static func load() -> WidgetSnapshot {
        guard let defaults = UserDefaults(suiteName: appGroupSuite),
              let data     = defaults.data(forKey: snapshotKey),
              let snapshot = try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
        else { return .placeholder }
        return snapshot
    }

    // MARK: Placeholder / preview data
    static let placeholder = WidgetSnapshot(
        totalCount:        12,
        completedCount:     5,
        pendingCount:       7,
        currentStreak:      3,
        upcomingDeadlines: [
            WidgetDeadline(id: UUID(), title: "Prepare client meeting",
                           dueDate: Date().addingTimeInterval(7200),
                           quadrantRaw: "do", isOverdue: false),
            WidgetDeadline(id: UUID(), title: "AWS certification",
                           dueDate: Date().addingTimeInterval(86400),
                           quadrantRaw: "schedule", isOverdue: false),
            WidgetDeadline(id: UUID(), title: "Book hair appointment",
                           dueDate: Date().addingTimeInterval(259200),
                           quadrantRaw: "delegate", isOverdue: false),
        ]
    )
}

struct WidgetDeadline: Codable, Identifiable {
    let id:          UUID
    let title:       String
    let dueDate:     Date
    let quadrantRaw: String   // "do" | "schedule" | "delegate" | "eliminate"
    let isOverdue:   Bool

    var quadrantColor: String {
        switch quadrantRaw {
        case "do":        return "red"
        case "schedule":  return "blue"
        case "delegate":  return "orange"
        default:          return "gray"
        }
    }
}
