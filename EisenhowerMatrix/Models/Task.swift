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

    /// Default canvas fraction position for this quadrant
    static func randomPosition(for quadrant: Quadrant) -> (x: Double, y: Double) {
        // x: 0 = not urgent (left), 1 = urgent (right)
        // y: 0 = important (top),   1 = not important (bottom)
        let r = { Double.random(in: 0.08...0.35) }
        switch quadrant {
        case .doFirst:   return (0.5 + r(), r())          // top-right
        case .schedule:  return (r(),       r())           // top-left
        case .delegate:  return (0.5 + r(), 0.5 + r())    // bottom-right
        case .eliminate: return (r(),       0.5 + r())     // bottom-left
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

    // Canvas position: x in [0,1] (left=not urgent, right=urgent)
    //                  y in [0,1] (top=important, bottom=not important)
    var canvasX: Double
    var canvasY: Double

    init(
        title: String,
        quadrant: Quadrant,
        canvasX: Double? = nil,
        canvasY: Double? = nil,
        isCompleted: Bool = false,
        dueDate: Date? = nil,
        notes: String = ""
    ) {
        self.title       = title
        self.quadrant    = quadrant
        self.isCompleted = isCompleted
        self.dueDate     = dueDate
        self.notes       = notes
        let (defaultX, defaultY) = Quadrant.randomPosition(for: quadrant)
        self.canvasX = canvasX ?? defaultX
        self.canvasY = canvasY ?? defaultY
    }

    static func == (lhs: EisTask, rhs: EisTask) -> Bool { lhs.id == rhs.id }
}
