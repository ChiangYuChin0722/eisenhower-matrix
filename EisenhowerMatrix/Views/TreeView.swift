import SwiftUI

struct TreeView: View {
    @EnvironmentObject var taskStore: TaskStore
    @State private var expandedQuadrants: Set<Quadrant> = Set(Quadrant.allCases)
    @State private var editingTask: EisTask? = nil
    @State private var showingAddTask = false
    @State private var addTaskQuadrant: Quadrant = .doFirst
    @State private var searchText = ""

    var filteredTasks: [EisTask] {
        guard !searchText.isEmpty else { return taskStore.tasks }
        return taskStore.tasks.filter {
            $0.title.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationView {
            List {
                ForEach(Quadrant.allCases) { quadrant in
                    quadrantSection(quadrant)
                }
            }
            .listStyle(.insetGrouped)
            .searchable(text: $searchText, prompt: "Search tasks…")
            .navigationTitle("Tree")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        addTaskQuadrant = .doFirst
                        showingAddTask = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddTask) {
                AddTaskView(defaultQuadrant: addTaskQuadrant)
            }
            .sheet(item: $editingTask) { task in
                AddTaskView(editingTask: task)
            }
        }
    }

    // MARK: - Quadrant section

    @ViewBuilder
    private func quadrantSection(_ quadrant: Quadrant) -> some View {
        let tasks = filteredTasks.filter { $0.quadrant == quadrant }
        let isExpanded = expandedQuadrants.contains(quadrant)

        Section {
            if isExpanded {
                ForEach(tasks) { task in
                    taskRow(task)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                taskStore.deleteTask(id: task.id)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            Button {
                                editingTask = task
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            .tint(.blue)
                        }
                        .swipeActions(edge: .leading) {
                            Button {
                                taskStore.toggleCompletion(id: task.id)
                            } label: {
                                Label(task.isCompleted ? "Undo" : "Done",
                                      systemImage: task.isCompleted ? "arrow.uturn.backward" : "checkmark")
                            }
                            .tint(.green)
                        }
                }
            }
        } header: {
            Button {
                withAnimation {
                    if isExpanded { expandedQuadrants.remove(quadrant) }
                    else          { expandedQuadrants.insert(quadrant) }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    Text(quadrant.emoji + " " + quadrant.title)
                        .font(.subheadline).fontWeight(.semibold)
                        .foregroundColor(quadrant.color)

                    Text(quadrant.subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()

                    Text("\(tasks.count)")
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(quadrant.color)
                        .cornerRadius(10)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Task row with subtasks

    @ViewBuilder
    private func taskRow(_ task: EisTask) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Button { taskStore.toggleCompletion(id: task.id) } label: {
                    Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(task.isCompleted ? task.quadrant.color : .secondary)
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 2) {
                    Text(task.title)
                        .strikethrough(task.isCompleted)
                        .foregroundColor(task.isCompleted ? .secondary : .primary)

                    if let due = task.dueDate {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                                .font(.caption2)
                            Text(due, style: .date)
                                .font(.caption)
                        }
                        .foregroundColor(.secondary)
                    }
                }

                Spacer()

                if task.colorTag != .none {
                    Circle()
                        .fill(task.colorTag.color)
                        .frame(width: 10, height: 10)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { editingTask = task }

            // Subtasks
            if !task.subtasks.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(task.subtasks) { sub in
                        HStack(spacing: 8) {
                            Rectangle()
                                .fill(Color.secondary.opacity(0.3))
                                .frame(width: 1, height: 14)
                                .padding(.leading, 12)
                            Image(systemName: sub.isCompleted ? "checkmark.circle.fill" : "circle")
                                .font(.caption)
                                .foregroundColor(sub.isCompleted ? .green : .secondary)
                            Text(sub.title)
                                .font(.subheadline)
                                .strikethrough(sub.isCompleted)
                                .foregroundColor(sub.isCompleted ? .secondary : .primary)
                        }
                    }
                }
                .padding(.top, 6)
                .padding(.leading, 30)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    TreeView()
        .environmentObject(TaskStore())
}
