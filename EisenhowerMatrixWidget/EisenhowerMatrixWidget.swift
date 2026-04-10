// MARK: - EisenhowerMatrixWidget.swift
// Add this file to a NEW Widget Extension target in Xcode:
//   File > New > Target > Widget Extension > name: "EisenhowerMatrixWidget"
//
// Also required in Xcode for both targets (app + widget):
//   Signing & Capabilities > + Capability > App Groups
//   Add group: "group.com.eisenhower.matrix"
//
// Then change TaskStore's UserDefaults to use the App Group:
//   UserDefaults(suiteName: "group.com.eisenhower.matrix") ?? .standard

import WidgetKit
import SwiftUI

// MARK: - Shared data loader

private struct WidgetTask: Codable {
    var title: String
    var isCompleted: Bool
    var quadrantRaw: String
    var dueDate: Date?
}

private struct WidgetData {
    var total: Int
    var completed: Int
    var doFirstCount: Int
    var overdueCount: Int
    var nextTask: WidgetTask?
}

private func loadWidgetData() -> WidgetData {
    // Read from the shared App Group UserDefaults
    let defaults = UserDefaults(suiteName: "group.com.eisenhower.matrix") ?? .standard
    guard let data = defaults.data(forKey: "eisenhower_tasks_v4"),
          let tasks = try? JSONDecoder().decode([WidgetTask].self, from: data)
    else {
        return WidgetData(total: 0, completed: 0, doFirstCount: 0, overdueCount: 0, nextTask: nil)
    }
    let now     = Date()
    let active  = tasks.filter { !$0.isCompleted }
    let overdue = active.filter { $0.dueDate != nil && $0.dueDate! < now }
    let next    = active.filter { $0.dueDate != nil }.sorted { $0.dueDate! < $1.dueDate! }.first
    return WidgetData(
        total:        tasks.count,
        completed:    tasks.filter { $0.isCompleted }.count,
        doFirstCount: active.filter { $0.quadrantRaw == "do" }.count,
        overdueCount: overdue.count,
        nextTask:     next
    )
}

// MARK: - Timeline Provider

struct EisenhowerEntry: TimelineEntry {
    let date: Date
    let data: WidgetData
}

struct EisenhowerProvider: TimelineProvider {
    func placeholder(in context: Context) -> EisenhowerEntry {
        EisenhowerEntry(date: Date(), data: WidgetData(total: 8, completed: 3,
                                                       doFirstCount: 2, overdueCount: 1, nextTask: nil))
    }

    func getSnapshot(in context: Context, completion: @escaping (EisenhowerEntry) -> Void) {
        completion(EisenhowerEntry(date: Date(), data: loadWidgetData()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<EisenhowerEntry>) -> Void) {
        let entry    = EisenhowerEntry(date: Date(), data: loadWidgetData())
        // Refresh every 30 minutes
        let next     = Calendar.current.date(byAdding: .minute, value: 30, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(next))
        completion(timeline)
    }
}

// MARK: - Small Widget View

struct SmallWidgetView: View {
    let data: WidgetData
    var progress: Double {
        guard data.total > 0 else { return 0 }
        return Double(data.completed) / Double(data.total)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "square.grid.2x2.fill")
                    .foregroundColor(.blue)
                Text("Matrix")
                    .font(.caption).fontWeight(.semibold)
                    .foregroundColor(.blue)
            }

            Spacer()

            ZStack {
                Circle()
                    .stroke(Color.blue.opacity(0.15), lineWidth: 6)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Color.blue, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 0) {
                    Text("\(Int(progress * 100))%")
                        .font(.system(size: 16, weight: .bold))
                    Text("done")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 54, height: 54)
            .frame(maxWidth: .infinity)

            Spacer()

            HStack {
                if data.overdueCount > 0 {
                    Label("\(data.overdueCount) late", systemImage: "exclamationmark.circle.fill")
                        .font(.caption2)
                        .foregroundColor(.red)
                } else {
                    Label("\(data.doFirstCount) urgent", systemImage: "bolt.fill")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
            }
        }
        .padding(14)
        .containerBackground(.background, for: .widget)
    }
}

// MARK: - Medium Widget View

struct MediumWidgetView: View {
    let data: WidgetData

    var body: some View {
        HStack(spacing: 12) {
            // Left: progress ring
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    Image(systemName: "square.grid.2x2.fill")
                        .foregroundColor(.blue).font(.caption)
                    Text("Eisenhower")
                        .font(.caption).fontWeight(.semibold)
                        .foregroundColor(.blue)
                }

                ZStack {
                    Circle()
                        .stroke(Color.blue.opacity(0.15), lineWidth: 7)
                    let p = data.total > 0 ? Double(data.completed) / Double(data.total) : 0
                    Circle()
                        .trim(from: 0, to: p)
                        .stroke(Color.blue, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 0) {
                        Text("\(data.completed)")
                            .font(.system(size: 18, weight: .bold))
                        Text("/ \(data.total)")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
                .frame(width: 70, height: 70)

                if data.overdueCount > 0 {
                    Label("\(data.overdueCount) overdue", systemImage: "exclamationmark.circle.fill")
                        .font(.caption2).foregroundColor(.red)
                }
            }

            Divider()

            // Right: next task
            VStack(alignment: .leading, spacing: 6) {
                Text("Up next")
                    .font(.caption).foregroundColor(.secondary)

                if let task = data.nextTask {
                    Text(task.title)
                        .font(.subheadline).fontWeight(.medium)
                        .lineLimit(2)
                    if let due = task.dueDate {
                        Label(due, style: .relative)
                            .font(.caption2).foregroundColor(.orange)
                    }
                } else {
                    Text("No upcoming tasks")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(.green)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .containerBackground(.background, for: .widget)
    }
}

// MARK: - Widget Entry View (routes by size)

struct EisenhowerWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: EisenhowerEntry

    var body: some View {
        switch family {
        case .systemSmall:  SmallWidgetView(data: entry.data)
        case .systemMedium: MediumWidgetView(data: entry.data)
        default:            SmallWidgetView(data: entry.data)
        }
    }
}

// MARK: - Widget Configuration

struct EisenhowerMatrixWidget: Widget {
    let kind = "EisenhowerMatrixWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: EisenhowerProvider()) { entry in
            EisenhowerWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Eisenhower Matrix")
        .description("Track your task progress at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Widget Bundle (put this in a separate WidgetBundle file if you have multiple widgets)

@main
struct EisenhowerWidgetBundle: WidgetBundle {
    var body: some Widget {
        EisenhowerMatrixWidget()
    }
}
