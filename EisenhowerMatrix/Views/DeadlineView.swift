import SwiftUI

struct DeadlineView: View {
    @EnvironmentObject var taskStore: TaskStore
    @AppStorage("appLanguage") private var lang: String = "en"
    @AppStorage("appAccent")   private var appAccent: String = "blue"
    @AppStorage("matrixTheme") private var matrixTheme: String = "classic"
    private func qColor(_ q: Quadrant) -> Color { q.color(theme: matrixTheme) }
    private func qBg(_ q: Quadrant)    -> Color { q.bgColor(theme: matrixTheme) }
    @State private var editingTask: EisTask? = nil
    @State private var showAddTask   = false
    @State private var showCompleted = false

    private let cal = Calendar.current
    private var s: Str { Str(lang) }
    private var accent: Color { .accent(appAccent) }

    private var nextFourTasks: [EisTask] {
        taskStore.tasksWithDeadlines
            .filter { !$0.isCompleted && ($0.dueDate ?? .distantPast) > Date() }
            .sorted { $0.dueDate! < $1.dueDate! }
            .prefix(4)
            .map { $0 }
    }

    private var allDeadlineTasks: [EisTask] {
        let base = taskStore.tasksWithDeadlines
        return showCompleted ? base : base.filter { !$0.isCompleted }
    }

    private var overdue: [EisTask] {
        allDeadlineTasks.filter { !$0.isCompleted && $0.dueDate! < startOfToday }
    }
    private var today: [EisTask] {
        allDeadlineTasks.filter { cal.isDateInToday($0.dueDate!) }
    }
    private var tomorrow: [EisTask] {
        allDeadlineTasks.filter { cal.isDateInTomorrow($0.dueDate!) }
    }
    private var thisWeek: [EisTask] {
        let end = cal.date(byAdding: .day, value: 7, to: startOfToday)!
        return allDeadlineTasks.filter { d in
            let due = d.dueDate!
            return due > startOfTomorrow && due <= end
        }
    }
    private var later: [EisTask] {
        let end = cal.date(byAdding: .day, value: 7, to: startOfToday)!
        return allDeadlineTasks.filter { $0.dueDate! > end }
    }

    private var startOfToday: Date    { cal.startOfDay(for: Date()) }
    private var startOfTomorrow: Date { cal.date(byAdding: .day, value: 1, to: startOfToday)! }

    var body: some View {
        NavigationView {
            Group {
                if taskStore.tasksWithDeadlines.isEmpty {
                    emptyState
                } else {
                    deadlineList
                }
            }
            .navigationTitle(s.tabDeadlines)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        withAnimation { showCompleted.toggle() }
                    } label: {
                        Label(showCompleted ? s.hideDoneTitle : s.showDoneTitle,
                              systemImage: showCompleted ? "eye.slash" : "eye")
                        .font(.caption)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showAddTask = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddTask) {
                AddTaskView(defaultQuadrant: .doFirst, forceCalendar: true)
            }
            .sheet(item: $editingTask) { task in
                AddTaskView(editingTask: task)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.badge.checkmark")
                .font(.system(size: 56))
                .foregroundColor(.secondary.opacity(0.3))
            Text(s.noDeadlines)
                .font(.title3).fontWeight(.medium)
            Text(s.noDeadlinesSub)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button(s.addWithDeadline) { showAddTask = true }
                .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    private var deadlineList: some View {
        List {
            // MARK: Countdown strip
            if !nextFourTasks.isEmpty {
                Section {
                    TimelineView(.periodic(from: .now, by: 1.0)) { ctx in
                        countdownStrip(at: ctx.date)
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 4, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
            }

            if !overdue.isEmpty {
                deadlineSection(s.overdue, tasks: overdue,   color: .red,      icon: "exclamationmark.circle.fill")
            }
            if !today.isEmpty {
                deadlineSection(s.today,   tasks: today,     color: .orange,   icon: "sun.max.fill")
            }
            if !tomorrow.isEmpty {
                deadlineSection(s.tomorrow,tasks: tomorrow,  color: .yellow,   icon: "sunrise.fill")
            }
            if !thisWeek.isEmpty {
                deadlineSection(s.thisWeek,tasks: thisWeek,  color: .blue,     icon: "calendar.badge.clock")
            }
            if !later.isEmpty {
                deadlineSection(s.later,   tasks: later,     color: .secondary,icon: "calendar")
            }
            if allDeadlineTasks.isEmpty && showCompleted {
                Text(s.allDoneMsg)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
                    .listRowBackground(Color.clear)
            }
        }
        .listStyle(.insetGrouped)
    }

    private func deadlineSection(
        _ title: String, tasks: [EisTask], color: Color, icon: String
    ) -> some View {
        Section {
            ForEach(tasks) { task in
                deadlineRow(task)
                    .swipeActions(edge: .leading) {
                        Button {
                            taskStore.toggleCompletion(id: task.id)
                        } label: {
                            Label(task.isCompleted ? s.undo : s.done,
                                  systemImage: task.isCompleted ? "arrow.uturn.backward" : "checkmark")
                        }
                        .tint(.green)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            taskStore.deleteTask(id: task.id)
                        } label: {
                            Label(s.delete, systemImage: "trash")
                        }
                        Button { editingTask = task } label: {
                            Label(s.edit, systemImage: "pencil")
                        }
                        .tint(.blue)
                    }
            }
        } header: {
            HStack(spacing: 6) {
                Image(systemName: icon).foregroundColor(color)
                Text(title).foregroundColor(color)
                Spacer()
                Text("\(tasks.count)").foregroundColor(.secondary)
            }
            .font(.caption)
        }
    }

    private func deadlineRow(_ task: EisTask) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(task.isCompleted ? Color.secondary.opacity(0.4) : qColor(task.quadrant))
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 3) {
                Text(task.title)
                    .font(.subheadline)
                    .strikethrough(task.isCompleted)
                    .foregroundColor(task.isCompleted ? .secondary : .primary)
                    .lineLimit(1)

                if let due = task.dueDate {
                    HStack(spacing: 4) {
                        Text(deadlineLabel(due))
                            .font(.caption)
                            .foregroundColor(deadlineColor(due, completed: task.isCompleted))
                        if !cal.isDateInToday(due) && !cal.isDateInTomorrow(due) {
                            Text(due, style: .date)
                                .font(.caption).foregroundColor(.secondary)
                        }
                        let timeComps = cal.dateComponents([.hour, .minute], from: due)
                        if (timeComps.hour ?? 0) != 0 || (timeComps.minute ?? 0) != 0 {
                            Text(due, style: .time)
                                .font(.caption).foregroundColor(.secondary)
                        }
                    }
                }
            }

            Spacer()

            Text(s.quadrantTitle(task.quadrant))
                .font(.caption2)
                .foregroundColor(qColor(task.quadrant))
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(task.quadrant.color.opacity(0.1))
                .cornerRadius(4)
        }
        .contentShape(Rectangle())
        .onTapGesture { editingTask = task }
    }

    private func deadlineLabel(_ date: Date) -> String {
        if date < startOfToday && !cal.isDateInToday(date) { return s.overdue }
        if cal.isDateInToday(date)    { return s.today }
        if cal.isDateInTomorrow(date) { return s.tomorrow }
        let days = cal.dateComponents([.day], from: startOfToday, to: date).day ?? 0
        return s.inDays(days)
    }

    private func deadlineColor(_ date: Date, completed: Bool) -> Color {
        if completed { return .secondary }
        if date < startOfToday { return .red }
        if cal.isDateInToday(date) { return .orange }
        return .blue
    }

    // MARK: - Countdown strip

    private func countdownStrip(at now: Date) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(nextFourTasks) { task in
                    if let due = task.dueDate {
                        let remaining = max(0, due.timeIntervalSince(now))
                        compactCountdownCard(task: task, due: due, remaining: remaining)
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func compactCountdownCard(task: EisTask, due: Date, remaining: TimeInterval) -> some View {
        let totalHours = Int(remaining) / 3600
        let minutes    = (Int(remaining) % 3600) / 60
        let seconds    = Int(remaining) % 60
        let urgency: Color = {
            if remaining < 3600      { return .red }
            if remaining < 86400     { return .orange }
            if remaining < 86400 * 3 { return .yellow }
            return accent
        }()

        return VStack(alignment: .leading, spacing: 6) {
            // Task name + quadrant dot
            HStack(spacing: 4) {
                Circle().fill(qColor(task.quadrant)).frame(width: 6, height: 6)
                Text(task.title)
                    .font(.caption).fontWeight(.semibold)
                    .lineLimit(1)
                    .foregroundColor(.primary)
            }

            // HH : MM : SS
            HStack(spacing: 2) {
                miniUnit(String(format: "%02d", totalHours), label: lang == "zh" ? "時" : "h", color: urgency)
                Text(":").font(.system(size: 14, weight: .thin)).foregroundColor(.secondary)
                miniUnit(String(format: "%02d", minutes),   label: lang == "zh" ? "分" : "m", color: urgency)
                Text(":").font(.system(size: 14, weight: .thin)).foregroundColor(.secondary)
                miniUnit(String(format: "%02d", seconds),   label: lang == "zh" ? "秒" : "s", color: urgency)
            }
            .frame(maxWidth: .infinity, alignment: .center)

            // Due date
            let comps = cal.dateComponents([.hour, .minute], from: due)
            let hasTime = (comps.hour ?? 0) != 0 || (comps.minute ?? 0) != 0
            HStack(spacing: 3) {
                Image(systemName: "calendar").font(.system(size: 9))
                Text(due, style: .date).font(.system(size: 10))
                if hasTime {
                    Text(due, style: .time).font(.system(size: 10))
                }
            }
            .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(width: 145)
        .background(urgency.opacity(0.07))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(urgency.opacity(0.2), lineWidth: 1))
        .onTapGesture { editingTask = task }
    }

    private func miniUnit(_ value: String, label: String, color: Color) -> some View {
        VStack(spacing: 1) {
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .monospaced))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
        }
        .frame(minWidth: 32)
    }
}

#Preview {
    DeadlineView().environmentObject(TaskStore())
}
