import Foundation
import Combine

class TaskStore: ObservableObject {
    @Published var tasks: [EisTask] = []

    private let saveKey = "eisenhower_tasks_v1"

    init() {
        loadTasks()
        if tasks.isEmpty { loadSampleData() }
    }

    // MARK: - Queries

    func tasks(for quadrant: Quadrant) -> [EisTask] {
        tasks.filter { $0.quadrant == quadrant }
    }

    func tasks(for date: Date) -> [EisTask] {
        let cal = Calendar.current
        return tasks.filter { task in
            guard let d = task.dueDate else { return false }
            return cal.isDate(d, inSameDayAs: date)
        }
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

    func deleteTasks(at offsets: IndexSet, in quadrant: Quadrant) {
        var quadrantTasks = tasks(for: quadrant)
        quadrantTasks.remove(atOffsets: offsets)
        tasks = tasks.filter { $0.quadrant != quadrant } + quadrantTasks
        save()
    }

    func toggleCompletion(id: UUID) {
        if let idx = tasks.firstIndex(where: { $0.id == id }) {
            tasks[idx].isCompleted.toggle()
            save()
        }
    }

    func moveTask(id: UUID, to quadrant: Quadrant) {
        if let idx = tasks.firstIndex(where: { $0.id == id }) {
            tasks[idx].quadrant = quadrant
            save()
        }
    }

    // MARK: - Persistence

    private func save() {
        if let encoded = try? JSONEncoder().encode(tasks) {
            UserDefaults.standard.set(encoded, forKey: saveKey)
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
        func days(_ n: Int) -> Date { cal.date(byAdding: .day, value: n, to: now)! }

        tasks = [
            EisTask(title: "Handle server outage", quadrant: .doFirst, dueDate: days(1)),
            EisTask(title: "Prepare for client meeting", quadrant: .doFirst, dueDate: days(1)),
            EisTask(title: "Submit final project", quadrant: .doFirst, dueDate: days(2)),
            EisTask(title: "Urgent bug hotfix", quadrant: .doFirst, dueDate: now),
            EisTask(title: "Finish team presentation", quadrant: .doFirst, dueDate: days(1)),

            EisTask(title: "English conversation class", quadrant: .schedule, dueDate: days(3)),
            EisTask(title: "Study for AWS certification", quadrant: .schedule, dueDate: days(7)),
            EisTask(title: "Gym workout 3x/week", quadrant: .schedule, dueDate: days(2)),
            EisTask(title: "Attend book club", quadrant: .schedule, dueDate: days(5)),
            EisTask(title: "Take online course", quadrant: .schedule, dueDate: days(10)),

            EisTask(title: "Book hair appointment", quadrant: .delegate, dueDate: days(4)),
            EisTask(title: "Schedule tax consultation", quadrant: .delegate, dueDate: days(6)),
            EisTask(title: "Ask intern to organize files", quadrant: .delegate),
            EisTask(title: "Request design feedback", quadrant: .delegate),
            EisTask(title: "Drop off dry cleaning", quadrant: .delegate, dueDate: days(1)),

            EisTask(title: "Donate unused clothes", quadrant: .eliminate),
            EisTask(title: "Clean up spam emails", quadrant: .eliminate),
            EisTask(title: "Delete old files", quadrant: .eliminate),
            EisTask(title: "Cancel unused subscriptions", quadrant: .eliminate),
            EisTask(title: "Turn off SNS notifications", quadrant: .eliminate),
        ]
        save()
    }
}
