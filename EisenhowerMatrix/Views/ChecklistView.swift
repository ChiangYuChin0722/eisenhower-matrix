import SwiftUI

struct ChecklistView: View {
    @EnvironmentObject var taskStore: TaskStore
    @State private var showAddTask   = false
    @State private var editingTask: EisTask? = nil
    @State private var showCompleted = false

    private var displayedTasks: [EisTask] {
        let base = taskStore.checklistTasks
        return showCompleted ? base : base.filter { !$0.isCompleted }
    }

    private var completedCount: Int { taskStore.checklistTasks.filter { $0.isCompleted }.count }
    private var totalCount: Int     { taskStore.checklistTasks.count }
    private var progress: Double {
        guard totalCount > 0 else { return 0 }
        return Double(completedCount) / Double(totalCount)
    }

    var body: some View {
        NavigationView {
            Group {
                if taskStore.checklistTasks.isEmpty {
                    emptyState
                } else {
                    checklistContent
                }
            }
            .navigationTitle("Checklist")
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
                AddTaskView(defaultQuadrant: .doFirst, forceChecklist: true)
            }
            .sheet(item: $editingTask) { task in
                AddTaskView(editingTask: task)
            }
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "checklist")
                .font(.system(size: 56))
                .foregroundColor(.secondary.opacity(0.3))
            Text("No checklist tasks")
                .font(.title3).fontWeight(.medium)
            Text("Add tasks from the Matrix and mark\nthem as checklist items.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button("Add Task") { showAddTask = true }
                .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    // MARK: - Checklist content

    private var checklistContent: some View {
        VStack(spacing: 0) {
            progressHeader
            Divider()
            List {
                ForEach(Quadrant.allCases) { quadrant in
                    let tasks = displayedTasks.filter { $0.quadrant == quadrant }
                    if !tasks.isEmpty {
                        Section {
                            ForEach(tasks) { task in
                                checklistRow(task)
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
                                Text(quadrant.emoji)
                                Text(quadrant.title)
                                    .foregroundColor(quadrant.color)
                                Spacer()
                                Text("\(tasks.filter { $0.isCompleted }.count)/\(tasks.count)")
                                    .foregroundColor(.secondary)
                            }
                            .font(.caption)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
    }

    // MARK: - Progress header

    private var progressHeader: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(Color.blue.opacity(0.15), lineWidth: 6)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Color.blue, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut, value: progress)
                Text("\(Int(progress * 100))%")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.blue)
            }
            .frame(width: 50, height: 50)

            VStack(alignment: .leading, spacing: 4) {
                Text("\(completedCount) of \(totalCount) done")
                    .font(.subheadline).fontWeight(.semibold)
                ProgressView(value: progress)
                    .tint(.blue)
            }

            Spacer()
        }
        .padding()
        .background(Color(uiColor: .systemBackground))
    }

    // MARK: - Row

    private func checklistRow(_ task: EisTask) -> some View {
        HStack(spacing: 12) {
            Button {
                taskStore.toggleCompletion(id: task.id)
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(task.isCompleted ? task.quadrant.color : Color.gray.opacity(0.4), lineWidth: 1.5)
                        .frame(width: 22, height: 22)
                    if task.isCompleted {
                        RoundedRectangle(cornerRadius: 5)
                            .fill(task.quadrant.color.opacity(0.15))
                            .frame(width: 22, height: 22)
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(task.quadrant.color)
                    }
                }
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 3) {
                Text(task.title)
                    .font(.subheadline)
                    .strikethrough(task.isCompleted)
                    .foregroundColor(task.isCompleted ? .secondary : .primary)

                if let due = task.dueDate {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.caption2)
                        Text(due, style: .date)
                            .font(.caption)
                    }
                    .foregroundColor(due < Date() && !task.isCompleted ? .red : .secondary)
                }

                if !task.subtasks.isEmpty {
                    Text("\(task.completedSubtaskCount)/\(task.totalSubtaskCount) subtasks")
                        .font(.caption2).foregroundColor(.secondary)
                }
            }

            Spacer()

            if task.colorTag != .none {
                Circle().fill(task.colorTag.color).frame(width: 8, height: 8)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { editingTask = task }
    }
}

#Preview {
    ChecklistView().environmentObject(TaskStore())
}
