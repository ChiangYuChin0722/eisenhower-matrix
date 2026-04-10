import WidgetKit
import SwiftUI

// MARK: - Timeline entry

struct EisenhowerEntry: TimelineEntry {
    let date:     Date
    let snapshot: WidgetSnapshot
}

// MARK: - Timeline provider

struct EisenhowerProvider: TimelineProvider {
    func placeholder(in context: Context) -> EisenhowerEntry {
        EisenhowerEntry(date: .now, snapshot: .placeholder)
    }
    func getSnapshot(in context: Context,
                     completion: @escaping (EisenhowerEntry) -> Void) {
        completion(EisenhowerEntry(date: .now, snapshot: .load()))
    }
    func getTimeline(in context: Context,
                     completion: @escaping (Timeline<EisenhowerEntry>) -> Void) {
        let entry   = EisenhowerEntry(date: .now, snapshot: .load())
        let refresh = Calendar.current.date(byAdding: .minute, value: 15, to: .now)!
        completion(Timeline(entries: [entry], policy: .after(refresh)))
    }
}

// MARK: - Entry view dispatcher

struct EisenhowerEntryView: View {
    let entry: EisenhowerEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        Group {
            switch family {
            case .systemSmall:           SmallWidgetView(entry: entry)
            case .systemMedium:          MediumWidgetView(entry: entry)
            case .accessoryCircular:     AccessoryCircularView(entry: entry)
            case .accessoryRectangular:  AccessoryRectangularView(entry: entry)
            case .accessoryInline:       AccessoryInlineView(entry: entry)
            default:                     SmallWidgetView(entry: entry)
            }
        }
        .widgetBg()
    }
}

// MARK: - Small widget (2×2)

struct SmallWidgetView: View {
    let entry: EisenhowerEntry
    var s: WidgetSnapshot { entry.snapshot }
    var rate: Double { s.totalCount > 0 ? Double(s.completedCount) / Double(s.totalCount) : 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 4) {
                Image(systemName: "square.grid.2x2.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.blue)
                Text("Eisenhower")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
            }

            Spacer()

            // Progress ring
            ZStack {
                Circle()
                    .stroke(Color.blue.opacity(0.15), lineWidth: 7)
                Circle()
                    .trim(from: 0, to: rate)
                    .stroke(
                        LinearGradient(colors: [.blue, .cyan],
                                       startPoint: .topLeading,
                                       endPoint: .bottomTrailing),
                        style: StrokeStyle(lineWidth: 7, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 0) {
                    Text("\(Int(rate * 100))%")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                    Text("done")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 64, height: 64)
            .frame(maxWidth: .infinity)

            Spacer()

            // Bottom: pending + streak
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text("\(s.pendingCount)")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(.orange)
                    Text("pending")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 1) {
                    HStack(spacing: 2) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.orange)
                        Text("\(s.currentStreak)")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                    }
                    Text("streak")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(14)
    }
}

// MARK: - Medium widget (4×2)

struct MediumWidgetView: View {
    let entry: EisenhowerEntry
    var s: WidgetSnapshot { entry.snapshot }
    var rate: Double { s.totalCount > 0 ? Double(s.completedCount) / Double(s.totalCount) : 0 }

    var body: some View {
        HStack(spacing: 0) {
            // Left: progress panel
            VStack(alignment: .leading, spacing: 6) {
                Label("Progress", systemImage: "chart.pie.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .labelStyle(.iconOnly)

                Spacer()

                ZStack {
                    Circle()
                        .stroke(Color.blue.opacity(0.15), lineWidth: 7)
                    Circle()
                        .trim(from: 0, to: rate)
                        .stroke(
                            LinearGradient(colors: [.blue, .cyan],
                                           startPoint: .topLeading,
                                           endPoint: .bottomTrailing),
                            style: StrokeStyle(lineWidth: 7, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 0) {
                        Text("\(Int(rate * 100))%")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                        Text("done")
                            .font(.system(size: 8))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 54, height: 54)

                HStack(spacing: 3) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.orange)
                    Text("\(s.currentStreak)d")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                    Text("streak")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .frame(width: 84)
            .padding(.leading, 14)
            .padding(.vertical, 12)

            Rectangle()
                .fill(Color.secondary.opacity(0.2))
                .frame(width: 1)
                .padding(.vertical, 12)

            // Right: deadlines
            VStack(alignment: .leading, spacing: 4) {
                Label("Deadlines", systemImage: "clock.badge.exclamationmark.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)

                Spacer(minLength: 2)

                if s.upcomingDeadlines.isEmpty {
                    Text("No upcoming deadlines")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Spacer()
                } else {
                    ForEach(s.upcomingDeadlines.prefix(3)) { item in
                        WidgetDeadlineRow(item: item)
                    }
                    Spacer(minLength: 0)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct WidgetDeadlineRow: View {
    let item: WidgetDeadline

    var dotColor: Color {
        switch item.quadrantRaw {
        case "do":       return .red
        case "schedule": return .blue
        case "delegate": return .orange
        default:         return .secondary
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(LinearGradient(colors: [dotColor, dotColor.opacity(0.6)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 6, height: 6)
            VStack(alignment: .leading, spacing: 0) {
                Text(item.title)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
                    .foregroundStyle(item.isOverdue ? .red : .primary)
                Text(item.dueDate, style: .relative)
                    .font(.system(size: 9))
                    .foregroundStyle(item.isOverdue ? .red : .secondary)
            }
            Spacer(minLength: 0)
        }
    }
}

// MARK: - Lock-screen accessory widgets

struct AccessoryCircularView: View {
    let entry: EisenhowerEntry
    var rate: Double {
        let s = entry.snapshot
        return s.totalCount > 0 ? Double(s.completedCount) / Double(s.totalCount) : 0
    }
    var body: some View {
        Gauge(value: rate) {
            Image(systemName: "square.grid.2x2.fill")
        } currentValueLabel: {
            Text("\(Int(rate * 100))")
                .font(.system(size: 11, weight: .bold, design: .rounded))
        }
        .gaugeStyle(.accessoryCircular)
    }
}

struct AccessoryRectangularView: View {
    let entry: EisenhowerEntry
    var s: WidgetSnapshot { entry.snapshot }
    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Label("\(s.pendingCount) pending  ·  \(s.currentStreak)d streak",
                  systemImage: "square.grid.2x2.fill")
                .font(.system(size: 11, weight: .medium))
            if let next = s.upcomingDeadlines.first {
                Label(next.title, systemImage: "clock")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct AccessoryInlineView: View {
    let entry: EisenhowerEntry
    var s: WidgetSnapshot { entry.snapshot }
    var body: some View {
        if let next = s.upcomingDeadlines.first {
            Label(next.title, systemImage: "clock")
        } else {
            Label("\(s.pendingCount) tasks  ·  \(s.currentStreak)d streak",
                  systemImage: "square.grid.2x2")
        }
    }
}

// MARK: - Widget definition

struct EisenhowerMatrixWidget: Widget {
    let kind = "EisenhowerMatrixWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: EisenhowerProvider()) { entry in
            EisenhowerEntryView(entry: entry)
        }
        .configurationDisplayName("Eisenhower Matrix")
        .description("Track tasks and deadlines at a glance.")
        .supportedFamilies([
            .systemSmall, .systemMedium,
            .accessoryCircular, .accessoryRectangular, .accessoryInline,
        ])
    }
}

// MARK: - Widget bundle

@main
struct EisenhowerWidgetBundle: WidgetBundle {
    var body: some Widget {
        EisenhowerMatrixWidget()
    }
}

// MARK: - iOS 16/17 background compatibility

extension View {
    @ViewBuilder
    func widgetBg() -> some View {
        if #available(iOS 17.0, *) {
            containerBackground(.background, for: .widget)
        } else {
            background(Color(uiColor: .systemBackground))
        }
    }
}

// MARK: - Previews

#Preview("Small", as: .systemSmall) {
    EisenhowerMatrixWidget()
} timeline: {
    EisenhowerEntry(date: .now, snapshot: .placeholder)
}

#Preview("Medium", as: .systemMedium) {
    EisenhowerMatrixWidget()
} timeline: {
    EisenhowerEntry(date: .now, snapshot: .placeholder)
}
