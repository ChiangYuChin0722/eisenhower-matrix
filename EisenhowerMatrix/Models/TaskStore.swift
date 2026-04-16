import Foundation
import Combine
import WidgetKit
import FirebaseFirestore
import FirebaseAuth

class TaskStore: ObservableObject {
    @Published var tasks: [EisTask]                        = []
    @Published var checklistCategories: [ChecklistCategory] = []
    @Published var isSyncing                               = false

    // v4: added Recurrence, ChecklistCategory, completedAt
    private let saveKey          = "eisenhower_tasks_v4"
    private let categoriesKey    = "eisenhower_categories_v1"
    private let currentUIDKey    = "currentUserUID"
    private let calendarSyncKey  = "syncToiCalendar"
    // Shared with Widget Extension via App Group
    private let defaults = UserDefaults(suiteName: "group.com.eisenhower.matrix") ?? .standard

    private var calendarSyncEnabled: Bool { defaults.bool(forKey: calendarSyncKey) }

    private var db           = Firestore.firestore()
    private var taskListener: ListenerRegistration?
    private var catListener:  ListenerRegistration?
    private var authHandle:   AuthStateDidChangeListenerHandle?

    init() {
        loadCategories()
        loadTasks()
        // Only show sample data on the very first launch — not after reset or re-launch
        let hasLaunched = defaults.bool(forKey: "hasLaunchedBefore")
        if tasks.isEmpty && !hasLaunched {
            loadSampleData()
            defaults.set(true, forKey: "hasLaunchedBefore")
        }
        NotificationManager.shared.requestPermission()

        // Auto-connect/disconnect Firestore when auth changes
        authHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            DispatchQueue.main.async {
                if let user = user { self?.startSync(uid: user.uid) }
                else               { self?.stopSync() }
            }
        }
    }

    deinit {
        stopSync()
        if let h = authHandle { Auth.auth().removeStateDidChangeListener(h) }
    }

    // MARK: - Firestore Sync

    private var uid: String? { Auth.auth().currentUser?.uid }

    func startSync(uid: String) {
        stopSync()
        isSyncing = true

        // If a different user is signing in, wipe the local task cache immediately.
        // This prevents User A's locally-cached tasks from being migrated into
        // User B's Firestore when User B's collection is first seen as empty.
        let previousUID = defaults.string(forKey: currentUIDKey)
        if let prev = previousUID, prev != uid {
            tasks = []
            defaults.removeObject(forKey: saveKey)
        }
        defaults.set(uid, forKey: currentUIDKey)

        let base = db.collection("users").document(uid)

        // Check for a pending reset stored in Firestore (survives app reinstalls,
        // unlike UserDefaults which is wiped on uninstall).
        base.getDocument { [weak self] snap, _ in
            guard let self = self else { return }
            let pendingReset = snap?.data()?["pendingReset"] as? Bool ?? false

            if pendingReset {
                // A reset was requested — delete any remaining task docs, then clear the flag.
                // Also cancel all local notifications on THIS device so that every device
                // the user owns clears its notifications the next time the app is opened.
                base.collection("tasks").getDocuments { taskSnap, _ in
                    taskSnap?.documents.forEach { $0.reference.delete() }
                }
                base.setData(["pendingReset": false], merge: true)
                DispatchQueue.main.async {
                    self.tasks = []
                    self.saveLocalCache()
                    NotificationManager.shared.cancelAll()
                }
            }

            // Set up real-time listeners after the reset check.
            DispatchQueue.main.async {
                self.setupListeners(uid: uid, base: base)
            }
        }
    }

    private func setupListeners(uid: String, base: DocumentReference) {
        let migratedKey = "migrated_\(uid)"

        taskListener = base.collection("tasks")
            .addSnapshotListener { [weak self] snap, _ in
                guard let self = self, let snap = snap else { return }
                DispatchQueue.main.async {
                    if snap.documents.isEmpty {
                        // First login: push local tasks up to Firestore if not yet migrated.
                        if !self.defaults.bool(forKey: migratedKey) && !self.tasks.isEmpty {
                            for task in self.tasks { self.fsWrite(task, uid: uid) }
                            for cat  in self.checklistCategories { self.fsWriteCat(cat, uid: uid) }
                            self.defaults.set(true, forKey: migratedKey)
                        }
                    } else {
                        // Normal sync: overwrite local tasks with Firestore truth.
                        let fetched = snap.documents
                            .compactMap { EisTask.from(firestoreData: $0.data()) }
                            .sorted { $0.createdAt < $1.createdAt }
                        self.tasks = fetched
                        self.saveLocalCache()
                    }
                    self.isSyncing = false
                }
            }

        catListener = base.collection("categories")
            .addSnapshotListener { [weak self] snap, _ in
                guard let self = self, let snap = snap else { return }
                let fetched = snap.documents
                    .compactMap { ChecklistCategory.from(firestoreData: $0.data()) }
                    .sorted { $0.name < $1.name }
                DispatchQueue.main.async {
                    if !fetched.isEmpty {
                        self.checklistCategories = fetched
                        self.saveCategories()
                    }
                }
            }
    }

    func stopSync() {
        taskListener?.remove(); taskListener = nil
        catListener?.remove();  catListener  = nil
    }

    // MARK: - Firestore write helpers

    private func fsWrite(_ task: EisTask, uid: String? = nil) {
        guard let uid = uid ?? self.uid else { return }
        db.collection("users").document(uid)
          .collection("tasks").document(task.id.uuidString)
          .setData(task.firestoreData)
    }

    private func fsDelete(taskId: UUID) {
        guard let uid = self.uid else { return }
        db.collection("users").document(uid)
          .collection("tasks").document(taskId.uuidString)
          .delete()
    }

    private func fsWriteCat(_ cat: ChecklistCategory, uid: String? = nil) {
        guard let uid = uid ?? self.uid else { return }
        db.collection("users").document(uid)
          .collection("categories").document(cat.id.uuidString)
          .setData(cat.firestoreData)
    }

    private func fsDeleteCat(id: UUID) {
        guard let uid = self.uid else { return }
        db.collection("users").document(uid)
          .collection("categories").document(id.uuidString)
          .delete()
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
        var t = task
        HapticManager.shared.impact(.light)
        NotificationManager.shared.scheduleNotification(for: t)
        if calendarSyncEnabled, let eventId = EventKitManager.shared.upsertEvent(for: t) {
            t.calendarEventId = eventId
        }
        tasks.append(t)
        fsWrite(t)
        saveLocalCache()
    }

    func updateTask(_ task: EisTask) {
        var t = task
        NotificationManager.shared.scheduleNotification(for: t)
        if calendarSyncEnabled {
            if t.dueDate != nil {
                if let eventId = EventKitManager.shared.upsertEvent(for: t) {
                    t.calendarEventId = eventId
                }
            } else if let eventId = t.calendarEventId {
                EventKitManager.shared.deleteEvent(id: eventId)
                t.calendarEventId = nil
            }
        }
        if let idx = tasks.firstIndex(where: { $0.id == t.id }) {
            tasks[idx] = t
        }
        fsWrite(t)
        saveLocalCache()
    }

    func deleteTask(id: UUID) {
        if let task = tasks.first(where: { $0.id == id }) {
            NotificationManager.shared.cancelNotification(for: task)
            if let eventId = task.calendarEventId {
                EventKitManager.shared.deleteEvent(id: eventId)
            }
        }
        tasks.removeAll { $0.id == id }
        HapticManager.shared.impact(.medium)
        fsDelete(taskId: id)
        saveLocalCache()
    }

    func toggleCompletion(id: UUID) {
        guard let idx = tasks.firstIndex(where: { $0.id == id }) else { return }
        let wasCompleted = tasks[idx].isCompleted
        tasks[idx].isCompleted.toggle()
        tasks[idx].completedAt = tasks[idx].isCompleted ? Date() : nil
        wasCompleted
            ? HapticManager.shared.impact(.light)
            : HapticManager.shared.notification(.success)

        // Recurring: spawn next occurrence when completed
        if !wasCompleted,
           tasks[idx].recurrence != .none,
           let due    = tasks[idx].dueDate,
           let nextDue = tasks[idx].recurrence.nextDate(after: due) {
            var next = tasks[idx]
            next.id = UUID(); next.isCompleted = false
            next.completedAt = nil; next.dueDate = nextDue; next.createdAt = Date()
            tasks.append(next)
            NotificationManager.shared.scheduleNotification(for: next)
            fsWrite(next)
        }
        fsWrite(tasks[idx])
        saveLocalCache()
    }

    func toggleSubtaskCompletion(taskId: UUID, subtaskId: UUID) {
        guard let ti = tasks.firstIndex(where: { $0.id == taskId }),
              let si = tasks[ti].subtasks.firstIndex(where: { $0.id == subtaskId })
        else { return }
        tasks[ti].subtasks[si].isCompleted.toggle()
        fsWrite(tasks[ti])
        saveLocalCache()
    }

    func completeMultiple(ids: Set<UUID>) {
        for id in ids {
            guard let idx = tasks.firstIndex(where: { $0.id == id }) else { continue }
            if !tasks[idx].isCompleted {
                tasks[idx].isCompleted = true
                tasks[idx].completedAt = Date()
                fsWrite(tasks[idx])
            }
        }
        saveLocalCache()
    }

    func deleteMultiple(ids: Set<UUID>) {
        for id in ids {
            if let task = tasks.first(where: { $0.id == id }) {
                NotificationManager.shared.cancelNotification(for: task)
            }
            fsDelete(taskId: id)
        }
        tasks.removeAll { ids.contains($0.id) }
        saveLocalCache()
    }

    func reorderChecklistTasks(_ reordered: [EisTask]) {
        for (idx, task) in reordered.enumerated() {
            if let si = tasks.firstIndex(where: { $0.id == task.id }) {
                tasks[si].sortOrder = idx
                fsWrite(tasks[si])
            }
        }
        saveLocalCache()
    }

    // MARK: - Category mutations

    func addCategory(_ cat: ChecklistCategory) {
        checklistCategories.append(cat)
        fsWriteCat(cat)
        saveCategories()
    }

    func resetToSampleData() {
        for task in tasks {
            if let eventId = task.calendarEventId {
                EventKitManager.shared.deleteEvent(id: eventId)
            }
        }
        if let uid = self.uid {
            let base = db.collection("users").document(uid)
            // Store the reset flag IN Firestore so it survives app reinstalls.
            // On next startSync (even after uninstall/reinstall), this flag is
            // read first and all tasks are deleted before listeners are set up.
            base.setData(["pendingReset": true], merge: true)
            // Also delete current task docs immediately (best-effort).
            for task in tasks {
                base.collection("tasks").document(task.id.uuidString).delete()
            }
        }
        tasks = []
        NotificationManager.shared.cancelAll()
        saveLocalCache()
    }

    func deleteCategory(id: UUID) {
        checklistCategories.removeAll { $0.id == id }
        let fallbackId = checklistCategories.first?.id
        for i in tasks.indices where tasks[i].checklistCategoryId == id {
            tasks[i].checklistCategoryId = fallbackId
            fsWrite(tasks[i])
        }
        fsDeleteCat(id: id)
        saveLocalCache()
        saveCategories()
    }

    // MARK: - Persistence (local cache)

    private func saveLocalCache() {
        if let data = try? JSONEncoder().encode(tasks) {
            defaults.set(data, forKey: saveKey)
        }
        writeWidgetData()
    }

    // Alias kept for backward compatibility with any remaining call sites
    private func save() { saveLocalCache() }

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
            EisTask(title: "Handle server outage",    quadrant: .doFirst,   canvasX: 0.78, canvasY: 0.16,
                    dueDate: days(1, hour: 9,  min: 0), isInChecklist: true, checklistCategoryId: genId),
            EisTask(title: "Prepare client meeting",  quadrant: .doFirst,   canvasX: 0.65, canvasY: 0.30,
                    dueDate: days(1, hour: 14, min: 0), isInChecklist: true, checklistCategoryId: genId),
            EisTask(title: "Submit final project",    quadrant: .doFirst,   canvasX: 0.82, canvasY: 0.42,
                    dueDate: days(2, hour: 17, min: 0), isInChecklist: true, checklistCategoryId: genId),
            EisTask(title: "Urgent bug hotfix",       quadrant: .doFirst,   canvasX: 0.70, canvasY: 0.22,
                    dueDate: days(0, hour: 18, min: 30)),
            EisTask(title: "AWS certification",       quadrant: .schedule,  canvasX: 0.32, canvasY: 0.18,
                    dueDate: days(10), isInChecklist: true, checklistCategoryId: genId),
            EisTask(title: "Read final!!!!!",         quadrant: .schedule,  canvasX: 0.44, canvasY: 0.28),
            EisTask(title: "CFA take a look",         quadrant: .schedule,  canvasX: 0.14, canvasY: 0.40,
                    isInChecklist: true, checklistCategoryId: genId),
            EisTask(title: "Update my CV",            quadrant: .schedule,  canvasX: 0.38, canvasY: 0.46,
                    dueDate: days(7)),
            EisTask(title: "Book hair appointment",   quadrant: .delegate,  canvasX: 0.68, canvasY: 0.62,
                    dueDate: days(4, hour: 10, min: 0)),
            EisTask(title: "Tax consultation",        quadrant: .delegate,  canvasX: 0.80, canvasY: 0.74,
                    dueDate: days(6)),
            EisTask(title: "Drop off dry cleaning",   quadrant: .delegate,  canvasX: 0.60, canvasY: 0.82,
                    dueDate: days(1, hour: 8, min: 0), isInChecklist: true, checklistCategoryId: genId),
            EisTask(title: "Milk & eggs",             quadrant: .eliminate, canvasX: 0.30, canvasY: 0.60,
                    isInChecklist: true, checklistCategoryId: shopId),
            EisTask(title: "Bread & butter",          quadrant: .eliminate, canvasX: 0.22, canvasY: 0.68,
                    isInChecklist: true, checklistCategoryId: shopId),
            EisTask(title: "把食譜歸檔案",            quadrant: .eliminate, canvasX: 0.18, canvasY: 0.76),
            EisTask(title: "Clean spam emails",       quadrant: .eliminate, canvasX: 0.36, canvasY: 0.88),
        ]
        saveLocalCache()
    }
}
