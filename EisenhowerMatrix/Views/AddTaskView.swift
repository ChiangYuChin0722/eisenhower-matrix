import SwiftUI

struct AddTaskView: View {
    @EnvironmentObject var taskStore: TaskStore
    @Environment(\.dismiss) var dismiss

    var editingTask: EisTask? = nil
    var defaultQuadrant: Quadrant = .doFirst

    @State private var title: String = ""
    @State private var notes: String = ""
    @State private var quadrant: Quadrant = .doFirst
    @State private var hasDueDate: Bool = false
    @State private var dueDate: Date = Date()
    @State private var colorTag: TaskColor = .none
    @State private var subtaskTitle: String = ""
    @State private var subtasks: [EisTask] = []

    var isEditing: Bool { editingTask != nil }

    var body: some View {
        NavigationView {
            Form {
                Section("Task") {
                    TextField("Title", text: $title)
                    TextField("Notes (optional)", text: $notes, axis: .vertical)
                        .lineLimit(3, reservesSpace: false)
                }

                Section("Quadrant") {
                    Picker("Quadrant", selection: $quadrant) {
                        ForEach(Quadrant.allCases) { q in
                            Label {
                                VStack(alignment: .leading) {
                                    Text(q.title)
                                        .font(.headline)
                                    Text(q.subtitle)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            } icon: {
                                Text(q.emoji)
                            }
                            .tag(q)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }

                Section("Due Date") {
                    Toggle("Set due date", isOn: $hasDueDate)
                    if hasDueDate {
                        DatePicker("Date", selection: $dueDate, displayedComponents: [.date, .hourAndMinute])
                    }
                }

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

                Section("Subtasks") {
                    ForEach(subtasks) { sub in
                        HStack {
                            Image(systemName: sub.isCompleted ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(sub.isCompleted ? .green : .secondary)
                            Text(sub.title)
                                .strikethrough(sub.isCompleted)
                        }
                    }
                    .onDelete { subtasks.remove(atOffsets: $0) }

                    HStack {
                        TextField("Add subtask…", text: $subtaskTitle)
                        Button("Add") {
                            let s = EisTask(title: subtaskTitle, quadrant: quadrant)
                            subtasks.append(s)
                            subtaskTitle = ""
                        }
                        .disabled(subtaskTitle.trimmingCharacters(in: .whitespaces).isEmpty)
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
                    Button(isEditing ? "Save" : "Add") { save() }
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                        .fontWeight(.semibold)
                }
            }
            .onAppear { populateIfEditing() }
        }
    }

    // MARK: - Color circle

    @ViewBuilder
    private func colorCircle(_ c: TaskColor) -> some View {
        ZStack {
            Circle()
                .fill(c == .none ? Color.gray.opacity(0.2) : c.color)
                .frame(width: 30, height: 30)
            if c == .none {
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            if colorTag == c {
                Circle()
                    .stroke(Color.primary, lineWidth: 2)
                    .frame(width: 34, height: 34)
            }
        }
        .onTapGesture { colorTag = c }
    }

    // MARK: - Helpers

    private func populateIfEditing() {
        guard let t = editingTask else {
            quadrant = defaultQuadrant
            return
        }
        title    = t.title
        notes    = t.notes
        quadrant = t.quadrant
        colorTag = t.colorTag
        subtasks = t.subtasks
        if let d = t.dueDate {
            hasDueDate = true
            dueDate = d
        }
    }

    private func save() {
        var task = editingTask ?? EisTask(title: title, quadrant: quadrant)
        task.title    = title.trimmingCharacters(in: .whitespaces)
        task.notes    = notes
        task.quadrant = quadrant
        task.dueDate  = hasDueDate ? dueDate : nil
        task.colorTag = colorTag
        task.subtasks = subtasks

        if isEditing { taskStore.updateTask(task) }
        else         { taskStore.addTask(task) }
        dismiss()
    }
}

#Preview {
    AddTaskView()
        .environmentObject(TaskStore())
}
