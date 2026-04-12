import Foundation
import SwiftUI

enum Quadrant: String, Codable, CaseIterable, Identifiable {
    case doFirst   = "do"
    case schedule  = "schedule"
    case delegate  = "delegate"
    case eliminate = "eliminate"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .doFirst:   return "Do Now"
        case .schedule:  return "Schedule"
        case .delegate:  return "Delegate"
        case .eliminate: return "Eliminate"
        }
    }

    var subtitle: String {
        switch self {
        case .doFirst:   return "Urgent & Important"
        case .schedule:  return "Not Urgent & Important"
        case .delegate:  return "Urgent & Not Important"
        case .eliminate: return "Not Urgent & Not Important"
        }
    }

    var emoji: String {
        switch self {
        case .doFirst:   return "🚀"
        case .schedule:  return "🔥"
        case .delegate:  return "👥"
        case .eliminate: return "🗂️"
        }
    }

    var color: Color {
        switch self {
        case .doFirst:   return Color(red: 0.85, green: 0.22, blue: 0.22)
        case .schedule:  return Color(red: 0.20, green: 0.44, blue: 0.85)
        case .delegate:  return Color(red: 0.92, green: 0.55, blue: 0.14)
        case .eliminate: return Color(red: 0.36, green: 0.36, blue: 0.38)
        }
    }

    var bgColor: Color {
        switch self {
        case .doFirst:   return Color(red: 0.85, green: 0.22, blue: 0.22).opacity(0.07)
        case .schedule:  return Color(red: 0.20, green: 0.44, blue: 0.85).opacity(0.07)
        case .delegate:  return Color(red: 0.92, green: 0.55, blue: 0.14).opacity(0.06)
        case .eliminate: return Color(red: 0.36, green: 0.36, blue: 0.38).opacity(0.04)
        }
    }

    var isUrgent: Bool    { self == .doFirst || self == .delegate }
    var isImportant: Bool { self == .doFirst || self == .schedule }

    static func randomPosition(for quadrant: Quadrant) -> (x: Double, y: Double) {
        let r = { Double.random(in: 0.08...0.35) }
        switch quadrant {
        case .doFirst:   return (0.5 + r(), r())
        case .schedule:  return (r(),       r())
        case .delegate:  return (0.5 + r(), 0.5 + r())
        case .eliminate: return (r(),       0.5 + r())
        }
    }

    static func from(canvasX x: Double, canvasY y: Double) -> Quadrant {
        switch (x >= 0.5, y < 0.5) {
        case (true,  true):  return .doFirst
        case (false, true):  return .schedule
        case (true,  false): return .delegate
        case (false, false): return .eliminate
        }
    }
}

enum TaskColor: String, Codable, CaseIterable {
    case none, red, orange, blue, green, purple, pink

    var color: Color {
        switch self {
        case .none:   return .clear
        case .red:    return .red
        case .orange: return .orange
        case .blue:   return .blue
        case .green:  return .green
        case .purple: return .purple
        case .pink:   return .pink
        }
    }
}

// MARK: - Recurrence

enum Recurrence: String, Codable, CaseIterable, Identifiable {
    case none     = "none"
    case daily    = "daily"
    case weekdays = "weekdays"
    case weekly   = "weekly"
    case monthly  = "monthly"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none:     return "No Recurrence"
        case .daily:    return "Daily"
        case .weekdays: return "Weekdays (Mon–Fri)"
        case .weekly:   return "Weekly"
        case .monthly:  return "Monthly"
        }
    }

    var icon: String {
        switch self {
        case .none:     return "minus"
        case .daily:    return "arrow.clockwise"
        case .weekdays: return "briefcase"
        case .weekly:   return "calendar.badge.clock"
        case .monthly:  return "calendar"
        }
    }

    /// Returns the next due date after `date` for this recurrence, or nil if `.none`.
    func nextDate(after date: Date) -> Date? {
        guard self != .none else { return nil }
        let cal = Calendar.current
        switch self {
        case .none:    return nil
        case .daily:   return cal.date(byAdding: .day,        value: 1, to: date)
        case .weekly:  return cal.date(byAdding: .weekOfYear, value: 1, to: date)
        case .monthly: return cal.date(byAdding: .month,      value: 1, to: date)
        case .weekdays:
            var next = cal.date(byAdding: .day, value: 1, to: date)!
            while [1, 7].contains(cal.component(.weekday, from: next)) {
                next = cal.date(byAdding: .day, value: 1, to: next)!
            }
            return next
        }
    }
}

// MARK: - ChecklistCategory

struct ChecklistCategory: Identifiable, Codable, Equatable {
    var id: UUID   = UUID()
    var name: String
    var icon: String   // SF Symbol name

    static let general  = ChecklistCategory(name: "General",  icon: "list.bullet")
    static let shopping = ChecklistCategory(name: "Shopping",  icon: "cart")
    static let work     = ChecklistCategory(name: "Work",      icon: "briefcase")
}

// MARK: - EisTask

struct EisTask: Identifiable, Codable, Equatable {
    var id: UUID           = UUID()
    var title: String
    var notes: String      = ""
    var quadrant: Quadrant
    var isCompleted: Bool  = false
    var dueDate: Date?     = nil
    var createdAt: Date    = Date()
    var completedAt: Date? = nil
    var subtasks: [EisTask]  = []
    var colorTag: TaskColor  = .none
    var colorTagLabel: String = ""
    var sortOrder: Int       = 0
    var isInChecklist: Bool  = false
    var canvasX: Double
    var canvasY: Double
    var recurrence: Recurrence      = .none
    var checklistCategoryId: UUID?  = nil
    var showInMatrix: Bool?         = nil   // nil = true (backward-compatible)

    var completedSubtaskCount: Int { subtasks.filter { $0.isCompleted }.count }
    var totalSubtaskCount: Int     { subtasks.count }

    init(
        title: String,
        quadrant: Quadrant,
        canvasX: Double?  = nil,
        canvasY: Double?  = nil,
        isCompleted: Bool = false,
        dueDate: Date?    = nil,
        notes: String     = "",
        isInChecklist: Bool       = false,
        recurrence: Recurrence    = .none,
        checklistCategoryId: UUID? = nil
    ) {
        self.title               = title
        self.quadrant            = quadrant
        self.isCompleted         = isCompleted
        self.dueDate             = dueDate
        self.notes               = notes
        self.isInChecklist       = isInChecklist
        self.recurrence          = recurrence
        self.checklistCategoryId = checklistCategoryId
        let pos = Quadrant.randomPosition(for: quadrant)
        self.canvasX = canvasX ?? pos.x
        self.canvasY = canvasY ?? pos.y
    }

    static func == (lhs: EisTask, rhs: EisTask) -> Bool { lhs.id == rhs.id }
}
