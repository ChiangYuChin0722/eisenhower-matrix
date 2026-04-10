import SwiftUI

struct DeadlineView: View {
    @EnvironmentObject var taskStore: TaskStore
    @State private var editingTask: EisTask? = nil
    @State private var showAddTask   = false
    @State private var showCompleted = false

    private let cal = Calendar.current

    // MARK: - Deadline groups

    private var allDeadlineTasks: [EisTask] {
        let base = taskStore.tasksWithDeadlines
        return showCompleted ? base : base.filter { !$0.isCompleted }
    }

    private var overdue: [EisTask] {
        allDeadlineTasks.filter { !$0.isCompleted && $0.dueDate! < startOfToday }
    }
    private var today: [EisTask] {
        allDeadlineTasks.filter { cal.isDateInToday($0.dueDate!) }
    }
    private var tomorrow: [EisTask] {
        allDeadlineTasks.filter { cal.isDateInTomorrow($0.dueDate!) }
    }
    private var thisWeek: [EisTask] {
        let end = cal.date(byAdding: .day, value: 7, to: startOfToday)!
        return allDeadlineTasks.filter { d in
            let due = d.dueDate!
            return due > startOfTomorrow && due <= end
        }
    }
    private var later: [EisTask] {
        let end = cal.date(byAdding: .day, value: 7, to: startOfToday)!
        return allDeadlineTasks.filter { $0.dueDate! > end }
    }

    private var startOfToday: Date {
        cal.startOfDay(for: Date())
    }
    private var startOfTomorrow: Date {
        cal.date(byAdding: .day, value: 1, to: startOfToday)!
    }

    // MARK: - Body

    var body: some View {
        NavigationView {
            Group {
                if taskStore.tasksWithDeadlines.isEmpty {
                    emptyState
                } else {
                    deadlineList
                }
            }
            .navigationTitle("Deadlines")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        withAnimation { showCompleted.toggle() }
                    } label: {
                        Label(showCompleted ? "Hide Done" : "Show Done",
                              systemImage: showCompleted ? "eye.slash" : "eye")
                        .font(.caption)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showAddTask = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddTask) {
                AddTaskView(defaultQuadrant: .doFirst, forceCalendar: true)
            }
            .sheet(item: $editingTask) { task in
                AddTaskView(editingTask: task)
            }
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.badge.checkmark")
                .font(.system(size: 56))
                .foregroundColor(.secondary.opacity(0.3))
            Text("No deadlines")
                .font(.title3).fontWeight(.medium)
            Text("Add due dates to tasks to track\nthem here.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button("Add Task with Deadline") { showAddTask = true }
                .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    // MARK: - Deadline list

    private var deadlineList: some View {
        List {
            if !overdue.isEmpty {
                deadlineSection("Overdue", tasks: overdue, color: .red, icon: "exclamationmark.circle.fill")
            }
            if !today.isEmpty {
                deadlineSection("Today", tasks: today, color: .orange, icon: "sun.max.fill")
            }
            if !tomorrow.isEmpty {
                deadlineSection("Tomorrow", tasks: tomorrow, color: .yellow, icon: "sunrise.fill")
            }
            if !thisWeek.isEmpty {
                deadlineSection("This Week", tasks: thisWeek, color: .blue, icon: "calendar.badge.clock")
            }
            if !later.isEmpty {
                deadlineSection("Later", tasks: later, color: .secondary, icon: "calendar")
            }
            if allDeadlineTasks.isEmpty && showCompleted {
                Text("All tasks completed!")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
                    .listRowBackground(Color.clear)
            }
        }
        .listStyle(.insetGrouped)
    }

    private func deadlineSection(
        _ title: String,
        tasks: [EisTask],
        color: Color,
        icon: String
    ) -> some View {
        Section {
            ForEach(tasks) { task in
                deadlineRow(task)
                    .swipeActions(edge: .leading) {
                        Button {
                            taskStore.toggleCompletion(id: task.id)
                        } label: {
                            Label(task.isCompleted ? "Undo" : "Done",
                                  systemImage: task.isCompleted ? "arrow.uturn.backward" : "checkmark")
                        }
                        .tint(.green)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            taskStore.deleteTask(id: task.id)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        Button { editingTask = task } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        .tint(.blue)
                    }
            }
        } header: {
            HStack(spacing: 6) {
                Image(systemName: icon).foregroundColor(color)
                Text(title).foregroundColor(color)
                Spacer()
                Text("\(tasks.count)").foregroundColor(.secondary)
            }
            .font(.caption)
        }
    }

    // MARK: - Row

    private func deadlineRow(_ task: EisTask) -> some View {
        HStack(spacing: 12) {
            // Quadrant color dot
            Circle()
                .fill(task.isCompleted ? Color.secondary.opacity(0.4) : task.quadrant.color)
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 3) {
                Text(task.title)
                    .font(.subheadline)
                    .strikethrough(task.isCompleted)
                    .foregroundColor(task.isCompleted ? .secondary : .primary)
                    .lineLimit(1)

                if let due = task.dueDate {
                    HStack(spacing: 4) {
                        Text(deadlineLabel(due))
                            .font(.caption)
                            .foregroundColor(deadlineColor(due, completed: task.isCompleted))
                        if !cal.isDateInToday(due) && !cal.isDateInTomorrow(due) {
                            Text(due, style: .date)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        let timeComps = cal.dateComponents([.hour, .minute], from: due)
                        if (timeComps.hour ?? 0) != 0 || (timeComps.minute ?? 0) != 0 {
                            Text(due, style: .time)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }

            Spacer()

            // Quadrant label badge
            Text(task.quadrant.title)
                .font(.caption2)
                .foregroundColor(task.quadrant.color)
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(task.quadrant.color.opacity(0.1))
                .cornerRadius(4)
        }
        .contentShape(Rectangle())
        .onTapGesture { editingTask = task }
    }

    // MARK: - Helpers

    private func deadlineLabel(_ date: Date) -> String {
        if date < startOfToday && !cal.isDateInToday(date) { return "Overdue" }
        if cal.isDateInToday(date)     { return "Today" }
        if cal.isDateInTomorrow(date)  { return "Tomorrow" }
        let days = cal.dateComponents([.day], from: startOfToday, to: date).day ?? 0
        return "In \(days) days"
    }

    private func deadlineColor(_ date: Date, completed: Bool) -> Color {
        if completed { return .secondary }
        if date < startOfToday { return .red }
        if cal.isDateInToday(date) { return .orange }
        return .blue
    }
}

#Preview {
    DeadlineView().environmentObject(TaskStore())
}
