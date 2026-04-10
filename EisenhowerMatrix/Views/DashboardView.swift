import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var taskStore: TaskStore

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    overallCard
                    quadrantCards
                    recentActivity
                }
                .padding()
            }
            .navigationTitle("Dashboard")
            .background(Color(uiColor: .systemGroupedBackground))
        }
    }

    // MARK: - Overall summary card

    private var overallCard: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Overall Progress")
                        .font(.headline)
                    Text("\(taskStore.completedCount) of \(taskStore.totalCount) tasks done")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                ZStack {
                    Circle()
                        .stroke(Color.blue.opacity(0.15), lineWidth: 8)
                    Circle()
                        .trim(from: 0, to: taskStore.completionRate)
                        .stroke(Color.blue, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut, value: taskStore.completionRate)
                    Text("\(Int(taskStore.completionRate * 100))%")
                        .font(.system(size: 14, weight: .bold))
                }
                .frame(width: 60, height: 60)
            }

            HStack(spacing: 12) {
                statBadge(value: taskStore.totalCount,     label: "Total",     color: .primary)
                statBadge(value: taskStore.pendingCount,   label: "Pending",   color: .orange)
                statBadge(value: taskStore.completedCount, label: "Completed", color: .green)
            }
        }
        .padding()
        .background(Color(uiColor: .systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
    }

    // MARK: - Per-quadrant cards

    private var quadrantCards: some View {
        VStack(spacing: 12) {
            Text("Quadrant Breakdown")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(Quadrant.allCases) { q in
                    quadrantCard(q)
                }
            }
        }
    }

    private func quadrantCard(_ q: Quadrant) -> some View {
        let tasks   = taskStore.tasks(for: q)
        let done    = tasks.filter { $0.isCompleted }.count
        let total   = tasks.count
        let rate    = total > 0 ? Double(done) / Double(total) : 0.0

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(q.emoji)
                Text(q.title)
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundColor(q.color)
                Spacer()
            }

            Text(q.subtitle)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)

            ProgressView(value: rate)
                .tint(q.color)
                .scaleEffect(x: 1, y: 1.5)

            HStack {
                Text("\(done)/\(total)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(Int(rate * 100))%")
                    .font(.caption).fontWeight(.semibold)
                    .foregroundColor(q.color)
            }
        }
        .padding()
        .background(Color(uiColor: .systemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(q.color.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Recent activity

    private var recentActivity: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Tasks")
                .font(.headline)

            let recent = taskStore.tasks
                .sorted { $0.createdAt > $1.createdAt }
                .prefix(8)

            ForEach(Array(recent)) { task in
                HStack(spacing: 10) {
                    Circle()
                        .fill(task.quadrant.color)
                        .frame(width: 8, height: 8)
                    Text(task.title)
                        .font(.subheadline)
                        .lineLimit(1)
                        .strikethrough(task.isCompleted)
                        .foregroundColor(task.isCompleted ? .secondary : .primary)
                    Spacer()
                    Text(task.quadrant.title)
                        .font(.caption)
                        .foregroundColor(task.quadrant.color)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(task.quadrant.color.opacity(0.1))
                        .cornerRadius(4)
                }
            }
        }
        .padding()
        .background(Color(uiColor: .systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
    }

    // MARK: - Helper

    private func statBadge(value: Int, label: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.title2).fontWeight(.bold)
                .foregroundColor(color)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.08))
        .cornerRadius(8)
    }
}

#Preview {
    DashboardView()
        .environmentObject(TaskStore())
}
