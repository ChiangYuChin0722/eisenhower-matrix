import Foundation
import SwiftUI

enum Quadrant: String, Codable, CaseIterable, Identifiable {
    case doFirst = "do"
    case schedule = "schedule"
    case delegate = "delegate"
    case eliminate = "eliminate"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .doFirst:   return "Do"
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

    var actionHint: String {
        switch self {
        case .doFirst:   return "Things to Do Quickly"
        case .schedule:  return "Things that require planning"
        case .delegate:  return "Things you can delegate"
        case .eliminate: return "Things that can be organized"
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
        case .doFirst:   return .red
        case .schedule:  return .blue
        case .delegate:  return .orange
        case .eliminate: return .green
        }
    }

    var isUrgent: Bool    { self == .doFirst || self == .delegate }
    var isImportant: Bool { self == .doFirst || self == .schedule }
}

enum TaskColor: String, Codable, CaseIterable {
    case none   = "none"
    case red    = "red"
    case orange = "orange"
    case blue   = "blue"
    case green  = "green"
    case purple = "purple"
    case pink   = "pink"

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

struct EisTask: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var title: String
    var notes: String = ""
    var quadrant: Quadrant
    var isCompleted: Bool = false
    var dueDate: Date? = nil
    var createdAt: Date = Date()
    var subtasks: [EisTask] = []
    var colorTag: TaskColor = .none

    static func == (lhs: EisTask, rhs: EisTask) -> Bool { lhs.id == rhs.id }

    var completedSubtaskCount: Int { subtasks.filter { $0.isCompleted }.count }
    var totalSubtaskCount: Int     { subtasks.count }
    var progress: Double {
        guard totalSubtaskCount > 0 else { return isCompleted ? 1.0 : 0.0 }
        return Double(completedSubtaskCount) / Double(totalSubtaskCount)
    }
}
