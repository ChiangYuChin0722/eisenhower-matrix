import SwiftUI

struct MatrixView: View {
    @EnvironmentObject var taskStore: TaskStore

    @State private var showAddTask   = false
    @State private var editingTask: EisTask? = nil
    @State private var addCanvasX    = 0.75
    @State private var addCanvasY    = 0.25
    @State private var addQuadrant   = Quadrant.doFirst
    @State private var showingSettings = false
    @State private var canvasSize    = CGSize.zero

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                axisHeader
                    .padding(.horizontal, 8)
                    .padding(.top, 4)

                GeometryReader { geo in
                    ZStack(alignment: .topLeading) {
                        // Quadrant backgrounds
                        quadrantBackgrounds(size: geo.size)

                        // Divider lines
                        dividers(size: geo.size)

                        // Quadrant corner labels
                        cornerLabels(size: geo.size)

                        // Task dots (drag gesture on each dot)
                        ForEach(taskStore.tasks) { task in
                            TaskDotView(task: task, canvasSize: geo.size)
                        }
                    }
                    // Single spatial tap gesture handles both "edit dot" and "add task"
                    .gesture(
                        SpatialTapGesture()
                            .onEnded { val in
                                handleTap(at: val.location, size: geo.size)
                            }
                    )
                    .onAppear { canvasSize = geo.size }
                    .onChange(of: geo.size) { canvasSize = $0 }
                }

                axisBottom
                    .padding(.horizontal, 8)
                    .padding(.bottom, 4)
            }
            .background(Color(uiColor: .systemBackground))
            .navigationTitle("Eisenhower Matrix")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { showingSettings = true } label: {
                        Image(systemName: "gearshape")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        let pos = Quadrant.randomPosition(for: .doFirst)
                        addCanvasX  = pos.x
                        addCanvasY  = pos.y
                        addQuadrant = .doFirst
                        showAddTask = true
                    } label: {
                        Image(systemName: "plus")
                            .fontWeight(.semibold)
                    }
                }
            }
            .sheet(isPresented: $showAddTask) {
                AddTaskView(
                    defaultQuadrant: addQuadrant,
                    initialCanvasX: addCanvasX,
                    initialCanvasY: addCanvasY
                )
            }
            .sheet(item: $editingTask) { task in
                AddTaskView(editingTask: task)
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
        }
    }

    // MARK: - Tap handler

    private func handleTap(at location: CGPoint, size: CGSize) {
        let tapX = Double(location.x / size.width)
        let tapY = Double(location.y / size.height)

        // If near an existing dot → edit
        if let hit = taskStore.tasks.first(where: { task in
            let dx = location.x - CGFloat(task.canvasX) * size.width
            let dy = location.y - CGFloat(task.canvasY) * size.height
            return hypot(dx, dy) < 18
        }) {
            editingTask = hit
            return
        }

        // Otherwise → add new task at that position
        addCanvasX  = tapX
        addCanvasY  = tapY
        addQuadrant = Quadrant.from(canvasX: tapX, canvasY: tapY)
        showAddTask = true
    }

    // MARK: - Backgrounds

    private func quadrantBackgrounds(size: CGSize) -> some View {
        let w = size.width / 2
        let h = size.height / 2
        return Group {
            // Schedule — top-left (blue)
            Rectangle().fill(Quadrant.schedule.bgColor)
                .frame(width: w, height: h)
                .offset(x: 0, y: 0)
            // Do Now — top-right (red)
            Rectangle().fill(Quadrant.doFirst.bgColor)
                .frame(width: w, height: h)
                .offset(x: w, y: 0)
            // Eliminate — bottom-left (gray)
            Rectangle().fill(Quadrant.eliminate.bgColor)
                .frame(width: w, height: h)
                .offset(x: 0, y: h)
            // Delegate — bottom-right (orange)
            Rectangle().fill(Quadrant.delegate.bgColor)
                .frame(width: w, height: h)
                .offset(x: w, y: h)
        }
    }

    // MARK: - Dividers

    private func dividers(size: CGSize) -> some View {
        Group {
            // Horizontal
            Rectangle()
                .fill(Color.gray.opacity(0.18))
                .frame(width: size.width, height: 1)
                .offset(x: 0, y: size.height / 2)
            // Vertical
            Rectangle()
                .fill(Color.gray.opacity(0.18))
                .frame(width: 1, height: size.height)
                .offset(x: size.width / 2, y: 0)
        }
    }

    // MARK: - Corner labels

    private func cornerLabels(size: CGSize) -> some View {
        let pad: CGFloat = 10
        let h = size.height / 2
        let w = size.width / 2
        return Group {
            // Schedule top-left
            quadrantLabel(.schedule, x: pad, y: pad)

            // Do Now top-right — with "tap to add" hint
            HStack(spacing: 4) {
                Text(Quadrant.doFirst.title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Quadrant.doFirst.color)
                Circle()
                    .fill(Quadrant.doFirst.color)
                    .frame(width: 6, height: 6)
            }
            .offset(x: w + pad, y: pad)

            // Eliminate bottom-left
            quadrantLabel(.eliminate, x: pad, y: h + pad)

            // Delegate bottom-right
            quadrantLabel(.delegate, x: w + pad, y: h + pad)

            // "tap anywhere to add" hint — centered, very subtle
            Text("tap anywhere to add")
                .font(.system(size: 10))
                .foregroundColor(.secondary.opacity(0.5))
                .offset(x: w - 55, y: h - 10)
        }
    }

    private func quadrantLabel(_ q: Quadrant, x: CGFloat, y: CGFloat) -> some View {
        Text(q.title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(q.color)
            .offset(x: x, y: y)
    }

    // MARK: - Axis labels

    private var axisHeader: some View {
        HStack {
            Spacer()
            Text("← Not Urgent")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
            Spacer()
            Text("Urgent →")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
            Spacer()
        }
    }

    private var axisBottom: some View {
        HStack {
            Text("Important ↑")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
            Spacer()
            Text("↓ Not Important")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    MatrixView()
        .environmentObject(TaskStore())
}
