import SwiftUI

struct ChecklistView: View {
    @EnvironmentObject var taskStore: TaskStore
    @State private var showAddTask    = false
    @State private var editingTask: EisTask? = nil
    @State private var showCompleted  = false
    @State private var newItemTitle   = ""
    @FocusState private var quickAddFocused: Bool

    private var displayedTasks: [EisTask] {
        let base = taskStore.checklistTasks
        let list = showCompleted ? base : base.filter { !$0.isCompleted }
        // Incomplete first, then by creation date
        return list.sorted {
            if $0.isCompleted != $1.isCompleted { return !$0.isCompleted }
            return $0.createdAt < $1.createdAt
        }
    }

    private var completedCount: Int { taskStore.checklistTasks.filter { $0.isCompleted }.count }
    private var totalCount: Int     { taskStore.checklistTasks.count }
    private var progress: Double {
        guard totalCount > 0 else { return 0 }
        return Double(completedCount) / Double(totalCount)
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if totalCount > 0 {
                    progressBar
                }

                if taskStore.checklistTasks.isEmpty {
                    emptyState
                } else {
                    taskList
                }

                quickAddBar
            }
            .navigationTitle("Checklist")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        withAnimation { showCompleted.toggle() }
                    } label: {
                        Image(systemName: showCompleted ? "eye.slash" : "eye")
                        Text(showCompleted ? "Hide done" : "Show done")
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showAddTask = true } label: {
                        Image(systemName: "square.and.pencil")
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

    // MARK: - Progress bar

    private var progressBar: some View {
        VStack(spacing: 6) {
            HStack {
                Text("\(completedCount) / \(totalCount) done")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(Int(progress * 100))%")
                    .font(.caption).fontWeight(.semibold)
                    .foregroundColor(.blue)
            }
            .padding(.horizontal, 16)

            ProgressView(value: progress)
                .tint(.blue)
                .padding(.horizontal, 16)
        }
        .padding(.vertical, 10)
        .background(Color(uiColor: .systemBackground))

        Divider()
    }

    // MARK: - Task list (flat, no grouping)

    private var taskList: some View {
        List {
            ForEach(displayedTasks) { task in
                checklistRow(task)
                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                    .listRowSeparator(.hidden)
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        Button {
                            withAnimation { taskStore.toggleCompletion(id: task.id) }
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
            .onMove { from, to in
                // Local move within displayed list — update store
                var reordered = displayedTasks
                reordered.move(fromOffsets: from, toOffset: to)
                // Apply order back to store
                for task in reordered {
                    taskStore.updateTask(task)
                }
            }
        }
        .listStyle(.plain)
        .environment(\.editMode, .constant(.active))  // enables drag-to-reorder handles
    }

    // MARK: - Row

    private func checklistRow(_ task: EisTask) -> some View {
        HStack(spacing: 14) {
            // Checkbox
            Button {
                withAnimation(.spring(response: 0.25)) {
                    taskStore.toggleCompletion(id: task.id)
                }
            } label: {
                ZStack {
                    Circle()
                        .stroke(task.isCompleted ? task.quadrant.color : Color.gray.opacity(0.35), lineWidth: 1.5)
                        .frame(width: 24, height: 24)
                    if task.isCompleted {
                        Circle()
                            .fill(task.quadrant.color.opacity(0.15))
                            .frame(width: 24, height: 24)
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(task.quadrant.color)
                    }
                }
            }
            .buttonStyle(.plain)

            // Content
            VStack(alignment: .leading, spacing: 3) {
                Text(task.title)
                    .font(.body)
                    .strikethrough(task.isCompleted, color: .secondary)
                    .foregroundColor(task.isCompleted ? .secondary : .primary)
                    .animation(.easeInOut(duration: 0.2), value: task.isCompleted)

                HStack(spacing: 8) {
                    // Quadrant label (small, contextual)
                    Text(task.quadrant.emoji + " " + task.quadrant.title)
                        .font(.caption2)
                        .foregroundColor(task.quadrant.color.opacity(0.8))

                    // Due date if set
                    if let due = task.dueDate {
                        Text("·").foregroundColor(.secondary)
                        Image(systemName: "calendar")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(due, style: .date)
                            .font(.caption2)
                            .foregroundColor(due < Date() && !task.isCompleted ? .red : .secondary)
                    }

                    // Notes indicator
                    if !task.notes.isEmpty {
                        Text("·").foregroundColor(.secondary)
                        Image(systemName: "note.text")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            // Color tag
            if task.colorTag != .none {
                Circle()
                    .fill(task.colorTag.color)
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.vertical, 11)
        .contentShape(Rectangle())
        .onTapGesture { editingTask = task }
        .opacity(task.isCompleted ? 0.6 : 1.0)
    }

    // MARK: - Quick add bar

    private var quickAddBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 12) {
                Image(systemName: "plus.circle.fill")
                    .foregroundColor(.blue)
                    .font(.title3)

                TextField("Quick add item…", text: $newItemTitle)
                    .focused($quickAddFocused)
                    .submitLabel(.done)
                    .onSubmit { commitQuickAdd() }

                if !newItemTitle.isEmpty {
                    Button(action: commitQuickAdd) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title3)
                            .foregroundColor(.blue)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(uiColor: .systemBackground))
        }
    }

    // MARK: - Quick add logic

    private func commitQuickAdd() {
        let t = newItemTitle.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return }
        taskStore.addTask(EisTask(title: t, quadrant: .doFirst, isInChecklist: true))
        newItemTitle = ""
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "checklist")
                .font(.system(size: 52))
                .foregroundColor(.secondary.opacity(0.25))
            Text("Your checklist is empty")
                .font(.title3).fontWeight(.medium)
            Text("Type below to quickly add an item,\nor tap + to add a full task.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    ChecklistView().environmentObject(TaskStore())
}
