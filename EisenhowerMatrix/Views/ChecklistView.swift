import SwiftUI

struct ChecklistView: View {
    @EnvironmentObject var taskStore: TaskStore
    @State private var showAddTask       = false
    @State private var editingTask: EisTask? = nil
    @State private var showCompleted     = false
    @State private var newItemTitle      = ""
    @State private var selectedCategoryId: UUID? = nil   // nil = All
    @State private var showAddCategory   = false
    @State private var newCategoryName   = ""
    @State private var newCategoryIcon   = "list.bullet"
    @FocusState private var quickAddFocused: Bool

    // Category being displayed (nil = all)
    private var activeCategoryId: UUID? { selectedCategoryId }

    private var displayedTasks: [EisTask] {
        var base = taskStore.checklistTasks
        if let catId = activeCategoryId {
            base = base.filter { $0.checklistCategoryId == catId }
        }
        if !showCompleted { base = base.filter { !$0.isCompleted } }
        return base.sorted {
            if $0.isCompleted != $1.isCompleted { return !$0.isCompleted }
            return $0.createdAt < $1.createdAt
        }
    }

    private var completedCount: Int {
        let base = activeCategoryId == nil
            ? taskStore.checklistTasks
            : taskStore.checklistTasks.filter { $0.checklistCategoryId == activeCategoryId }
        return base.filter { $0.isCompleted }.count
    }
    private var totalCount: Int {
        let base = activeCategoryId == nil
            ? taskStore.checklistTasks
            : taskStore.checklistTasks.filter { $0.checklistCategoryId == activeCategoryId }
        return base.count
    }
    private var progress: Double {
        guard totalCount > 0 else { return 0 }
        return Double(completedCount) / Double(totalCount)
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                categoryPicker

                if totalCount > 0 {
                    progressBar
                }

                if taskStore.checklistTasks.isEmpty {
                    emptyState
                } else if displayedTasks.isEmpty && !taskStore.checklistTasks.isEmpty {
                    emptyCategory
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
                AddTaskView(defaultQuadrant: .doFirst, forceChecklist: true,
                            defaultCategoryId: activeCategoryId)
            }
            .sheet(item: $editingTask) { task in
                AddTaskView(editingTask: task)
            }
            .sheet(isPresented: $showAddCategory) {
                addCategorySheet
            }
        }
    }

    // MARK: - Category picker

    private var categoryPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // "All" chip
                categoryChip(id: nil, name: "All", icon: "tray.full")

                ForEach(taskStore.checklistCategories) { cat in
                    categoryChip(id: cat.id, name: cat.name, icon: cat.icon)
                        .contextMenu {
                            Button(role: .destructive) {
                                taskStore.deleteCategory(id: cat.id)
                                if selectedCategoryId == cat.id { selectedCategoryId = nil }
                            } label: {
                                Label("Delete \"\(cat.name)\"", systemImage: "trash")
                            }
                        }
                }

                // Add category button
                Button {
                    newCategoryName = ""
                    newCategoryIcon = "list.bullet"
                    showAddCategory = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                        Text("New List")
                    }
                    .font(.caption).fontWeight(.medium)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(20)
                    .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(Color(uiColor: .systemBackground))
    }

    private func categoryChip(id: UUID?, name: String, icon: String) -> some View {
        let isSelected = selectedCategoryId == id
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedCategoryId = id
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.caption2)
                Text(name).font(.caption).fontWeight(.medium)
            }
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(isSelected ? Color.blue : Color.secondary.opacity(0.1))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(20)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Add-category sheet

    private var addCategorySheet: some View {
        let iconOptions = [
            "list.bullet", "cart", "briefcase", "house", "heart",
            "book", "dumbbell", "fork.knife", "car", "airplane",
            "gift", "star", "music.note", "gamecontroller", "camera"
        ]
        return NavigationView {
            Form {
                Section("List Name") {
                    TextField("e.g. Groceries", text: $newCategoryName)
                }
                Section("Icon") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 12) {
                        ForEach(iconOptions, id: \.self) { icon in
                            Button {
                                newCategoryIcon = icon
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(newCategoryIcon == icon ? Color.blue : Color.secondary.opacity(0.1))
                                        .frame(width: 44, height: 44)
                                    Image(systemName: icon)
                                        .foregroundColor(newCategoryIcon == icon ? .white : .primary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("New List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showAddCategory = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let cat = ChecklistCategory(name: newCategoryName.trimmingCharacters(in: .whitespaces),
                                                    icon: newCategoryIcon)
                        taskStore.addCategory(cat)
                        selectedCategoryId = cat.id
                        showAddCategory = false
                    }
                    .fontWeight(.semibold)
                    .disabled(newCategoryName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
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

    // MARK: - Task list

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
                var reordered = displayedTasks
                reordered.move(fromOffsets: from, toOffset: to)
                for task in reordered { taskStore.updateTask(task) }
            }
        }
        .listStyle(.plain)
        .environment(\.editMode, .constant(.active))
    }

    // MARK: - Row

    private func checklistRow(_ task: EisTask) -> some View {
        HStack(spacing: 14) {
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

            VStack(alignment: .leading, spacing: 3) {
                Text(task.title)
                    .font(.body)
                    .strikethrough(task.isCompleted, color: .secondary)
                    .foregroundColor(task.isCompleted ? .secondary : .primary)
                    .animation(.easeInOut(duration: 0.2), value: task.isCompleted)

                HStack(spacing: 8) {
                    Text(task.quadrant.emoji + " " + task.quadrant.title)
                        .font(.caption2)
                        .foregroundColor(task.quadrant.color.opacity(0.8))

                    if task.recurrence != .none {
                        Text("·").foregroundColor(.secondary)
                        Image(systemName: task.recurrence.icon)
                            .font(.caption2)
                            .foregroundColor(.blue)
                    }

                    if let due = task.dueDate {
                        Text("·").foregroundColor(.secondary)
                        Image(systemName: "calendar")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(due, style: .date)
                            .font(.caption2)
                            .foregroundColor(due < Date() && !task.isCompleted ? .red : .secondary)
                    }

                    if !task.notes.isEmpty {
                        Text("·").foregroundColor(.secondary)
                        Image(systemName: "note.text")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

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

    private func commitQuickAdd() {
        let t = newItemTitle.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return }
        taskStore.addTask(EisTask(title: t, quadrant: .doFirst, isInChecklist: true,
                                  checklistCategoryId: activeCategoryId ?? taskStore.checklistCategories.first?.id))
        newItemTitle = ""
    }

    // MARK: - Empty states

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

    private var emptyCategory: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "tray")
                .font(.system(size: 44))
                .foregroundColor(.secondary.opacity(0.3))
            Text("No items in this list")
                .font(.subheadline).foregroundColor(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    ChecklistView().environmentObject(TaskStore())
}
