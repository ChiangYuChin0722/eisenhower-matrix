import SwiftUI

struct QuadrantSectionView: View {
    @EnvironmentObject var taskStore: TaskStore
    let quadrant: Quadrant
    @Binding var editingTask: EisTask?
    @Binding var showingAddTask: Bool
    @Binding var addTaskQuadrant: Quadrant

    var tasks: [EisTask] { taskStore.tasks(for: quadrant) }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 4) {
                Text(quadrant.emoji)
                    .font(.caption)
                Text(quadrant.title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(quadrant.color)
                Spacer()
                Text("\(tasks.filter { !$0.isCompleted }.count)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Button {
                    addTaskQuadrant = quadrant
                    showingAddTask = true
                } label: {
                    Image(systemName: "plus")
                        .font(.caption)
                        .foregroundColor(quadrant.color)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(quadrant.color.opacity(0.08))

            // Task list
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(tasks) { task in
                        TaskRowView(task: task, onEdit: { editingTask = $0 })
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(Color(uiColor: .systemBackground))

                        Divider()
                            .padding(.leading, task.colorTag != .none ? 20 : 8)
                    }

                    if tasks.isEmpty {
                        VStack(spacing: 8) {
                            Text(quadrant.emoji)
                                .font(.title2)
                            Text("No tasks")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                    }
                }
            }
        }
        .background(Color(uiColor: .systemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(quadrant.color.opacity(0.2), lineWidth: 1)
        )
    }
}
