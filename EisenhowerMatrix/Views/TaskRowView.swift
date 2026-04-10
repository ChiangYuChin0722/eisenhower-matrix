import SwiftUI

struct TaskRowView: View {
    @EnvironmentObject var taskStore: TaskStore
    let task: EisTask
    var onEdit: ((EisTask) -> Void)? = nil

    var body: some View {
        HStack(spacing: 10) {
            // Color tag indicator
            if task.colorTag != .none {
                VStack(spacing: 2) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(task.colorTag.color)
                        .frame(width: 4, height: task.colorTagLabel.isEmpty ? 32 : 22)
                    if !task.colorTagLabel.isEmpty {
                        Text(task.colorTagLabel)
                            .font(.system(size: 7, weight: .semibold))
                            .foregroundColor(task.colorTag.color)
                            .lineLimit(1)
                            .frame(width: 28)
                    }
                }
            }

            // Completion checkbox
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

            // Title
            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(.system(size: 14))
                    .foregroundColor(task.isCompleted ? .secondary : .primary)
                    .strikethrough(task.isCompleted)
                    .lineLimit(1)

                if !task.subtasks.isEmpty {
                    Text("\(task.completedSubtaskCount)/\(task.totalSubtaskCount) subtasks")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Due date badge
            if let due = task.dueDate {
                Text(dueDateLabel(due))
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(dueDateColor(due).opacity(0.12))
                    .foregroundColor(dueDateColor(due))
                    .cornerRadius(4)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { onEdit?(task) }
    }

    private func dueDateLabel(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date)     { return "Today" }
        if cal.isDateInTomorrow(date)  { return "Tomorrow" }
        if cal.isDateInYesterday(date) { return "Overdue" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd"
        return formatter.string(from: date)
    }

    private func dueDateColor(_ date: Date) -> Color {
        let cal = Calendar.current
        if cal.isDateInYesterday(date) || date < Date() { return .red }
        if cal.isDateInToday(date) { return .orange }
        return .secondary
    }
}
