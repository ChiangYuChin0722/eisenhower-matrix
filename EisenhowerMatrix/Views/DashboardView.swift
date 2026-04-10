import SwiftUI
import Charts

struct DashboardView: View {
    @EnvironmentObject var taskStore: TaskStore
    @AppStorage("appLanguage") private var lang: String = "en"
    @AppStorage("appAccent")   private var appAccent: String = "blue"
    @AppStorage("matrixTheme") private var matrixTheme: String = "classic"
    private func qColor(_ q: Quadrant) -> Color { q.color(theme: matrixTheme) }
    private func qBg(_ q: Quadrant)    -> Color { q.bgColor(theme: matrixTheme) }

    private var s: Str { Str(lang) }
    private var accent: Color { .accent(appAccent) }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 12) {
                    overallCard
                    streakCard
                    completionChart
                    quadrantCards
                    recentActivity
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 16)
            }
            .navigationTitle(s.tabDashboard)
            .navigationBarTitleDisplayMode(.inline)
            .background(Color.appBackground)
        }
    }

    private var overallCard: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(s.overallProgress).font(.headline)
                    Text(s.tasksDone(taskStore.completedCount, taskStore.totalCount))
                        .font(.subheadline).foregroundColor(.secondary)
                }
                Spacer()
                ZStack {
                    Circle().stroke(accent.opacity(0.15), lineWidth: 8)
                    Circle()
                        .trim(from: 0, to: taskStore.completionRate)
                        .stroke(accent, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut, value: taskStore.completionRate)
                    Text("\(Int(taskStore.completionRate * 100))%")
                        .font(.system(size: 14, weight: .bold))
                }
                .frame(width: 60, height: 60)
            }

            HStack(spacing: 12) {
                statBadge(value: taskStore.totalCount,     label: s.totalLabel,     color: .primary)
                statBadge(value: taskStore.pendingCount,   label: s.pendingLabel,   color: .orange)
                statBadge(value: taskStore.completedCount, label: s.completedLabel, color: .green)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(uiColor: .systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
    }

    private var streakCard: some View {
        HStack(spacing: 16) {
            Image(systemName: taskStore.currentStreak > 0 ? "flame.fill" : "flame")
                .font(.system(size: 32))
                .foregroundColor(taskStore.currentStreak > 0 ? .orange : .secondary)

            VStack(alignment: .leading, spacing: 4) {
                Text(s.streak(taskStore.currentStreak)).font(.headline)
                Text(taskStore.currentStreak > 0 ? s.streakKeepUp : s.streakStart)
                    .font(.caption).foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(uiColor: .systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
    }

    private var completionChart: some View {
        let history = taskStore.completionsPerDay(days: 7)
        return VStack(alignment: .leading, spacing: 12) {
            Text(s.lastSevenDays).font(.headline)

            Chart(history, id: \.date) { item in
                BarMark(
                    x: .value("Day", item.date, unit: .day),
                    y: .value(s.completedLabel, item.count)
                )
                .foregroundStyle(accent.gradient)
                .cornerRadius(4)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { _ in
                    AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisValueLabel { if let v = value.as(Int.self) { Text("\(v)") } }
                    AxisGridLine()
                }
            }
            .frame(height: 110)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(uiColor: .systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
    }

    private var quadrantCards: some View {
        VStack(spacing: 12) {
            Text(s.quadrantBreakdown).font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(Quadrant.allCases) { q in quadrantCard(q) }
            }
        }
    }

    private func quadrantCard(_ q: Quadrant) -> some View {
        let tasks = taskStore.tasks(for: q)
        let done  = tasks.filter { $0.isCompleted }.count
        let total = tasks.count
        let rate  = total > 0 ? Double(done) / Double(total) : 0.0

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Circle().fill(qColor(q)).frame(width: 10, height: 10)
                Text(s.quadrantTitle(q))
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundColor(qColor(q))
                Spacer()
            }
            Text(s.quadrantSubtitle(q))
                .font(.caption).foregroundColor(.secondary).lineLimit(1)
            ProgressView(value: rate).tint(qColor(q)).scaleEffect(x: 1, y: 1.5)
            HStack {
                Text("\(done)/\(total)").font(.caption).foregroundColor(.secondary)
                Spacer()
                Text("\(Int(rate * 100))%").font(.caption).fontWeight(.semibold).foregroundColor(qColor(q))
            }
        }
        .padding()
        .background(Color(uiColor: .systemBackground))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(qColor(q).opacity(0.2), lineWidth: 1))
    }

    private var recentActivity: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(s.recentTasks).font(.headline)

            let recent = taskStore.tasks.sorted { $0.createdAt > $1.createdAt }.prefix(8)
            ForEach(Array(recent)) { task in
                HStack(spacing: 10) {
                    Circle().fill(qColor(task.quadrant)).frame(width: 8, height: 8)
                    Text(task.title)
                        .font(.subheadline).lineLimit(1)
                        .strikethrough(task.isCompleted)
                        .foregroundColor(task.isCompleted ? .secondary : .primary)
                    Spacer()
                    Text(s.quadrantTitle(task.quadrant))
                        .font(.caption).foregroundColor(qColor(task.quadrant))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(task.quadrant.color.opacity(0.1))
                        .cornerRadius(4)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(uiColor: .systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
    }

    private func statBadge(value: Int, label: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(value)").font(.title2).fontWeight(.bold).foregroundColor(color)
            Text(label).font(.caption).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.08))
        .cornerRadius(8)
    }
}

#Preview {
    DashboardView().environmentObject(TaskStore())
}
