import Foundation
import Combine

class TaskStore: ObservableObject {
    @Published var tasks: [EisTask] = []

    // v3: added isInChecklist field
    private let saveKey = "eisenhower_tasks_v3"

    init() {
        loadTasks()
        if tasks.isEmpty { loadSampleData() }
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

    // MARK: - Mutations

    func addTask(_ task: EisTask) {
        tasks.append(task)
        save()
    }

    func updateTask(_ task: EisTask) {
        if let idx = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[idx] = task
            save()
        }
    }

    func deleteTask(id: UUID) {
        tasks.removeAll { $0.id == id }
        save()
    }

    func toggleCompletion(id: UUID) {
        if let idx = tasks.firstIndex(where: { $0.id == id }) {
            tasks[idx].isCompleted.toggle()
            save()
        }
    }

    // MARK: - Persistence

    private func save() {
        if let data = try? JSONEncoder().encode(tasks) {
            UserDefaults.standard.set(data, forKey: saveKey)
        }
    }

    private func loadTasks() {
        guard let data = UserDefaults.standard.data(forKey: saveKey),
              let decoded = try? JSONDecoder().decode([EisTask].self, from: data)
        else { return }
        tasks = decoded
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

        tasks = [
            // Do Now
            EisTask(title: "Handle server outage",    quadrant: .doFirst,   canvasX: 0.78, canvasY: 0.16,
                    dueDate: days(1, hour: 9,  min: 0), isInChecklist: true),
            EisTask(title: "Prepare client meeting",  quadrant: .doFirst,   canvasX: 0.65, canvasY: 0.30,
                    dueDate: days(1, hour: 14, min: 0), isInChecklist: true),
            EisTask(title: "Submit final project",    quadrant: .doFirst,   canvasX: 0.82, canvasY: 0.42,
                    dueDate: days(2, hour: 17, min: 0), isInChecklist: true),
            EisTask(title: "Urgent bug hotfix",       quadrant: .doFirst,   canvasX: 0.70, canvasY: 0.22,
                    dueDate: days(0, hour: 18, min: 30)),

            // Schedule
            EisTask(title: "AWS certification",       quadrant: .schedule,  canvasX: 0.32, canvasY: 0.18,
                    dueDate: days(10), isInChecklist: true),
            EisTask(title: "Read final!!!!!",         quadrant: .schedule,  canvasX: 0.44, canvasY: 0.28),
            EisTask(title: "CFA take a look",         quadrant: .schedule,  canvasX: 0.14, canvasY: 0.40,
                    isInChecklist: true),
            EisTask(title: "Update my CV",            quadrant: .schedule,  canvasX: 0.38, canvasY: 0.46,
                    dueDate: days(7)),

            // Delegate
            EisTask(title: "Book hair appointment",   quadrant: .delegate,  canvasX: 0.68, canvasY: 0.62,
                    dueDate: days(4, hour: 10, min: 0)),
            EisTask(title: "Tax consultation",        quadrant: .delegate,  canvasX: 0.80, canvasY: 0.74,
                    dueDate: days(6)),
            EisTask(title: "Drop off dry cleaning",   quadrant: .delegate,  canvasX: 0.60, canvasY: 0.82,
                    dueDate: days(1, hour: 8, min: 0), isInChecklist: true),

            // Eliminate
            EisTask(title: "做清單",                  quadrant: .eliminate, canvasX: 0.30, canvasY: 0.60,
                    isInChecklist: true),
            EisTask(title: "把食譜歸檔案",            quadrant: .eliminate, canvasX: 0.18, canvasY: 0.76),
            EisTask(title: "Clean spam emails",       quadrant: .eliminate, canvasX: 0.36, canvasY: 0.88),
        ]
        save()
    }
}
