import SwiftUI

struct CalendarView: View {
    @EnvironmentObject var taskStore: TaskStore
    @AppStorage("appLanguage") private var lang: String = "en"
    @AppStorage("appAccent")   private var appAccent: String = "blue"
    @AppStorage("matrixTheme") private var matrixTheme: String = "classic"
    private func qColor(_ q: Quadrant) -> Color { q.color(theme: matrixTheme) }
    private func qBg(_ q: Quadrant)    -> Color { q.bgColor(theme: matrixTheme) }
    @State private var selectedDate    = Date()
    @State private var displayedMonth  = Date()
    @State private var viewMode: ViewMode = .month
    @State private var showAddTask     = false
    @State private var editingTask: EisTask? = nil

    enum ViewMode: String, CaseIterable {
        case month = "Month"
        case week  = "Week"
        case day   = "Day"
    }

    private var s: Str { Str(lang) }
    private var accent: Color { .accent(appAccent) }
    private let cal  = Calendar.current
    private let cols = Array(repeating: GridItem(.flexible()), count: 7)
    private var weekdays: [String] {
        lang == "zh"
            ? ["日","一","二","三","四","五","六"]
            : ["Sun","Mon","Tue","Wed","Thu","Fri","Sat"]
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Mode toggle
                Picker("", selection: $viewMode) {
                    Text(s.monthMode).tag(ViewMode.month)
                    Text(s.weekMode).tag(ViewMode.week)
                    Text(s.dayMode).tag(ViewMode.day)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)

                if viewMode == .month {
                    monthView
                } else if viewMode == .week {
                    weekView
                } else {
                    dayTimelineView
                }
            }
            .background(Color.appBackground)
            .navigationTitle(s.tabCalendar)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(s.today) {
                        selectedDate   = Date()
                        displayedMonth = Date()
                    }
                    .font(.subheadline)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showAddTask = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddTask) {
                AddTaskView(defaultQuadrant: .doFirst)
            }
            .sheet(item: $editingTask) { task in
                AddTaskView(editingTask: task)
            }
        }
    }

    // MARK: - Month View

    private var monthView: some View {
        VStack(spacing: 0) {
            monthNavHeader
            weekdayRow
            monthGrid
                .padding(.horizontal, 6)
                .padding(.bottom, 8)

            Divider()

            // Day task list — FIXED: use ScrollView not List
            dayTaskSection
        }
    }

    private var monthNavHeader: some View {
        HStack {
            Button { changeMonth(-1) } label: {
                Image(systemName: "chevron.left").frame(width: 36, height: 36)
            }
            Spacer()
            Text(monthTitle).font(.headline)
            Spacer()
            Button { changeMonth(1) } label: {
                Image(systemName: "chevron.right").frame(width: 36, height: 36)
            }
        }
        .padding(.horizontal, 8)
    }

    private var weekdayRow: some View {
        LazyVGrid(columns: cols) {
            ForEach(weekdays, id: \.self) { d in
                Text(d)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 6)
    }

    private var monthGrid: some View {
        LazyVGrid(columns: cols, spacing: 2) {
            ForEach(daysInMonth.indices, id: \.self) { idx in
                if let date = daysInMonth[idx] {
                    dayCell(date)
                } else {
                    Color.clear.frame(height: 44)
                }
            }
        }
    }

    private func dayCell(_ date: Date) -> some View {
        let isToday    = cal.isDateInToday(date)
        let isSelected = cal.isDate(date, inSameDayAs: selectedDate)
        let dots       = Array(Set(taskStore.tasks(for: date).map { $0.quadrant }))

        return Button { selectedDate = date } label: {
            VStack(spacing: 2) {
                ZStack {
                    Circle()
                        .fill(isSelected ? accent : (isToday ? accent.opacity(0.12) : .clear))
                        .frame(width: 30, height: 30)
                    Text("\(cal.component(.day, from: date))")
                        .font(.system(size: 14, weight: isToday ? .bold : .regular))
                        .foregroundColor(isSelected ? .white : (isToday ? accent : .primary))
                }
                HStack(spacing: 2) {
                    ForEach(dots, id: \.self) { q in
                        Circle().fill(qColor(q)).frame(width: 4, height: 4)
                    }
                }
                .frame(height: 4)
            }
            .frame(height: 44)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Day task section (fixed layout — no List inside VStack)

    private var dayTaskSection: some View {
        let tasks = taskStore.tasks(for: selectedDate)
        return VStack(spacing: 0) {
            // Header — always fixed height
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(selectedDate, style: .date)
                        .font(.subheadline).fontWeight(.semibold)
                    Text(s.taskCount(tasks.count))
                        .font(.caption).foregroundColor(.secondary)
                }
                Spacer()
                Button {
                    viewMode = .day
                } label: {
                    Label(s.timeline, systemImage: "clock")
                        .font(.caption).foregroundColor(accent)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)

            // Body — explicit frame for BOTH branches prevents layout jump
            Group {
                if tasks.isEmpty {
                    emptyDayState
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(tasks) { task in
                                dayTaskRow(task)
                                Divider().padding(.leading, 42)
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.appBackground)
        }
    }

    private var emptyDayState: some View {
        VStack(spacing: 14) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 44))
                .foregroundColor(.secondary.opacity(0.35))
            Text(s.noTasksForDay)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Button(s.addTask) { showAddTask = true }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func dayTaskRow(_ task: EisTask) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(task.isCompleted ? Color.secondary.opacity(0.4) : qColor(task.quadrant))
                .frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(.subheadline)
                    .strikethrough(task.isCompleted)
                    .foregroundColor(task.isCompleted ? .secondary : .primary)
                if let due = task.dueDate, (cal.component(.hour, from: due) != 0 || cal.component(.minute, from: due) != 0) {
                    Text(due, style: .time)
                        .font(.caption).foregroundColor(.secondary)
                }
            }
            Spacer()
            Text(task.quadrant.title)
                .font(.caption2).foregroundColor(qColor(task.quadrant))
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(qColor(task.quadrant).opacity(0.1))
                .cornerRadius(4)
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(Color(uiColor: .systemBackground))
        .contentShape(Rectangle())
        .onTapGesture { editingTask = task }
    }

    // MARK: - Week View

    private var weekView: some View {
        VStack(spacing: 0) {
            weekNavHeader
            weekStrip
                .padding(.horizontal, 6)
                .padding(.bottom, 8)
            Divider()
            dayTaskSection
        }
    }

    private var weekNavHeader: some View {
        HStack {
            Button { moveWeek(-1) } label: {
                Image(systemName: "chevron.left").frame(width: 36, height: 36)
            }
            Spacer()
            Text(weekRangeTitle).font(.headline)
            Spacer()
            Button { moveWeek(1) } label: {
                Image(systemName: "chevron.right").frame(width: 36, height: 36)
            }
        }
        .padding(.horizontal, 8)
    }

    private var weekStrip: some View {
        HStack(spacing: 0) {
            ForEach(daysInWeek, id: \.self) { date in
                weekDayCell(date)
            }
        }
    }

    private func weekDayCell(_ date: Date) -> some View {
        let isToday    = cal.isDateInToday(date)
        let isSelected = cal.isDate(date, inSameDayAs: selectedDate)
        let hasTasks   = !taskStore.tasks(for: date).isEmpty

        return Button { selectedDate = date } label: {
            VStack(spacing: 4) {
                Text(weekdayAbbr(date))
                    .font(.system(size: 11))
                    .foregroundColor(isSelected ? accent : .secondary)
                ZStack {
                    Circle()
                        .fill(isSelected ? accent : (isToday ? accent.opacity(0.12) : .clear))
                        .frame(width: 32, height: 32)
                    Text("\(cal.component(.day, from: date))")
                        .font(.system(size: 15, weight: isToday ? .bold : .regular))
                        .foregroundColor(isSelected ? .white : (isToday ? accent : .primary))
                }
                Circle()
                    .fill(hasTasks ? accent : .clear)
                    .frame(width: 4, height: 4)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    private func weekdayAbbr(_ date: Date) -> String {
        let abbrs = weekdays  // reuses the existing weekdays property
        let weekday = cal.component(.weekday, from: date) - 1
        return abbrs[weekday]
    }

    private var daysInWeek: [Date] {
        let weekday = cal.component(.weekday, from: selectedDate)
        guard let start = cal.date(byAdding: .day, value: -(weekday - 1), to: selectedDate) else { return [] }
        return (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: start) }
    }

    private func moveWeek(_ n: Int) {
        if let d = cal.date(byAdding: .day, value: n * 7, to: selectedDate) {
            selectedDate   = d
            displayedMonth = d
        }
    }

    private var weekRangeTitle: String {
        let days = daysInWeek
        guard let first = days.first, let last = days.last else { return "" }
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        let firstStr = f.string(from: first)
        f.dateFormat = "d, yyyy"
        let lastStr = f.string(from: last)
        return "\(firstStr) – \(lastStr)"
    }

    // MARK: - Day Timeline View

    private var dayTimelineView: some View {
        VStack(spacing: 0) {
            // Date navigation bar
            HStack(spacing: 0) {
                Button { moveDay(-1) } label: {
                    Image(systemName: "chevron.left")
                        .frame(width: 44, height: 44)
                }
                Spacer()
                VStack(spacing: 2) {
                    Text(selectedDate, style: .date).font(.headline)
                    Text(s.taskCount(taskStore.tasks(for: selectedDate).count))
                        .font(.caption).foregroundColor(.secondary)
                }
                Spacer()
                Button { moveDay(1) } label: {
                    Image(systemName: "chevron.right")
                        .frame(width: 44, height: 44)
                }
            }
            .padding(.horizontal, 4)
            .background(Color(uiColor: .systemBackground))

            Divider()

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        // All-day tasks
                        let allDay = allDayTasksForSelected
                        if !allDay.isEmpty {
                            allDaySection(allDay)
                        }

                        // Hourly slots 6 AM – 10 PM
                        ForEach(6...22, id: \.self) { hour in
                            timelineHourRow(hour: hour, tasks: timedTasks(hour: hour))
                                .id(hour)
                        }

                        Color.clear.frame(height: 40)
                    }
                }
                .onAppear {
                    let h = min(max(cal.component(.hour, from: Date()), 6), 22)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        proxy.scrollTo(max(h - 1, 6), anchor: .top)
                    }
                }
                .onChange(of: selectedDate) { _ in
                    proxy.scrollTo(6, anchor: .top)
                }
            }
        }
    }

    private func allDaySection(_ tasks: [EisTask]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(s.allDay)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(width: 52, alignment: .trailing)
                Divider().frame(height: 1)
            }
            .padding(.top, 4)

            VStack(spacing: 4) {
                ForEach(tasks) { task in
                    timelineCard(task)
                }
            }
            .padding(.top, 4)
            .padding(.bottom, 8)
        }
        .background(Color.appBackground.opacity(0.5))
    }

    private func timelineHourRow(hour: Int, tasks: [EisTask]) -> some View {
        let isCurrentHour = cal.isDateInToday(selectedDate)
            && cal.component(.hour, from: Date()) == hour

        return HStack(alignment: .top, spacing: 0) {
            // Hour label
            Text(hourLabel(hour))
                .font(.system(size: 11, weight: isCurrentHour ? .bold : .regular))
                .foregroundColor(isCurrentHour ? accent : .secondary)
                .frame(width: 52, alignment: .trailing)
                .padding(.trailing, 8)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 0) {
                Rectangle()
                    .fill(isCurrentHour ? accent.opacity(0.3) : Color.gray.opacity(0.15))
                    .frame(height: 1)

                if tasks.isEmpty {
                    Color.clear.frame(maxWidth: .infinity, minHeight: 44)
                } else {
                    VStack(spacing: 6) {
                        ForEach(tasks) { task in timelineCard(task) }
                    }
                    .padding(.top, 4)
                    .padding(.bottom, 8)
                }
            }
        }
    }

    private func timelineCard(_ task: EisTask) -> some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(qColor(task.quadrant))
                .frame(width: 3)
                .cornerRadius(1.5)

            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(task.title)
                        .font(.subheadline).fontWeight(.medium)
                        .strikethrough(task.isCompleted)
                        .foregroundColor(task.isCompleted ? .secondary : .primary)
                    if let due = task.dueDate {
                        Text(due, style: .time)
                            .font(.caption).foregroundColor(.secondary)
                    }
                }
                Spacer()
                Button {
                    taskStore.toggleCompletion(id: task.id)
                } label: {
                    Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(task.isCompleted ? qColor(task.quadrant) : .secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
        .background(qColor(task.quadrant).opacity(0.06))
        .cornerRadius(8)
        .padding(.trailing, 16)
        .contentShape(Rectangle())
        .onTapGesture { editingTask = task }
    }

    // MARK: - Helpers

    private var allDayTasksForSelected: [EisTask] {
        taskStore.tasks(for: selectedDate).filter { task in
            guard let d = task.dueDate else { return false }
            let comps = cal.dateComponents([.hour, .minute], from: d)
            return (comps.hour ?? 0) == 0 && (comps.minute ?? 0) == 0
        }
    }

    private func timedTasks(hour: Int) -> [EisTask] {
        taskStore.tasks(for: selectedDate).filter { task in
            guard let d = task.dueDate else { return false }
            let h = cal.component(.hour, from: d)
            let m = cal.component(.minute, from: d)
            guard !(h == 0 && m == 0) else { return false }
            return h == hour
        }
    }

    private func hourLabel(_ hour: Int) -> String {
        let h = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)
        return "\(h)\(hour >= 12 ? "pm" : "am")"
    }

    private var monthTitle: String {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f.string(from: displayedMonth)
    }

    private var daysInMonth: [Date?] {
        guard
            let start = cal.date(from: cal.dateComponents([.year, .month], from: displayedMonth)),
            let range = cal.range(of: .day, in: .month, for: start)
        else { return [] }
        let offset = cal.component(.weekday, from: start) - 1
        var result: [Date?] = Array(repeating: nil, count: offset)
        for day in range {
            result.append(cal.date(byAdding: .day, value: day - 1, to: start))
        }
        return result
    }

    private func changeMonth(_ n: Int) {
        if let d = cal.date(byAdding: .month, value: n, to: displayedMonth) {
            displayedMonth = d
        }
    }

    private func moveDay(_ n: Int) {
        if let d = cal.date(byAdding: .day, value: n, to: selectedDate) {
            selectedDate   = d
            displayedMonth = d
        }
    }
}

#Preview {
    CalendarView().environmentObject(TaskStore())
}
