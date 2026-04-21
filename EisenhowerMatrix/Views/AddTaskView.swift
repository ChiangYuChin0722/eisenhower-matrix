import SwiftUI

struct AddTaskView: View {
    @EnvironmentObject var taskStore: TaskStore
    @Environment(\.dismiss) var dismiss
    @AppStorage("appLanguage") private var lang: String = "en"
    @AppStorage("matrixTheme") private var matrixTheme: String = "classic"
    private func qColor(_ q: Quadrant) -> Color { q.color(theme: matrixTheme) }

    var editingTask: EisTask?       = nil
    var defaultQuadrant: Quadrant    = .doFirst
    var initialCanvasX: Double?      = nil
    var initialCanvasY: Double?      = nil
    var forceCalendar: Bool          = false
    var forceChecklist: Bool         = false
    var defaultCategoryId: UUID?     = nil

    @State private var title           = ""
    @State private var notes           = ""
    @State private var quadrant        = Quadrant.doFirst
    @State private var addToMatrix      = true
    @State private var hasDueDate      = false
    @State private var dueDate         = roundedNextHour()
    @State private var addToChecklist  = false
    @State private var colorTag        = TaskColor.red
    @State private var colorTagLabel   = ""
    @State private var customTagColor  = Color.red
    @State private var useCustomColor  = false
    @State private var subtaskText     = ""
    @State private var subtasks: [EisTask] = []
    @State private var links: [String] = []
    @State private var recurrence      = Recurrence.none
    @State private var selectedCategoryId: UUID? = nil
    @State private var showDeleteConfirm = false
    @State private var isCompleted     = false

    var isEditing: Bool { editingTask != nil }
    private var s: Str { Str(lang) }

    var body: some View {
        NavigationView {
            Form {
                // Completion status banner when editing a completed task
                if isEditing {
                    Section {
                        Button {
                            isCompleted.toggle()
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                                    .font(.title3)
                                    .foregroundColor(isCompleted ? .green : .secondary)
                                Text(isCompleted
                                     ? (lang == "zh" ? "已完成 — 點擊取消完成" : "Completed — tap to undo")
                                     : (lang == "zh" ? "標記為完成" : "Mark as Complete"))
                                    .foregroundColor(isCompleted ? .green : .primary)
                                Spacer()
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }

                Section(s.taskSection) {
                    TextField(s.titleField, text: $title)
                    TextField(s.notesField, text: $notes, axis: .vertical)
                        .lineLimit(3, reservesSpace: false)
                }

                Section {
                    Toggle(isOn: $addToMatrix) {
                        Label(lang == "zh" ? "加入象限矩陣" : "Add to Matrix",
                              systemImage: "square.grid.2x2")
                    }
                    if addToMatrix {
                        Picker(s.quadrantSection, selection: $quadrant) {
                            ForEach(Quadrant.allCases) { q in
                                Label {
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(s.quadrantTitle(q))
                                            .font(.subheadline).fontWeight(.medium)
                                        Text(s.quadrantSubtitle(q))
                                            .font(.caption).foregroundColor(.secondary)
                                    }
                                } icon: {
                                    Circle()
                                        .fill(qColor(q))
                                        .frame(width: 12, height: 12)
                                }
                                .tag(q)
                            }
                        }
                        .pickerStyle(.inline)
                        .labelsHidden()
                    }
                }

                Section {
                    Toggle(isOn: $hasDueDate) {
                        Label(lang == "zh" ? "加截止日期" : "Set Deadline",
                              systemImage: "clock")
                    }
                    if hasDueDate {
                        DatePicker(s.dateTimeLabel, selection: $dueDate,
                                   displayedComponents: [.date, .hourAndMinute])

                        Picker(selection: $recurrence) {
                            ForEach(Recurrence.allCases) { r in
                                Label(r.title, systemImage: r.icon).tag(r)
                            }
                        } label: {
                            Label(s.repeatLabel, systemImage: "arrow.clockwise")
                        }
                    }
                }

                Section {
                    Toggle(isOn: $addToChecklist) {
                        Label(s.addToChecklist, systemImage: "checklist")
                    }
                    if addToChecklist && !taskStore.checklistCategories.isEmpty {
                        Picker(s.listPickerLabel, selection: $selectedCategoryId) {
                            ForEach(taskStore.checklistCategories) { cat in
                                Label(cat.name, systemImage: cat.icon).tag(Optional(cat.id))
                            }
                        }
                    }
                }

                // Saved tag presets (only show when at least one saved label exists)
                let presets = savedTagPresets
                if !presets.isEmpty {
                    Section(lang == "zh" ? "常用標籤" : "Saved Tags") {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(presets, id: \.0) { (color, label) in
                                    Button {
                                        colorTag       = color
                                        colorTagLabel  = label
                                        useCustomColor = false
                                    } label: {
                                        HStack(spacing: 5) {
                                            Circle().fill(color.color).frame(width: 8, height: 8)
                                            Text(label)
                                                .font(.caption).fontWeight(.medium)
                                        }
                                        .padding(.horizontal, 10).padding(.vertical, 5)
                                        .background(
                                            (colorTag == color && colorTagLabel == label && !useCustomColor)
                                                ? color.color.opacity(0.18)
                                                : Color.secondary.opacity(0.1)
                                        )
                                        .cornerRadius(14)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 14)
                                                .stroke(
                                                    (colorTag == color && colorTagLabel == label && !useCustomColor)
                                                        ? color.color : Color.clear,
                                                    lineWidth: 1.5
                                                )
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }

                Section(s.colorTagSection) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(TaskColor.allCases, id: \.self) { c in
                                colorCircle(c)
                            }
                            // Custom colour picker
                            ZStack {
                                ColorPicker("", selection: $customTagColor, supportsOpacity: false)
                                    .labelsHidden()
                                    .frame(width: 30, height: 30)
                                    .onChange(of: customTagColor) { _ in
                                        useCustomColor = true
                                        colorTag = .none
                                    }
                                if useCustomColor {
                                    Circle()
                                        .stroke(Color.primary, lineWidth: 2)
                                        .frame(width: 34, height: 34)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                        .padding(.horizontal, 4)
                    }
                }

                if colorTag != .none || useCustomColor {
                    Section {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(useCustomColor ? customTagColor : colorTag.color)
                                .frame(width: 10, height: 10)
                                .allowsHitTesting(false)
                            TextField(lang == "zh" ? "標籤名稱（選填）" : "Tag label (optional)",
                                      text: $colorTagLabel)
                            Button {
                                colorTag = .none
                                useCustomColor = false
                                colorTagLabel = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }

                Section(s.subtasksSection) {
                    ForEach(subtasks) { sub in
                        HStack {
                            Image(systemName: sub.isCompleted ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(sub.isCompleted ? .green : .secondary)
                            Text(sub.title).strikethrough(sub.isCompleted)
                        }
                    }
                    .onDelete { subtasks.remove(atOffsets: $0) }

                    HStack {
                        TextField(s.addSubtask, text: $subtaskText)
                        Button(s.add) {
                            subtasks.append(EisTask(title: subtaskText, quadrant: quadrant))
                            subtaskText = ""
                        }
                        .disabled(subtaskText.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }

                Section(lang == "zh" ? "連結" : "Links") {
                    ForEach(links.indices, id: \.self) { i in
                        HStack(spacing: 8) {
                            Image(systemName: "link").foregroundColor(.blue).font(.caption)
                            TextField("https://...", text: $links[i])
                                .keyboardType(.URL)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                            if !links[i].isEmpty {
                                Button { UIApplication.shared.open(URL(string: links[i]) ?? URL(string: "https://")!) } label: {
                                    Image(systemName: "arrow.up.right.square").foregroundColor(.blue)
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                    }
                    .onDelete { links.remove(atOffsets: $0) }
                    Button { links.append("") } label: {
                        Label(lang == "zh" ? "新增連結" : "Add Link", systemImage: "plus")
                    }
                }

                if isEditing {
                    Section {
                        Button(role: .destructive) {
                            showDeleteConfirm = true
                        } label: {
                            HStack {
                                Spacer()
                                Text(lang == "zh" ? "刪除任務" : "Delete Task")
                                Spacer()
                            }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.appBackground)
            .navigationTitle(isEditing ? s.editTaskTitle : s.newTaskTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(s.cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? s.save : s.add, action: save)
                        .fontWeight(.semibold)
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear(perform: populate)
            .alert(lang == "zh" ? "刪除任務" : "Delete Task",
                   isPresented: $showDeleteConfirm) {
                Button(lang == "zh" ? "刪除" : "Delete", role: .destructive) {
                    if let task = editingTask {
                        taskStore.deleteTask(id: task.id)
                    }
                    dismiss()
                }
                Button(lang == "zh" ? "取消" : "Cancel", role: .cancel) {}
            } message: {
                Text(lang == "zh" ? "確定要刪除這個任務嗎？" : "Are you sure you want to delete this task?")
            }
        }
    }

    // MARK: - Tag presets

    private var savedTagPresets: [(TaskColor, String)] {
        TaskColor.allCases.compactMap { c -> (TaskColor, String)? in
            guard c != .none else { return nil }
            let label = savedTagLabel(for: c)
            return label.isEmpty ? nil : (c, label)
        }
    }

    private func savedTagLabel(for color: TaskColor) -> String {
        UserDefaults.standard.string(forKey: "tagLabel_\(color.rawValue)") ?? ""
    }

    private func persistTagLabel(_ label: String, for color: TaskColor) {
        guard !label.isEmpty else { return }
        UserDefaults.standard.set(label, forKey: "tagLabel_\(color.rawValue)")
    }

    private func colorCircle(_ c: TaskColor) -> some View {
        ZStack {
            Circle()
                .fill(c == .none ? Color.gray.opacity(0.2) : c.color)
                .frame(width: 30, height: 30)
            if c == .none {
                Image(systemName: "xmark").font(.caption).foregroundColor(.secondary)
            }
            if colorTag == c {
                Circle().stroke(Color.primary, lineWidth: 2).frame(width: 34, height: 34)
            }
        }
        .onTapGesture {
            colorTag = c
            useCustomColor = false
            if c == .none {
                colorTagLabel = ""
            } else {
                colorTagLabel = savedTagLabel(for: c)
            }
        }
    }

    // MARK: - Populate / Save

    private func populate() {
        if let t = editingTask {
            title              = t.title
            notes              = t.notes
            quadrant           = t.quadrant
            addToMatrix        = t.showInMatrix ?? true
            colorTag           = t.colorTag
            colorTagLabel      = t.colorTagLabel
            isCompleted        = t.isCompleted
            if let hex = t.tagHex, let c = Color(hex: hex) {
                customTagColor = c
                useCustomColor = true
                colorTag       = .none
            }
            subtasks           = t.subtasks
            links              = t.links
            addToChecklist     = t.isInChecklist
            recurrence         = t.recurrence
            selectedCategoryId = t.checklistCategoryId
            if let d = t.dueDate {
                hasDueDate = true
                dueDate    = d
            }
        } else {
            quadrant           = defaultQuadrant
            addToMatrix        = true
            hasDueDate         = forceCalendar
            addToChecklist     = forceChecklist
            selectedCategoryId = defaultCategoryId ?? taskStore.checklistCategories.first?.id
            links              = []
        }
    }

    private func save() {
        if colorTag != .none && !colorTagLabel.isEmpty { persistTagLabel(colorTagLabel, for: colorTag) }
        var task = editingTask ?? EisTask(
            title: title, quadrant: quadrant,
            canvasX: initialCanvasX, canvasY: initialCanvasY
        )
        task.title               = title.trimmingCharacters(in: .whitespaces)
        task.notes               = notes
        task.quadrant            = quadrant
        task.showInMatrix        = addToMatrix
        task.dueDate             = hasDueDate ? dueDate : nil
        task.isInChecklist       = addToChecklist
        if useCustomColor {
            task.colorTag      = .none
            task.tagHex        = customTagColor.toHex()
        } else {
            task.colorTag      = colorTag
            task.tagHex        = nil
        }
        task.colorTagLabel     = (colorTag != .none || useCustomColor)
                                   ? colorTagLabel.trimmingCharacters(in: .whitespaces)
                                   : ""
        task.subtasks            = subtasks
        task.links               = links.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        task.recurrence          = hasDueDate ? recurrence : .none
        task.checklistCategoryId = addToChecklist ? selectedCategoryId : nil

        if !isEditing {
            if let x = initialCanvasX { task.canvasX = x }
            if let y = initialCanvasY { task.canvasY = y }
        }

        // Handle completion state change
        let wasCompleted = editingTask?.isCompleted ?? false
        if isCompleted && !wasCompleted {
            task.isCompleted  = true
            task.completedAt  = Date()
            // Spawn next recurrence when completing a recurring task
            if task.recurrence != .none, let due = task.dueDate,
               let nextDue = task.recurrence.nextDate(after: due) {
                var next = task
                next.id          = UUID()
                next.isCompleted = false
                next.completedAt = nil
                next.dueDate     = nextDue
                next.createdAt   = Date()
                taskStore.addTask(next)
            }
        } else if !isCompleted && wasCompleted {
            task.isCompleted = false
            task.completedAt = nil
        }

        if isEditing { taskStore.updateTask(task) }
        else         { taskStore.addTask(task) }
        dismiss()
    }

    private static func roundedNextHour() -> Date {
        let cal  = Calendar.current
        let now  = Date()
        let next = cal.date(byAdding: .hour, value: 1, to: now)!
        return cal.date(bySetting: .minute, value: 0, of: next) ?? next
    }
}

#Preview {
    AddTaskView().environmentObject(TaskStore())
}
