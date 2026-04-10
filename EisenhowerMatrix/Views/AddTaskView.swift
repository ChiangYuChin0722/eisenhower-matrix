import SwiftUI

struct AddTaskView: View {
    @EnvironmentObject var taskStore: TaskStore
    @Environment(\.dismiss) var dismiss

    var editingTask: EisTask?       = nil
    var defaultQuadrant: Quadrant    = .doFirst
    var initialCanvasX: Double?      = nil
    var initialCanvasY: Double?      = nil
    var forceCalendar: Bool          = false
    var forceChecklist: Bool         = false
    var defaultCategoryId: UUID?     = nil   // pre-select category from ChecklistView

    @State private var title           = ""
    @State private var notes           = ""
    @State private var quadrant        = Quadrant.doFirst
    @State private var addToCalendar   = false
    @State private var dueDate         = roundedNextHour()
    @State private var addToChecklist  = false
    @State private var colorTag        = TaskColor.none
    @State private var subtaskText     = ""
    @State private var subtasks: [EisTask] = []
    @State private var recurrence      = Recurrence.none
    @State private var selectedCategoryId: UUID? = nil

    var isEditing: Bool { editingTask != nil }

    var body: some View {
        NavigationView {
            Form {
                // MARK: Task basics
                Section("Task") {
                    TextField("Title", text: $title)
                    TextField("Notes (optional)", text: $notes, axis: .vertical)
                        .lineLimit(3, reservesSpace: false)
                }

                // MARK: Quadrant
                Section("Quadrant") {
                    Picker("Quadrant", selection: $quadrant) {
                        ForEach(Quadrant.allCases) { q in
                            Label {
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(q.title).font(.subheadline).fontWeight(.medium)
                                    Text(q.subtitle).font(.caption).foregroundColor(.secondary)
                                }
                            } icon: { Text(q.emoji) }
                            .tag(q)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }

                // MARK: Add to Calendar + Recurrence
                Section {
                    Toggle(isOn: $addToCalendar) {
                        Label("Add to Calendar", systemImage: "calendar")
                    }
                    if addToCalendar {
                        DatePicker("Date & Time", selection: $dueDate,
                                   displayedComponents: [.date, .hourAndMinute])

                        Picker(selection: $recurrence) {
                            ForEach(Recurrence.allCases) { r in
                                Label(r.title, systemImage: r.icon).tag(r)
                            }
                        } label: {
                            Label("Repeat", systemImage: "arrow.clockwise")
                        }
                    }
                }

                // MARK: Add to Checklist + Category
                Section {
                    Toggle(isOn: $addToChecklist) {
                        Label("Add to Checklist", systemImage: "checklist")
                    }
                    if addToChecklist && !taskStore.checklistCategories.isEmpty {
                        Picker("List", selection: $selectedCategoryId) {
                            ForEach(taskStore.checklistCategories) { cat in
                                Label(cat.name, systemImage: cat.icon).tag(Optional(cat.id))
                            }
                        }
                    }
                }

                // MARK: Color tag
                Section("Color Tag") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(TaskColor.allCases, id: \.self) { c in
                                colorCircle(c)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                // MARK: Subtasks
                Section("Subtasks") {
                    ForEach(subtasks) { sub in
                        HStack {
                            Image(systemName: sub.isCompleted ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(sub.isCompleted ? .green : .secondary)
                            Text(sub.title).strikethrough(sub.isCompleted)
                        }
                    }
                    .onDelete { subtasks.remove(atOffsets: $0) }

                    HStack {
                        TextField("Add subtask…", text: $subtaskText)
                        Button("Add") {
                            subtasks.append(EisTask(title: subtaskText, quadrant: quadrant))
                            subtaskText = ""
                        }
                        .disabled(subtaskText.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Task" : "New Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Save" : "Add", action: save)
                        .fontWeight(.semibold)
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear(perform: populate)
        }
    }

    // MARK: - Color circle

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
        .onTapGesture { colorTag = c }
    }

    // MARK: - Populate when editing

    private func populate() {
        if let t = editingTask {
            title              = t.title
            notes              = t.notes
            quadrant           = t.quadrant
            colorTag           = t.colorTag
            subtasks           = t.subtasks
            addToChecklist     = t.isInChecklist
            recurrence         = t.recurrence
            selectedCategoryId = t.checklistCategoryId
            if let d = t.dueDate {
                addToCalendar = true
                dueDate       = d
            }
        } else {
            quadrant           = defaultQuadrant
            addToCalendar      = forceCalendar
            addToChecklist     = forceChecklist
            selectedCategoryId = defaultCategoryId ?? taskStore.checklistCategories.first?.id
        }
    }

    // MARK: - Save

    private func save() {
        var task = editingTask ?? EisTask(
            title: title,
            quadrant: quadrant,
            canvasX: initialCanvasX,
            canvasY: initialCanvasY
        )
        task.title               = title.trimmingCharacters(in: .whitespaces)
        task.notes               = notes
        task.quadrant            = quadrant
        task.dueDate             = addToCalendar ? dueDate : nil
        task.isInChecklist       = addToChecklist
        task.colorTag            = colorTag
        task.subtasks            = subtasks
        task.recurrence          = addToCalendar ? recurrence : .none
        task.checklistCategoryId = addToChecklist ? selectedCategoryId : nil

        if !isEditing {
            if let x = initialCanvasX { task.canvasX = x }
            if let y = initialCanvasY { task.canvasY = y }
        }

        if isEditing { taskStore.updateTask(task) }
        else         { taskStore.addTask(task) }
        dismiss()
    }

    // MARK: - Helpers

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
