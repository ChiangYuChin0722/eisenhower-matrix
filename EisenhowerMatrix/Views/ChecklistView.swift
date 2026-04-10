import SwiftUI

struct ChecklistView: View {
    @EnvironmentObject var taskStore: TaskStore
    @AppStorage("appLanguage") private var lang: String = "en"
    @AppStorage("appAccent")   private var appAccent: String = "blue"
    @AppStorage("matrixTheme") private var matrixTheme: String = "classic"
    private func qColor(_ q: Quadrant) -> Color { q.color(theme: matrixTheme) }
    private func qBg(_ q: Quadrant)    -> Color { q.bgColor(theme: matrixTheme) }

    @State private var editingTask: EisTask? = nil
    @State private var showCompleted         = false
    @State private var showQuickAdd          = false
    @State private var selectedCategoryId: UUID? = nil
    @State private var showAddCategory       = false
    @State private var newCategoryName       = ""
    @State private var newCategoryIcon       = "list.bullet"
    @State private var expandedIds           = Set<UUID>()
    @State private var isReorderMode         = false
    @State private var showSearch            = false
    @State private var showPomodoro          = false
    @State private var pomodoroTask: EisTask? = nil

    private var s: Str { Str(lang) }
    private var accent: Color { .accent(appAccent) }

    // MARK: - Derived data

    private var displayedTasks: [EisTask] {
        var base = taskStore.checklistTasks
        if let catId = selectedCategoryId {
            base = base.filter { $0.checklistCategoryId == catId }
        }
        if !showCompleted { base = base.filter { !$0.isCompleted } }
        return base.sorted {
            if $0.isCompleted != $1.isCompleted { return !$0.isCompleted }
            if $0.sortOrder   != $1.sortOrder   { return $0.sortOrder < $1.sortOrder }
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

    // MARK: - Body

    var body: some View {
        NavigationView {
            ZStack(alignment: .bottomTrailing) {
                VStack(spacing: 0) {
                    if !isReorderMode { categoryPicker }

                    if taskStore.checklistTasks.isEmpty {
                        emptyState
                    } else if displayedTasks.isEmpty {
                        emptyCategory
                    } else {
                        taskList
                    }
                }

                // FAB — hidden while in reorder mode
                if !isReorderMode {
                    Button { showQuickAdd = true } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 56, height: 56)
                            .background(accent)
                            .clipShape(Circle())
                            .shadow(color: accent.opacity(0.4), radius: 8, y: 4)
                    }
                    .padding(.trailing, 20)
                    .padding(.bottom, 16)
                }
            }
            .navigationTitle(s.tabChecklist)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Group {
                        if isReorderMode {
                            Button(s.doneReorder) {
                                withAnimation { isReorderMode = false }
                            }
                            .fontWeight(.semibold)
                        } else {
                            // Icon-only eye button — no text
                            Button {
                                withAnimation { showCompleted.toggle() }
                            } label: {
                                Image(systemName: showCompleted ? "eye.slash" : "eye")
                                    .font(.system(size: 15))
                            }
                            .foregroundColor(.secondary)
                        }
                    }
                }
                if !isReorderMode {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        HStack(spacing: 2) {
                            Button {
                                withAnimation { isReorderMode = true }
                            } label: {
                                Image(systemName: "arrow.up.arrow.down")
                            }
                            Button { showSearch = true } label: {
                                Image(systemName: "magnifyingglass")
                            }
                        }
                    }
                }
            }
            .sheet(item: $editingTask) { task in AddTaskView(editingTask: task) }
            .sheet(isPresented: $showAddCategory) { addCategorySheet }
            .sheet(isPresented: $showQuickAdd) {
                ChecklistQuickAddSheet(defaultCategoryId: selectedCategoryId)
            }
            .sheet(isPresented: $showSearch) { SearchView() }
            .sheet(isPresented: $showPomodoro) {
                PomodoroView(initialTask: pomodoroTask)
            }
        }
    }

    // MARK: - Task list

    private var taskList: some View {
        List {
            // Progress bar inline — no gap between it and the first row
            if totalCount > 0 {
                HStack(spacing: 0) {
                    Text("\(completedCount) / \(totalCount) \(s.done.lowercased())")
                        .font(.caption).foregroundColor(.secondary)
                    Spacer()
                    Text("\(Int(progress * 100))%")
                        .font(.caption).fontWeight(.semibold).foregroundColor(accent)
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: completedCount)
                }
                .padding(.horizontal, 16)
                .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 2, trailing: 0))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

                ProgressView(value: progress).tint(accent)
                    .padding(.horizontal, 16)
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 6, trailing: 0))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .animation(.spring(response: 0.5, dampingFraction: 0.7), value: progress)
            }

            if isReorderMode {
                ForEach(displayedTasks) { task in
                    checklistRow(task)
                        .listRowInsets(EdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 12))
                        .listRowSeparator(.hidden)
                }
                .onMove { from, to in
                    var reordered = displayedTasks
                    reordered.move(fromOffsets: from, toOffset: to)
                    taskStore.reorderChecklistTasks(reordered)
                }
            } else {
                ForEach(displayedTasks) { task in
                    checklistRow(task)
                        .listRowInsets(EdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 12))
                        .listRowSeparator(.hidden)
                        .transition(.asymmetric(
                            insertion: .move(edge: .leading).combined(with: .opacity),
                            removal:   .opacity
                        ))
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            Button {
                                pomodoroTask = task
                                showPomodoro = true
                            } label: {
                                Label(s.focusLabel, systemImage: "timer")
                            }
                            .tint(.purple)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                taskStore.deleteTask(id: task.id)
                            } label: {
                                Label(s.delete, systemImage: "trash")
                            }
                            .tint(.red)
                            Button { editingTask = task } label: {
                                Label(s.edit, systemImage: "pencil")
                            }
                            .tint(accent)
                        }
                }
                .animation(.spring(response: 0.38, dampingFraction: 0.78), value: displayedTasks.map(\.id))
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.appBackground)
        .environment(\.editMode, .constant(isReorderMode ? .active : .inactive))
    }

    // MARK: - Row

    private func checklistRow(_ task: EisTask) -> some View {
        let isExpanded = expandedIds.contains(task.id)
        let hasExtra   = !task.subtasks.isEmpty || !task.notes.isEmpty

        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 14) {
                completionButton(task)

                VStack(alignment: .leading, spacing: 3) {
                    Text(task.title)
                        .font(.body)
                        .strikethrough(task.isCompleted, color: .secondary)
                        .foregroundColor(task.isCompleted ? .secondary : .primary)
                        .animation(.easeInOut(duration: 0.2), value: task.isCompleted)

                    metaRow(task)

                    if !task.subtasks.isEmpty && !isExpanded {
                        Text(s.subtasksOf(task.completedSubtaskCount, task.totalSubtaskCount))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                if task.colorTag != .none {
                    HStack(spacing: 3) {
                        Circle().fill(task.colorTag.color).frame(width: 7, height: 7)
                        if !task.colorTagLabel.isEmpty {
                            Text(task.colorTagLabel)
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(task.colorTag.color)
                        }
                    }
                    .padding(.horizontal, task.colorTagLabel.isEmpty ? 0 : 5)
                    .padding(.vertical, task.colorTagLabel.isEmpty ? 0 : 2)
                    .background(task.colorTagLabel.isEmpty ? .clear : task.colorTag.color.opacity(0.12))
                    .cornerRadius(4)
                }

                if hasExtra && !isReorderMode {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary.opacity(0.6))
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .animation(.easeInOut(duration: 0.2), value: isExpanded)
                }
            }
            .padding(.vertical, 11)
            .contentShape(Rectangle())
            .onTapGesture {
                if hasExtra {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        if expandedIds.contains(task.id) {
                            expandedIds.remove(task.id)
                        } else {
                            expandedIds.insert(task.id)
                        }
                    }
                } else {
                    editingTask = task
                }
            }

            if isExpanded {
                expandedContent(task)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .opacity(task.isCompleted ? 0.65 : 1.0)
    }

    private func completionButton(_ task: EisTask) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                taskStore.toggleCompletion(id: task.id)
            }
        } label: {
            ZStack {
                Circle()
                    .stroke(task.isCompleted ? qColor(task.quadrant) : Color.gray.opacity(0.35), lineWidth: 1.5)
                    .frame(width: 24, height: 24)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: task.isCompleted)
                if task.isCompleted {
                    Circle()
                        .fill(qColor(task.quadrant).opacity(0.15))
                        .frame(width: 24, height: 24)
                        .transition(.scale.combined(with: .opacity))
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(qColor(task.quadrant))
                        .transition(.scale(scale: 0.4).combined(with: .opacity))
                }
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func metaRow(_ task: EisTask) -> some View {
        HStack(spacing: 6) {
            Text(s.quadrantTitle(task.quadrant))
                .font(.caption2)
                .foregroundColor(qColor(task.quadrant).opacity(0.8))

            if task.recurrence != .none {
                Text("·").foregroundColor(.secondary).font(.caption2)
                Image(systemName: task.recurrence.icon).font(.caption2).foregroundColor(accent)
            }

            if let due = task.dueDate {
                Text("·").foregroundColor(.secondary).font(.caption2)
                Image(systemName: "calendar").font(.caption2).foregroundColor(.secondary)
                Text(due, style: .date)
                    .font(.caption2)
                    .foregroundColor(due < Date() && !task.isCompleted ? .red : .secondary)
            }
        }
    }

    @ViewBuilder
    private func expandedContent(_ task: EisTask) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if !task.notes.isEmpty {
                Text(task.notes)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(4)
                    .padding(.leading, 38)
                    .padding(.trailing, 16)
                    .padding(.bottom, task.subtasks.isEmpty ? 10 : 6)
            }

            if !task.subtasks.isEmpty {
                Divider().padding(.leading, 38)
                ForEach(task.subtasks) { sub in
                    subtaskRow(sub, parentId: task.id)
                }
                .padding(.bottom, 4)
            }
        }
    }

    private func subtaskRow(_ sub: EisTask, parentId: UUID) -> some View {
        HStack(spacing: 10) {
            Color.clear.frame(width: 38, height: 1)

            Button {
                taskStore.toggleSubtaskCompletion(taskId: parentId, subtaskId: sub.id)
            } label: {
                ZStack {
                    Circle()
                        .stroke(sub.isCompleted
                                ? Color.secondary.opacity(0.35)
                                : Color.gray.opacity(0.35),
                                lineWidth: 1.5)
                        .frame(width: 20, height: 20)
                    if sub.isCompleted {
                        Image(systemName: "checkmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .buttonStyle(.plain)

            Text(sub.title)
                .font(.subheadline)
                .foregroundColor(sub.isCompleted ? .secondary : .primary)
                .strikethrough(sub.isCompleted, color: .secondary)

            Spacer()
        }
        .padding(.vertical, 7)
        .contentShape(Rectangle())
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
        .background(Color.appBackground)
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

// MARK: - Quick Add Sheet

private struct ChecklistQuickAddSheet: View {
    @EnvironmentObject var taskStore: TaskStore
    @Environment(\.dismiss) var dismiss
    @AppStorage("appLanguage") private var lang: String = "en"
    @AppStorage("appAccent")   private var appAccent: String = "blue"
    @AppStorage("matrixTheme") private var matrixTheme: String = "classic"

    let defaultCategoryId: UUID?

    @State private var title    = ""
    @State private var notes    = ""
    @State private var quadrant = Quadrant.doFirst
    @FocusState private var titleFocused: Bool

    private var s: Str { Str(lang) }
    private var accent: Color { .accent(appAccent) }
    private func qColor(_ q: Quadrant) -> Color { q.color(theme: matrixTheme) }

    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField(s.titleField, text: $title)
                        .focused($titleFocused)
                    TextField(s.notesField, text: $notes, axis: .vertical)
                        .lineLimit(3, reservesSpace: false)
                }

                Section(s.quadrantSection) {
                    LazyVGrid(
                        columns: [GridItem(.flexible()), GridItem(.flexible())],
                        spacing: 10
                    ) {
                        ForEach(Quadrant.allCases) { q in
                            Button {
                                HapticManager.shared.selection()
                                quadrant = q
                            } label: {
                                HStack(spacing: 8) {
                                    Circle()
                                        .fill(qColor(q))
                                        .frame(width: 10, height: 10)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(s.quadrantTitle(q))
                                            .font(.caption).fontWeight(.semibold)
                                            .foregroundColor(qColor(q))
                                        Text(s.quadrantSubtitle(q))
                                            .font(.system(size: 9))
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .background(quadrant == q ? qColor(q).opacity(0.12) : Color.secondary.opacity(0.06))
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(quadrant == q ? qColor(q) : .clear, lineWidth: 1.5)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                    .listRowBackground(Color.clear)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.appBackground)
            .navigationTitle(s.addTask)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(s.cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(s.add) { save() }
                        .fontWeight(.semibold)
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear { titleFocused = true }
        }
        .presentationDetents([.medium, .large])
    }

    private func save() {
        let t = title.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return }
        taskStore.addTask(EisTask(
            title: t,
            quadrant: quadrant,
            notes: notes.trimmingCharacters(in: .whitespaces),
            isInChecklist: true,
            checklistCategoryId: defaultCategoryId ?? taskStore.checklistCategories.first?.id
        ))
        dismiss()
    }
}

#Preview {
    ChecklistView().environmentObject(TaskStore())
}
