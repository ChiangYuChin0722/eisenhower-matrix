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
    @State private var addToCalendar   = false
    @State private var dueDate         = roundedNextHour()
    @State private var addToChecklist  = false
    @State private var colorTag        = TaskColor.red
    @State private var colorTagLabel   = ""
    @State private var customTagColor  = Color.red
    @State private var useCustomColor  = false
    @State private var subtaskText     = ""
    @State private var subtasks: [EisTask] = []
    @State private var recurrence      = Recurrence.none
    @State private var selectedCategoryId: UUID? = nil

    var isEditing: Bool { editingTask != nil }
    private var s: Str { Str(lang) }

    var body: some View {
        NavigationView {
            Form {
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
                    Toggle(isOn: $addToCalendar) {
                        Label(s.addToCalendar, systemImage: "calendar")
                    }
                    if addToCalendar {
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

                Section(s.colorTagSection) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            // Preset colour shortcuts
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
                                // Ring when active
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

                // Tag label — own Section so it's completely isolated from the horizontal
                // ScrollView above (which steals gestures and blocks the TextField).
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
        }
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
            if c == .none { colorTagLabel = "" }
        }
    }

    private func populate() {
        if let t = editingTask {
            title              = t.title
            notes              = t.notes
            quadrant           = t.quadrant
            addToMatrix        = t.showInMatrix ?? true
            colorTag           = t.colorTag
            colorTagLabel      = t.colorTagLabel
            if let hex = t.tagHex, let c = Color(hex: hex) {
                customTagColor = c
                useCustomColor = true
                colorTag       = .none
            }
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
            addToMatrix        = true
            addToCalendar      = forceCalendar
            addToChecklist     = forceChecklist
            selectedCategoryId = defaultCategoryId ?? taskStore.checklistCategories.first?.id
        }
    }

    private func save() {
        var task = editingTask ?? EisTask(
            title: title, quadrant: quadrant,
            canvasX: initialCanvasX, canvasY: initialCanvasY
        )
        task.title               = title.trimmingCharacters(in: .whitespaces)
        task.notes               = notes
        task.quadrant            = quadrant
        task.showInMatrix        = addToMatrix
        task.dueDate             = addToCalendar ? dueDate : nil
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
