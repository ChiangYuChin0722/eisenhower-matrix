import SwiftUI

struct TaskDotView: View {
    @EnvironmentObject var taskStore: TaskStore
    @AppStorage("matrixTheme") private var matrixTheme: String = "classic"
    @AppStorage("appLanguage") private var lang: String = "en"
    let task: EisTask
    let canvasSize: CGSize
    var onEdit: () -> Void = {}

    @GestureState private var dragOffset: CGSize = .zero
    private func qColor(_ q: Quadrant) -> Color { q.color(theme: matrixTheme) }

    private var dotX: CGFloat { CGFloat(task.canvasX) * canvasSize.width }
    private var dotY: CGFloat { CGFloat(task.canvasY) * canvasSize.height }
    private var isDragging: Bool { dragOffset != .zero }

    /// Flip label to the left when the dot is in the right 30% of the canvas,
    /// so it never overflows the screen edge.
    private var showLabelOnLeft: Bool { dotX > canvasSize.width * 0.70 }

    var body: some View {
        Circle()
            .fill(task.isCompleted
                  ? Color.secondary.opacity(0.4)
                  : qColor(task.quadrant))
            .frame(width: 14, height: 14)
            .shadow(
                color: qColor(task.quadrant).opacity(isDragging ? 0.5 : 0.25),
                radius: isDragging ? 10 : 4,
                y: isDragging ? 4 : 1
            )
            .scaleEffect(isDragging ? 1.4 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isDragging)
            // Label is an overlay so its width never affects the dot's offset math.
            // Align to .trailing when left-side so the label's right edge anchors near
            // the dot; align to .leading when right-side so its left edge anchors there.
            .overlay(alignment: showLabelOnLeft ? .trailing : .leading) {
                if !isDragging {
                    Text(task.title)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .fixedSize()
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color(uiColor: .systemBackground).opacity(0.92))
                                .shadow(color: .black.opacity(0.08), radius: 3, y: 1)
                        )
                        // Shift away from the dot: 14 (diameter) + 5 (gap) = 19pt each side
                        // overlay alignment is .leading/.trailing so offset starts at circle edge,
                        // not center — must use full diameter to clear the circle completely.
                        .offset(x: showLabelOnLeft ? -(14 + 5) : (14 + 5))
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }
            }
            // Keep dot circle centered at (dotX, dotY)
            .offset(
                x: dotX - 7 + dragOffset.width,
                y: dotY - 7 + dragOffset.height
            )
            .zIndex(isDragging ? 999 : 1)
            .contextMenu {
                Button {
                    taskStore.toggleCompletion(id: task.id)
                } label: {
                    Label(
                        task.isCompleted
                            ? (lang == "zh" ? "標記為未完成" : "Mark Incomplete")
                            : (lang == "zh" ? "標記為完成" : "Mark Complete"),
                        systemImage: task.isCompleted ? "circle" : "checkmark.circle"
                    )
                }
                Button {
                    onEdit()
                } label: {
                    Label(lang == "zh" ? "編輯任務" : "Edit Task", systemImage: "pencil")
                }
                Divider()
                Button(role: .destructive) {
                    taskStore.deleteTask(id: task.id)
                } label: {
                    Label(lang == "zh" ? "刪除任務" : "Delete Task", systemImage: "trash")
                }
            }
            .gesture(
                DragGesture(minimumDistance: 4)
                    .updating($dragOffset) { value, state, _ in
                        if state == .zero { HapticManager.shared.selection() }
                        state = value.translation
                    }
                    .onEnded { value in
                        let newX = (Double(dotX + value.translation.width) / Double(canvasSize.width))
                            .clamped(to: 0.02...0.98)
                        let newY = (Double(dotY + value.translation.height) / Double(canvasSize.height))
                            .clamped(to: 0.02...0.98)
                        var updated = task
                        updated.canvasX = newX
                        updated.canvasY = newY
                        let newQuadrant = Quadrant.from(canvasX: newX, canvasY: newY)
                        updated.quadrant = newQuadrant
                        taskStore.updateTask(updated)
                        if newQuadrant != task.quadrant {
                            HapticManager.shared.impact(.medium)
                        } else {
                            HapticManager.shared.impact(.light)
                        }
                    }
            )
    }
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        Swift.max(range.lowerBound, Swift.min(range.upperBound, self))
    }
}
