import Foundation
import Combine
import WidgetKit

class TaskStore: ObservableObject {
    @Published var tasks: [EisTask]                      = []
    @Published var checklistCategories: [ChecklistCategory] = []

    // v4: added Recurrence, ChecklistCategory, completedAt
    private let saveKey       = "eisenhower_tasks_v4"
    private let categoriesKey = "eisenhower_categories_v1"
    // Shared with Widget Extension via App Group (set up group in Xcode → Signing & Capabilities)
    private let defaults = UserDefaults(suiteName: "group.com.eisenhower.matrix") ?? .standard

    init() {
        loadCategories()
        loadTasks()
        if tasks.isEmpty { loadSampleData() }
        NotificationManager.shared.requestPermission()
    }

    // MARK: - Queries

    func tasks(for quadrant: Quadrant) -> [EisTask] {
        tasks.filter { $0.quadrant == quadrant }
    }

    func tasks(for date: Date) -> [EisTask] {
        tasks.filter {
            guard let d = $0.dueDate else { return false }
            return Calendar.current.isDate(d, inSameDayAs: date)
        }
    }

    var checklistTasks: [EisTask] { tasks.filter { $0.isInChecklist } }

    var tasksWithDeadlines: [EisTask] {
        tasks.filter { $0.dueDate != nil }.sorted { $0.dueDate! < $1.dueDate! }
    }

    var totalCount: Int     { tasks.count }
    var completedCount: Int { tasks.filter { $0.isCompleted }.count }
    var pendingCount: Int   { tasks.filter { !$0.isCompleted }.count }

    var completionRate: Double {
        guard totalCount > 0 else { return 0 }
        return Double(completedCount) / Double(totalCount)
    }

    func completionRate(for quadrant: Quadrant) -> Double {
        let q = tasks(for: quadrant)
        guard !q.isEmpty else { return 0 }
        return Double(q.filter { $0.isCompleted }.count) / Double(q.count)
    }

    /// Returns completion counts for the last `days` days (index 0 = oldest day).
    func completionsPerDay(days: Int = 7) -> [(date: Date, count: Int)] {
        let cal   = Calendar.current
        let today = cal.startOfDay(for: Date())
        return (0..<days).reversed().map { offset in
            let day = cal.date(byAdding: .day, value: -offset, to: today)!
            let count = tasks.filter {
                guard let c = $0.completedAt else { return false }
                return cal.isDate(c, inSameDayAs: day)
            }.count
            return (date: day, count: count)
        }
    }

    /// Consecutive days ending today where at least 1 task was completed.
    var currentStreak: Int {
        let cal = Calendar.current
        var streak = 0
        var day   = cal.startOfDay(for: Date())
        while true {
            let count = tasks.filter {
                guard let c = $0.completedAt else { return false }
                return cal.isDate(c, inSameDayAs: day)
            }.count
            guard count > 0 else { break }
            streak += 1
            guard let prev = cal.date(byAdding: .day, value: -1, to: day) else { break }
            day = prev
        }
        return streak
    }

    // MARK: - Mutations

    func addTask(_ task: EisTask) {
        tasks.append(task)
        HapticManager.shared.impact(.light)
        NotificationManager.shared.scheduleNotification(for: task)
        save()
    }

    func updateTask(_ task: EisTask) {
        if let idx = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[idx] = task
            NotificationManager.shared.scheduleNotification(for: task)
            save()
        }
    }

    func deleteTask(id: UUID) {
        if let task = tasks.first(where: { $0.id == id }) {
            NotificationManager.shared.cancelNotification(for: task)
        }
        tasks.removeAll { $0.id == id }
        HapticManager.shared.impact(.medium)
        save()
    }

    func toggleCompletion(id: UUID) {
        guard let idx = tasks.firstIndex(where: { $0.id == id }) else { return }
        let wasCompleted = tasks[idx].isCompleted
        tasks[idx].isCompleted.toggle()
        tasks[idx].completedAt = tasks[idx].isCompleted ? Date() : nil
        wasCompleted
            ? HapticManager.shared.impact(.light)
            : HapticManager.shared.notification(.success)

        // Recurring: when just completed, spawn next occurrence
        if !wasCompleted,
           tasks[idx].recurrence != .none,
           let due = tasks[idx].dueDate,
           let nextDue = tasks[idx].recurrence.nextDate(after: due) {
            var next        = tasks[idx]
            next.id          = UUID()
            next.isCompleted = false
            next.completedAt = nil
            next.dueDate     = nextDue
            next.createdAt   = Date()
            tasks.append(next)
            NotificationManager.shared.scheduleNotification(for: next)
        }
        save()
    }

    func toggleSubtaskCompletion(taskId: UUID, subtaskId: UUID) {
        guard let taskIdx = tasks.firstIndex(where: { $0.id == taskId }),
              let subIdx  = tasks[taskIdx].subtasks.firstIndex(where: { $0.id == subtaskId })
        else { return }
        tasks[taskIdx].subtasks[subIdx].isCompleted.toggle()
        save()
    }

    func completeMultiple(ids: Set<UUID>) {
        for id in ids {
            guard let idx = tasks.firstIndex(where: { $0.id == id }) else { continue }
            if !tasks[idx].isCompleted {
                tasks[idx].isCompleted = true
                tasks[idx].completedAt = Date()
            }
        }
        save()
    }

    func deleteMultiple(ids: Set<UUID>) {
        for id in ids {
            if let task = tasks.first(where: { $0.id == id }) {
                NotificationManager.shared.cancelNotification(for: task)
            }
        }
        tasks.removeAll { ids.contains($0.id) }
        save()
    }

    /// Called after the user manually reorders the checklist.
    /// `reordered` is the new desired order of the visible (filtered) tasks.
    func reorderChecklistTasks(_ reordered: [EisTask]) {
        for (idx, task) in reordered.enumerated() {
            if let storeIdx = tasks.firstIndex(where: { $0.id == task.id }) {
                tasks[storeIdx].sortOrder = idx
            }
        }
        save()
    }

    // MARK: - Category mutations

    func addCategory(_ cat: ChecklistCategory) {
        checklistCategories.append(cat)
        saveCategories()
    }

    func resetToSampleData() {
        tasks = []
        NotificationManager.shared.cancelAll()
        loadSampleData()
    }

    func deleteCategory(id: UUID) {
        checklistCategories.removeAll { $0.id == id }
        // Reassign tasks to first remaining category (General)
        let fallbackId = checklistCategories.first?.id
        for i in tasks.indices where tasks[i].checklistCategoryId == id {
            tasks[i].checklistCategoryId = fallbackId
        }
        save()
        saveCategories()
    }

    // MARK: - Persistence

    private func save() {
        if let data = try? JSONEncoder().encode(tasks) {
            defaults.set(data, forKey: saveKey)
        }
        writeWidgetData()
    }

    private func writeWidgetData() {
        struct Item: Codable {
            let id: String; let title: String; let dueDate: Date
            let quadrantRaw: String; let isOverdue: Bool
        }
        struct Snap: Codable {
            let totalCount: Int; let completedCount: Int; let pendingCount: Int
            let currentStreak: Int; let upcomingDeadlines: [Item]
        }
        let now = Date()
        let upcoming = tasksWithDeadlines
            .filter { !$0.isCompleted }
            .prefix(5)
            .map { t in Item(id: t.id.uuidString, title: t.title, dueDate: t.dueDate!,
                             quadrantRaw: t.quadrant.rawValue,
                             isOverdue: t.dueDate! < now) }
        let snap = Snap(totalCount: totalCount, completedCount: completedCount,
                        pendingCount: pendingCount, currentStreak: currentStreak,
                        upcomingDeadlines: Array(upcoming))
        if let data = try? JSONEncoder().encode(snap) {
            defaults.set(data, forKey: "widgetSnapshot")
        }
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func loadTasks() {
        guard let data    = defaults.data(forKey: saveKey),
              let decoded = try? JSONDecoder().decode([EisTask].self, from: data)
        else { return }
        tasks = decoded
    }

    private func saveCategories() {
        if let data = try? JSONEncoder().encode(checklistCategories) {
            defaults.set(data, forKey: categoriesKey)
        }
    }

    private func loadCategories() {
        if let data    = defaults.data(forKey: categoriesKey),
           let decoded = try? JSONDecoder().decode([ChecklistCategory].self, from: data) {
            checklistCategories = decoded
        } else {
            checklistCategories = [.general, .shopping, .work]
            saveCategories()
        }
    }

    // MARK: - Sample Data

    private func loadSampleData() {
        let now = Date()
        let cal = Calendar.current
        func days(_ n: Int, hour: Int = 0, min: Int = 0) -> Date {
            var d = cal.date(byAdding: .day, value: n, to: now)!
            d = cal.date(bySettingHour: hour, minute: min, second: 0, of: d)!
            return d
        }
        let genId  = checklistCategories.first { $0.name == "General"  }?.id
        let shopId = checklistCategories.first { $0.name == "Shopping" }?.id

        tasks = [
            // Do Now
            EisTask(title: "Handle server outage",    quadrant: .doFirst,   canvasX: 0.78, canvasY: 0.16,
                    dueDate: days(1, hour: 9,  min: 0), isInChecklist: true, checklistCategoryId: genId),
            EisTask(title: "Prepare client meeting",  quadrant: .doFirst,   canvasX: 0.65, canvasY: 0.30,
                    dueDate: days(1, hour: 14, min: 0), isInChecklist: true, checklistCategoryId: genId),
            EisTask(title: "Submit final project",    quadrant: .doFirst,   canvasX: 0.82, canvasY: 0.42,
                    dueDate: days(2, hour: 17, min: 0), isInChecklist: true, checklistCategoryId: genId),
            EisTask(title: "Urgent bug hotfix",       quadrant: .doFirst,   canvasX: 0.70, canvasY: 0.22,
                    dueDate: days(0, hour: 18, min: 30)),

            // Schedule
            EisTask(title: "AWS certification",       quadrant: .schedule,  canvasX: 0.32, canvasY: 0.18,
                    dueDate: days(10), isInChecklist: true, checklistCategoryId: genId),
            EisTask(title: "Read final!!!!!",         quadrant: .schedule,  canvasX: 0.44, canvasY: 0.28),
            EisTask(title: "CFA take a look",         quadrant: .schedule,  canvasX: 0.14, canvasY: 0.40,
                    isInChecklist: true, checklistCategoryId: genId),
            EisTask(title: "Update my CV",            quadrant: .schedule,  canvasX: 0.38, canvasY: 0.46,
                    dueDate: days(7)),

            // Delegate
            EisTask(title: "Book hair appointment",   quadrant: .delegate,  canvasX: 0.68, canvasY: 0.62,
                    dueDate: days(4, hour: 10, min: 0)),
            EisTask(title: "Tax consultation",        quadrant: .delegate,  canvasX: 0.80, canvasY: 0.74,
                    dueDate: days(6)),
            EisTask(title: "Drop off dry cleaning",   quadrant: .delegate,  canvasX: 0.60, canvasY: 0.82,
                    dueDate: days(1, hour: 8, min: 0), isInChecklist: true, checklistCategoryId: genId),

            // Eliminate — some become shopping list items
            EisTask(title: "Milk & eggs",             quadrant: .eliminate, canvasX: 0.30, canvasY: 0.60,
                    isInChecklist: true, checklistCategoryId: shopId),
            EisTask(title: "Bread & butter",          quadrant: .eliminate, canvasX: 0.22, canvasY: 0.68,
                    isInChecklist: true, checklistCategoryId: shopId),
            EisTask(title: "把食譜歸檔案",            quadrant: .eliminate, canvasX: 0.18, canvasY: 0.76),
            EisTask(title: "Clean spam emails",       quadrant: .eliminate, canvasX: 0.36, canvasY: 0.88),
        ]
        save()
    }
}
