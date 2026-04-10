import SwiftUI
import UserNotifications

struct SettingsView: View {
    @EnvironmentObject var taskStore: TaskStore
    @Environment(\.dismiss) var dismiss
    @AppStorage("showCompletedTasks") private var showCompletedTasks = true
    @AppStorage("defaultQuadrant")    private var defaultQuadrant    = "do"
    @AppStorage("appTheme")           private var appTheme           = "system"
    @State private var showingClearConfirm   = false
    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined

    var body: some View {
        NavigationView {
            Form {
                Section("Display") {
                    Toggle("Show completed tasks", isOn: $showCompletedTasks)

                    Picker("Default quadrant", selection: $defaultQuadrant) {
                        ForEach(Quadrant.allCases) { q in
                            Text(q.emoji + " " + q.title).tag(q.rawValue)
                        }
                    }

                    Picker("Theme", selection: $appTheme) {
                        Text("System").tag("system")
                        Text("Light").tag("light")
                        Text("Dark").tag("dark")
                    }
                }

                // MARK: - Notifications
                Section {
                    HStack {
                        Label("Task reminders", systemImage: "bell.badge")
                        Spacer()
                        notificationBadge
                    }

                    if notificationStatus == .notDetermined {
                        Button("Enable Notifications") {
                            NotificationManager.shared.requestPermission()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                refreshNotificationStatus()
                            }
                        }
                    } else if notificationStatus == .denied {
                        Button("Open Settings to Enable") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                    }

                    Text("You'll get a reminder 1 hour before each task's due time.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } header: {
                    Text("Notifications")
                }

                Section("About the Matrix") {
                    InfoRow(icon: "🚀", title: "Do",       subtitle: "Urgent & Important — act immediately")
                    InfoRow(icon: "🔥", title: "Schedule", subtitle: "Important, not urgent — plan it")
                    InfoRow(icon: "👥", title: "Delegate", subtitle: "Urgent, not important — hand it off")
                    InfoRow(icon: "🗂️", title: "Eliminate",subtitle: "Not urgent & not important — drop it")
                }

                Section("Statistics") {
                    LabeledContent("Total tasks",     value: "\(taskStore.totalCount)")
                    LabeledContent("Completed",       value: "\(taskStore.completedCount)")
                    LabeledContent("Completion rate", value: "\(Int(taskStore.completionRate * 100))%")
                    LabeledContent("Current streak",  value: "\(taskStore.currentStreak) days")
                }

                Section {
                    Button(role: .destructive) {
                        showingClearConfirm = true
                    } label: {
                        Label("Clear all tasks", systemImage: "trash")
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .confirmationDialog(
                "Clear all tasks?",
                isPresented: $showingClearConfirm,
                titleVisibility: .visible
            ) {
                Button("Clear all", role: .destructive) {
                    for task in taskStore.tasks {
                        taskStore.deleteTask(id: task.id)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete all tasks and cannot be undone.")
            }
            .onAppear { refreshNotificationStatus() }
        }
    }

    private var notificationBadge: some View {
        Group {
            switch notificationStatus {
            case .authorized:
                Text("On").foregroundColor(.green).font(.subheadline)
            case .denied:
                Text("Off").foregroundColor(.red).font(.subheadline)
            default:
                Text("Not set").foregroundColor(.secondary).font(.subheadline)
            }
        }
    }

    private func refreshNotificationStatus() {
        NotificationManager.shared.getAuthorizationStatus { status in
            notificationStatus = status
        }
    }
}

struct InfoRow: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 10) {
            Text(icon).font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline).fontWeight(.medium)
                Text(subtitle).font(.caption).foregroundColor(.secondary)
            }
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(TaskStore())
}
