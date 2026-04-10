import SwiftUI

struct CalendarView: View {
    @EnvironmentObject var taskStore: TaskStore
    @State private var displayedMonth: Date = Date()
    @State private var selectedDate: Date = Date()
    @State private var showingAddTask = false
    @State private var editingTask: EisTask? = nil

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible()), count: 7)
    private let weekdays = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                monthHeader
                weekdayLabels
                monthGrid
                    .padding(.bottom, 8)
                Divider()
                dayTaskList
            }
            .navigationTitle("Calendar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Today") {
                        displayedMonth = Date()
                        selectedDate = Date()
                    }
                    .font(.subheadline)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddTask = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddTask) {
                AddTaskView(defaultQuadrant: .doFirst)
            }
            .sheet(item: $editingTask) { task in
                AddTaskView(editingTask: task)
            }
        }
    }

    // MARK: - Month header

    private var monthHeader: some View {
        HStack {
            Button { changeMonth(-1) } label: {
                Image(systemName: "chevron.left")
                    .frame(width: 36, height: 36)
            }
            Spacer()
            Text(monthTitle)
                .font(.headline)
            Spacer()
            Button { changeMonth(1) } label: {
                Image(systemName: "chevron.right")
                    .frame(width: 36, height: 36)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private var monthTitle: String {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f.string(from: displayedMonth)
    }

    // MARK: - Weekday labels

    private var weekdayLabels: some View {
        LazyVGrid(columns: columns) {
            ForEach(weekdays, id: \.self) { day in
                Text(day)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 8)
    }

    // MARK: - Month grid

    private var monthGrid: some View {
        LazyVGrid(columns: columns, spacing: 4) {
            ForEach(daysInMonth, id: \.self) { date in
                if let date {
                    dayCell(date)
                } else {
                    Color.clear
                        .frame(height: 44)
                }
            }
        }
        .padding(.horizontal, 8)
    }

    private func dayCell(_ date: Date) -> some View {
        let isToday    = calendar.isDateInToday(date)
        let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
        let dayTasks   = taskStore.tasks(for: date)

        return VStack(spacing: 2) {
            ZStack {
                Circle()
                    .fill(isSelected ? Color.blue : (isToday ? Color.blue.opacity(0.12) : Color.clear))
                    .frame(width: 30, height: 30)
                Text("\(calendar.component(.day, from: date))")
                    .font(.system(size: 14, weight: isToday ? .bold : .regular))
                    .foregroundColor(isSelected ? .white : (isToday ? .blue : .primary))
            }

            // Task dots
            if !dayTasks.isEmpty {
                HStack(spacing: 2) {
                    ForEach(Array(Set(dayTasks.map { $0.quadrant })), id: \.self) { q in
                        Circle()
                            .fill(q.color)
                            .frame(width: 4, height: 4)
                    }
                }
            } else {
                Color.clear.frame(height: 4)
            }
        }
        .frame(height: 44)
        .onTapGesture { selectedDate = date }
    }

    // MARK: - Day task list

    private var dayTaskList: some View {
        VStack(alignment: .leading, spacing: 0) {
            let tasks = taskStore.tasks(for: selectedDate)

            HStack {
                Text(selectedDate, style: .date)
                    .font(.subheadline).fontWeight(.semibold)
                Spacer()
                Text("\(tasks.count) task\(tasks.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            .padding(.vertical, 10)

            if tasks.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "calendar.badge.plus")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("No tasks for this day")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Button("Add task") { showingAddTask = true }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 20)
            } else {
                List(tasks) { task in
                    HStack(spacing: 10) {
                        Circle()
                            .fill(task.quadrant.color)
                            .frame(width: 8, height: 8)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(task.title)
                                .font(.subheadline)
                                .strikethrough(task.isCompleted)
                                .foregroundColor(task.isCompleted ? .secondary : .primary)
                            if let due = task.dueDate {
                                Text(due, style: .time)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        Spacer()
                        Text(task.quadrant.title)
                            .font(.caption2)
                            .foregroundColor(task.quadrant.color)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { editingTask = task }
                }
                .listStyle(.plain)
            }
        }
    }

    // MARK: - Helpers

    private var daysInMonth: [Date?] {
        guard let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: displayedMonth)),
              let range = calendar.range(of: .day, in: .month, for: monthStart)
        else { return [] }

        let firstWeekday = calendar.component(.weekday, from: monthStart) - 1
        var days: [Date?] = Array(repeating: nil, count: firstWeekday)

        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: monthStart) {
                days.append(date)
            }
        }
        return days
    }

    private func changeMonth(_ delta: Int) {
        if let newMonth = calendar.date(byAdding: .month, value: delta, to: displayedMonth) {
            displayedMonth = newMonth
        }
    }
}

#Preview {
    CalendarView()
        .environmentObject(TaskStore())
}
