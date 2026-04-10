import SwiftUI

struct ChecklistView: View {
    @EnvironmentObject var taskStore: TaskStore
    @AppStorage("appLanguage") private var lang: String = "en"
    @AppStorage("appAccent")   private var appAccent: String = "blue"
    @State private var showAddTask           = false
    @State private var editingTask: EisTask? = nil
    @State private var showCompleted         = false
    @State private var newItemTitle          = ""
    @State private var selectedCategoryId: UUID? = nil
    @State private var showAddCategory       = false
    @State private var newCategoryName       = ""
    @State private var newCategoryIcon       = "list.bullet"
    @FocusState private var quickAddFocused: Bool

    private var s: Str { Str(lang) }
    private var accent: Color { .accent(appAccent) }

    private var displayedTasks: [EisTask] {
        var base = taskStore.checklistTasks
        if let catId = selectedCategoryId {
            base = base.filter { $0.checklistCategoryId == catId }
        }
        if !showCompleted { base = base.filter { !$0.isCompleted } }
        return base.sorted {
            if $0.isCompleted != $1.isCompleted { return !$0.isCompleted }
            return $0.createdAt < $1.createdAt
        }
    }

    private var filteredBase: [EisTask] {
        selectedCategoryId == nil
            ? taskStore.checklistTasks
            : taskStore.checklistTasks.filter { $0.checklistCategoryId == selectedCategoryId }
    }
    private var completedCount: Int { filteredBase.filter { $0.isCompleted }.count }
    private var totalCount: Int     { filteredBase.count }
    private var progress: Double {
        guard totalCount > 0 else { return 0 }
        return Double(completedCount) / Double(totalCount)
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                categoryPicker

                if totalCount > 0 { progressBar }

                if taskStore.checklistTasks.isEmpty {
                    emptyState
                } else if displayedTasks.isEmpty {
                    emptyCategory
                } else {
                    taskList
                }

                quickAddBar
            }
            .navigationTitle(s.tabChecklist)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        withAnimation { showCompleted.toggle() }
                    } label: {
                        Image(systemName: showCompleted ? "eye.slash" : "eye")
                        Text(showCompleted ? s.hideDone : s.showDone).font(.caption)
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
                            defaultCategoryId: selectedCategoryId)
            }
            .sheet(item: $editingTask) { task in AddTaskView(editingTask: task) }
            .sheet(isPresented: $showAddCategory) { addCategorySheet }
        }
    }

    // MARK: - Category picker

    private var categoryPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                categoryChip(id: nil, name: s.allCategory, icon: "tray.full")

                ForEach(taskStore.checklistCategories) { cat in
                    categoryChip(id: cat.id, name: cat.name, icon: cat.icon)
                        .contextMenu {
                            Button(role: .destructive) {
                                taskStore.deleteCategory(id: cat.id)
                                if selectedCategoryId == cat.id { selectedCategoryId = nil }
                            } label: {
                                Label("\(s.delete) \"\(cat.name)\"", systemImage: "trash")
                            }
                        }
                }

                Button {
                    newCategoryName = ""
                    newCategoryIcon = "list.bullet"
                    showAddCategory = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                        Text(s.newList)
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
            withAnimation(.easeInOut(duration: 0.15)) { selectedCategoryId = id }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.caption2)
                Text(name).font(.caption).fontWeight(.medium)
            }
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(isSelected ? accent : Color.secondary.opacity(0.1))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(20)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Add-category sheet

    private var addCategorySheet: some View {
        let iconOptions = [
            "list.bullet","cart","briefcase","house","heart",
            "book","dumbbell","fork.knife","car","airplane",
            "gift","star","music.note","gamecontroller","camera"
        ]
        return NavigationView {
            Form {
                Section(s.listNameLabel) {
                    TextField(s.egGroceries, text: $newCategoryName)
                }
                Section(s.iconLabel) {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 12) {
                        ForEach(iconOptions, id: \.self) { icon in
                            Button { newCategoryIcon = icon } label: {
                                ZStack {
                                    Circle()
                                        .fill(newCategoryIcon == icon ? accent : Color.secondary.opacity(0.1))
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
            .navigationTitle(s.newList)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(s.cancel) { showAddCategory = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(s.add) {
                        let cat = ChecklistCategory(
                            name: newCategoryName.trimmingCharacters(in: .whitespaces),
                            icon: newCategoryIcon
                        )
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
        VStack(spacing: 0) {
            VStack(spacing: 6) {
                HStack {
                    Text("\(completedCount) / \(totalCount) \(s.done.lowercased())")
                        .font(.caption).foregroundColor(.secondary)
                    Spacer()
                    Text("\(Int(progress * 100))%")
                        .font(.caption).fontWeight(.semibold).foregroundColor(accent)
                }
                .padding(.horizontal, 16)
                ProgressView(value: progress).tint(accent).padding(.horizontal, 16)
            }
            .padding(.vertical, 10)
            .background(Color(uiColor: .systemBackground))
            Divider()
        }
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
                            Label(task.isCompleted ? s.undo : s.done,
                                  systemImage: task.isCompleted ? "arrow.uturn.backward" : "checkmark")
                        }
                        .tint(.green)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) { taskStore.deleteTask(id: task.id) } label: {
                            Label(s.delete, systemImage: "trash")
                        }
                        Button { editingTask = task } label: {
                            Label(s.edit, systemImage: "pencil")
                        }
                        .tint(accent)
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
                withAnimation(.spring(response: 0.25)) { taskStore.toggleCompletion(id: task.id) }
            } label: {
                ZStack {
                    Circle()
                        .stroke(task.isCompleted ? task.quadrant.color : Color.gray.opacity(0.35), lineWidth: 1.5)
                        .frame(width: 24, height: 24)
                    if task.isCompleted {
                        Circle().fill(task.quadrant.color.opacity(0.15)).frame(width: 24, height: 24)
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
                    Text(task.quadrant.emoji + " " + s.quadrantTitle(task.quadrant))
                        .font(.caption2)
                        .foregroundColor(task.quadrant.color.opacity(0.8))

                    if task.recurrence != .none {
                        Text("·").foregroundColor(.secondary)
                        Image(systemName: task.recurrence.icon).font(.caption2).foregroundColor(accent)
                    }

                    if let due = task.dueDate {
                        Text("·").foregroundColor(.secondary)
                        Image(systemName: "calendar").font(.caption2).foregroundColor(.secondary)
                        Text(due, style: .date)
                            .font(.caption2)
                            .foregroundColor(due < Date() && !task.isCompleted ? .red : .secondary)
                    }

                    if !task.notes.isEmpty {
                        Text("·").foregroundColor(.secondary)
                        Image(systemName: "note.text").font(.caption2).foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            if task.colorTag != .none {
                Circle().fill(task.colorTag.color).frame(width: 8, height: 8)
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
                Image(systemName: "plus.circle.fill").foregroundColor(accent).font(.title3)
                TextField(s.quickAddPlaceholder, text: $newItemTitle)
                    .focused($quickAddFocused)
                    .submitLabel(.done)
                    .onSubmit { commitQuickAdd() }
                if !newItemTitle.isEmpty {
                    Button(action: commitQuickAdd) {
                        Image(systemName: "arrow.up.circle.fill").font(.title3).foregroundColor(accent)
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
                                  checklistCategoryId: selectedCategoryId ?? taskStore.checklistCategories.first?.id))
        newItemTitle = ""
    }

    // MARK: - Empty states

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "checklist").font(.system(size: 52)).foregroundColor(.secondary.opacity(0.25))
            Text(s.emptyChecklistTitle).font(.title3).fontWeight(.medium)
            Text(s.emptyChecklistSub).font(.subheadline).foregroundColor(.secondary).multilineTextAlignment(.center)
            Spacer()
        }
        .padding().frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyCategory: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "tray").font(.system(size: 44)).foregroundColor(.secondary.opacity(0.3))
            Text(s.emptyCategoryMsg).font(.subheadline).foregroundColor(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    ChecklistView().environmentObject(TaskStore())
}
