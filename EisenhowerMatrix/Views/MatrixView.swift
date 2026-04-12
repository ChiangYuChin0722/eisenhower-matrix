import SwiftUI

struct MatrixView: View {
    @EnvironmentObject var taskStore: TaskStore
    @AppStorage("appLanguage") private var lang: String = "en"
    @AppStorage("matrixTheme") private var matrixTheme: String = "classic"
    private func qColor(_ q: Quadrant) -> Color { q.color(theme: matrixTheme) }
    private func qBg(_ q: Quadrant)    -> Color { q.bgColor(theme: matrixTheme) }

    @State private var showAddTask     = false
    @State private var editingTask: EisTask? = nil
    @State private var addCanvasX      = 0.75
    @State private var addCanvasY      = 0.25
    @State private var addQuadrant     = Quadrant.doFirst
    @State private var showingSettings = false
    @State private var showSearch      = false
    @State private var canvasSize      = CGSize.zero

    private var s: Str { Str(lang) }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                axisHeader
                    .padding(.horizontal, 8)
                    .padding(.top, 4)

                GeometryReader { geo in
                    ZStack(alignment: .topLeading) {
                        quadrantBackgrounds(size: geo.size)
                        dividers(size: geo.size)
                        cornerLabels(size: geo.size)

                        ForEach(taskStore.tasks.filter { $0.showInMatrix != false }) { task in
                            TaskDotView(task: task, canvasSize: geo.size)
                        }
                    }
                    .gesture(
                        SpatialTapGesture()
                            .onEnded { val in handleTap(at: val.location, size: geo.size) }
                    )
                    .onAppear { canvasSize = geo.size }
                    .onChange(of: geo.size) { canvasSize = $0 }
                }

                axisBottom
                    .padding(.horizontal, 8)
                    .padding(.bottom, 4)
            }
            .background(Color.appBackground)
            .navigationTitle(s.matrixNavTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { showingSettings = true } label: {
                        Image(systemName: "gearshape")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 2) {
                        Button { showSearch = true } label: {
                            Image(systemName: "magnifyingglass")
                        }
                        Button {
                            let pos = Quadrant.randomPosition(for: .doFirst)
                            addCanvasX  = pos.x
                            addCanvasY  = pos.y
                            addQuadrant = .doFirst
                            showAddTask = true
                        } label: {
                            Image(systemName: "plus").fontWeight(.semibold)
                        }
                    }
                }
            }
            .sheet(isPresented: $showAddTask) {
                AddTaskView(defaultQuadrant: addQuadrant, initialCanvasX: addCanvasX, initialCanvasY: addCanvasY)
            }
            .sheet(item: $editingTask) { task in
                AddTaskView(editingTask: task)
            }
            .navigationDestination(isPresented: $showingSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showSearch) {
                SearchView()
            }
        }
    }

    // MARK: - Tap handler

    private func handleTap(at location: CGPoint, size: CGSize) {
        let tapX = Double(location.x / size.width)
        let tapY = Double(location.y / size.height)

        if let hit = taskStore.tasks.first(where: { task in
            let dx = location.x - CGFloat(task.canvasX) * size.width
            let dy = location.y - CGFloat(task.canvasY) * size.height
            return hypot(dx, dy) < 18
        }) {
            editingTask = hit
            return
        }

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
            // Each quadrant's gradient radiates from its outer corner toward the centre
            Rectangle()
                .fill(Quadrant.schedule.bgGradient(theme: matrixTheme, corner: .topLeading))
                .frame(width: w, height: h).offset(x: 0, y: 0)
            Rectangle()
                .fill(Quadrant.doFirst.bgGradient(theme: matrixTheme, corner: .topTrailing))
                .frame(width: w, height: h).offset(x: w, y: 0)
            Rectangle()
                .fill(Quadrant.eliminate.bgGradient(theme: matrixTheme, corner: .bottomLeading))
                .frame(width: w, height: h).offset(x: 0, y: h)
            Rectangle()
                .fill(Quadrant.delegate.bgGradient(theme: matrixTheme, corner: .bottomTrailing))
                .frame(width: w, height: h).offset(x: w, y: h)
        }
    }

    // MARK: - Dividers

    private func dividers(size: CGSize) -> some View {
        Group {
            Rectangle()
                .fill(Color.gray.opacity(0.18))
                .frame(width: size.width, height: 1)
                .offset(x: 0, y: size.height / 2)
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
            quadrantLabel(.schedule, x: pad, y: pad)

            HStack(spacing: 4) {
                Text(s.quadrantTitle(.doFirst))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(qColor(.doFirst))
                Circle()
                    .fill(qColor(.doFirst))
                    .frame(width: 6, height: 6)
            }
            .offset(x: w + pad, y: pad)

            quadrantLabel(.eliminate, x: pad, y: h + pad)
            quadrantLabel(.delegate, x: w + pad, y: h + pad)

            Text(s.tapToAdd)
                .font(.system(size: 10))
                .foregroundColor(.secondary.opacity(0.5))
                .offset(x: w - 55, y: h - 10)
        }
    }

    private func quadrantLabel(_ q: Quadrant, x: CGFloat, y: CGFloat) -> some View {
        Text(s.quadrantTitle(q))
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(qColor(q))
            .offset(x: x, y: y)
    }

    // MARK: - Axis labels

    private var axisHeader: some View {
        HStack {
            Spacer()
            Text(s.notUrgentLabel).font(.system(size: 10)).foregroundColor(.secondary)
            Spacer()
            Text(s.urgentLabel).font(.system(size: 10)).foregroundColor(.secondary)
            Spacer()
        }
    }

    private var axisBottom: some View {
        HStack {
            Text(s.importantLabel).font(.system(size: 10)).foregroundColor(.secondary)
            Spacer()
            Text(s.notImportantLabel).font(.system(size: 10)).foregroundColor(.secondary)
        }
    }
}

#Preview {
    MatrixView().environmentObject(TaskStore())
}
