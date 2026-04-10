import SwiftUI

struct MatrixView: View {
    @EnvironmentObject var taskStore: TaskStore
    @State private var showingAddTask = false
    @State private var addTaskQuadrant: Quadrant = .doFirst
    @State private var editingTask: EisTask? = nil
    @State private var showingSettings = false

    var body: some View {
        NavigationView {
            GeometryReader { geo in
                VStack(spacing: 0) {
                    // Column headers
                    HStack(spacing: 4) {
                        Spacer().frame(width: 20)
                        headerLabel("Urgent", color: .red)
                        headerLabel("Not Urgent", color: .blue)
                    }
                    .padding(.horizontal, 8)
                    .padding(.top, 6)

                    HStack(alignment: .top, spacing: 4) {
                        // Row labels
                        VStack(spacing: 4) {
                            rotatedLabel("Important", color: .primary)
                            rotatedLabel("Not Important", color: .secondary)
                        }
                        .frame(width: 20)

                        // Grid
                        let cellW = (geo.size.width - 40) / 2
                        let cellH = (geo.size.height - 60) / 2

                        VStack(spacing: 4) {
                            HStack(spacing: 4) {
                                QuadrantSectionView(
                                    quadrant: .doFirst,
                                    editingTask: $editingTask,
                                    showingAddTask: $showingAddTask,
                                    addTaskQuadrant: $addTaskQuadrant
                                )
                                .frame(width: cellW, height: cellH)

                                QuadrantSectionView(
                                    quadrant: .schedule,
                                    editingTask: $editingTask,
                                    showingAddTask: $showingAddTask,
                                    addTaskQuadrant: $addTaskQuadrant
                                )
                                .frame(width: cellW, height: cellH)
                            }

                            HStack(spacing: 4) {
                                QuadrantSectionView(
                                    quadrant: .delegate,
                                    editingTask: $editingTask,
                                    showingAddTask: $showingAddTask,
                                    addTaskQuadrant: $addTaskQuadrant
                                )
                                .frame(width: cellW, height: cellH)

                                QuadrantSectionView(
                                    quadrant: .eliminate,
                                    editingTask: $editingTask,
                                    showingAddTask: $showingAddTask,
                                    addTaskQuadrant: $addTaskQuadrant
                                )
                                .frame(width: cellW, height: cellH)
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 8)
                }
            }
            .navigationTitle("Matrix")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { showingSettings = true } label: {
                        Image(systemName: "gearshape")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        addTaskQuadrant = .doFirst
                        showingAddTask = true
                    } label: {
                        Image(systemName: "plus")
                            .fontWeight(.semibold)
                    }
                }
            }
            .sheet(isPresented: $showingAddTask) {
                AddTaskView(defaultQuadrant: addTaskQuadrant)
            }
            .sheet(item: $editingTask) { task in
                AddTaskView(editingTask: task)
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
        }
    }

    private func headerLabel(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(color)
            .frame(maxWidth: .infinity)
    }

    private func rotatedLabel(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .medium))
            .foregroundColor(color)
            .rotationEffect(.degrees(-90))
            .frame(maxHeight: .infinity)
            .fixedSize()
    }
}

#Preview {
    MatrixView()
        .environmentObject(TaskStore())
}
