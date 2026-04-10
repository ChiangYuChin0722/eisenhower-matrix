import SwiftUI

struct TaskDotView: View {
    @EnvironmentObject var taskStore: TaskStore
    @AppStorage("matrixTheme") private var matrixTheme: String = "classic"
    let task: EisTask
    let canvasSize: CGSize

    @GestureState private var dragOffset: CGSize = .zero
    private func qColor(_ q: Quadrant) -> Color { q.color(theme: matrixTheme) }

    private var dotX: CGFloat { CGFloat(task.canvasX) * canvasSize.width }
    private var dotY: CGFloat { CGFloat(task.canvasY) * canvasSize.height }
    private var isDragging: Bool { dragOffset != .zero }

    var body: some View {
        HStack(spacing: 5) {
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
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
        }
        .fixedSize()
        // Place top-left of HStack so the circle CENTER lands at (dotX, dotY)
        .offset(
            x: dotX - 7 + dragOffset.width,
            y: dotY - 7 + dragOffset.height
        )
        .zIndex(isDragging ? 999 : 1)
        .gesture(
            DragGesture(minimumDistance: 4)
                .updating($dragOffset) { value, state, _ in
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
                    updated.quadrant = Quadrant.from(canvasX: newX, canvasY: newY)
                    taskStore.updateTask(updated)
                }
        )
    }
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        Swift.max(range.lowerBound, Swift.min(range.upperBound, self))
    }
}
