import SwiftUI

struct SearchView: View {
    @EnvironmentObject var taskStore: TaskStore
    @Environment(\.dismiss) var dismiss
    @State private var query        = ""
    @State private var editingTask: EisTask? = nil
    @FocusState private var searchFocused: Bool

    private var results: [EisTask] {
        let trimmed = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !trimmed.isEmpty else { return [] }
        return taskStore.tasks.filter {
            $0.title.lowercased().contains(trimmed) ||
            $0.notes.lowercased().contains(trimmed)
        }
        .sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search bar
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search tasks…", text: $query)
                        .focused($searchFocused)
                        .submitLabel(.search)
                        .autocorrectionDisabled()
                    if !query.isEmpty {
                        Button { query = "" } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(10)
                .background(Color(uiColor: .secondarySystemBackground))
                .cornerRadius(12)
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 8)

                Divider()

                if query.trimmingCharacters(in: .whitespaces).isEmpty {
                    searchHint
                } else if results.isEmpty {
                    noResults
                } else {
                    resultsList
                }
            }
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(item: $editingTask) { task in
                AddTaskView(editingTask: task)
            }
            .onAppear { searchFocused = true }
        }
    }

    // MARK: - States

    private var searchHint: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.3))
            Text("Search by title or notes")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var noResults: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.3))
            Text("No results for \"\(query)\"")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var resultsList: some View {
        List(results) { task in
            searchRow(task)
                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                    Button {
                        taskStore.toggleCompletion(id: task.id)
                    } label: {
                        Label(task.isCompleted ? "Undo" : "Done",
                              systemImage: task.isCompleted ? "arrow.uturn.backward" : "checkmark")
                    }
                    .tint(.green)
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        taskStore.deleteTask(id: task.id)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    Button { editingTask = task } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    .tint(.blue)
                }
        }
        .listStyle(.plain)
    }

    private func searchRow(_ task: EisTask) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(task.isCompleted ? Color.secondary.opacity(0.4) : task.quadrant.color)
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 4) {
                highlightedText(task.title, query: query)
                    .font(.subheadline)
                    .strikethrough(task.isCompleted)
                    .foregroundColor(task.isCompleted ? .secondary : .primary)

                HStack(spacing: 6) {
                    Text(task.quadrant.emoji + " " + task.quadrant.title)
                        .font(.caption2)
                        .foregroundColor(task.quadrant.color)

                    if let due = task.dueDate {
                        Text("·").foregroundColor(.secondary)
                        Text(due, style: .date)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    if !task.notes.isEmpty {
                        Text("·").foregroundColor(.secondary)
                        Text(task.notes)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            if task.colorTag != .none {
                Circle().fill(task.colorTag.color).frame(width: 8, height: 8)
            }
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onTapGesture { editingTask = task }
        .opacity(task.isCompleted ? 0.65 : 1)
    }

    /// Highlights matching characters in the text with blue foreground.
    private func highlightedText(_ text: String, query: String) -> Text {
        let lower   = text.lowercased()
        let qLower  = query.lowercased()
        guard let range = lower.range(of: qLower) else {
            return Text(text)
        }
        let before  = String(text[text.startIndex..<range.lowerBound])
        let match   = String(text[range])
        let after   = String(text[range.upperBound...])
        return Text(before) + Text(match).foregroundColor(.blue).bold() + Text(after)
    }
}

#Preview {
    SearchView().environmentObject(TaskStore())
}
