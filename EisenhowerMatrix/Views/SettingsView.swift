import SwiftUI
import UserNotifications

struct SettingsView: View {
    @EnvironmentObject var taskStore: TaskStore
    @Environment(\.dismiss) var dismiss
    @AppStorage("showCompletedTasks") private var showCompletedTasks = true
    @AppStorage("appTheme")           private var appTheme           = "system"
    @AppStorage("appLanguage")        private var lang               = "en"
    @AppStorage("appAccent")          private var appAccent          = "blue"
    @AppStorage("matrixTheme")        private var matrixTheme        = "classic"
    @State private var showingResetConfirm   = false
    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined

    private var s: Str { Str(lang) }

    var body: some View {
        NavigationView {
            Form {
                // MARK: Display
                Section(s.displaySection) {
                    Toggle(s.showCompletedLabel, isOn: $showCompletedTasks)

                    Picker(s.themeLabel, selection: $appTheme) {
                        Text(s.themeSystem).tag("system")
                        Text(s.themeLight).tag("light")
                        Text(s.themeDark).tag("dark")
                    }
                }

                // MARK: Matrix colour theme
                Section(s.matrixThemeSection) {
                    matrixThemePicker
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }

                // MARK: Accent colour
                Section(s.accentSection) {
                    accentColorPicker
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }

                // MARK: Language
                Section(s.languageSection) {
                    Picker(s.languageSection, selection: $lang) {
                        Text("English").tag("en")
                        Text("中文").tag("zh")
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }

                // MARK: Notifications
                Section {
                    HStack {
                        Label(s.notifReminders, systemImage: "bell.badge")
                        Spacer()
                        notificationBadge
                    }

                    if notificationStatus == .notDetermined {
                        Button(s.enableNotif) {
                            NotificationManager.shared.requestPermission()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                refreshNotificationStatus()
                            }
                        }
                    } else if notificationStatus == .denied {
                        Button(s.openSettingsNotif) {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                    }

                    Text(s.notifDesc)
                        .font(.caption)
                        .foregroundColor(.secondary)
                } header: {
                    Text(s.notifSection)
                }

                // MARK: About
                Section(s.aboutSection) {
                    InfoRow(icon: "🚀", title: s.quadrantTitle(.doFirst),
                            subtitle: s.quadrantSubtitle(.doFirst))
                    InfoRow(icon: "🔥", title: s.quadrantTitle(.schedule),
                            subtitle: s.quadrantSubtitle(.schedule))
                    InfoRow(icon: "👥", title: s.quadrantTitle(.delegate),
                            subtitle: s.quadrantSubtitle(.delegate))
                    InfoRow(icon: "🗂️", title: s.quadrantTitle(.eliminate),
                            subtitle: s.quadrantSubtitle(.eliminate))
                }

                // MARK: Statistics
                Section(s.statsSection) {
                    LabeledContent(s.totalTasksLabel,    value: "\(taskStore.totalCount)")
                    LabeledContent(s.completedLabel,     value: "\(taskStore.completedCount)")
                    LabeledContent(s.completionRateLabel,value: "\(Int(taskStore.completionRate * 100))%")
                    LabeledContent(s.currentStreakLabel, value: s.streak(taskStore.currentStreak))
                }

                // MARK: Reset
                Section(s.resetSectionTitle) {
                    Button(role: .destructive) {
                        showingResetConfirm = true
                    } label: {
                        Label(s.resetButton, systemImage: "arrow.counterclockwise")
                    }
                }
            }
            .navigationTitle(s.settingsTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(s.doneButton) { dismiss() }
                }
            }
            .confirmationDialog(
                s.resetConfirmTitle,
                isPresented: $showingResetConfirm,
                titleVisibility: .visible
            ) {
                Button(s.resetConfirmAction, role: .destructive) {
                    taskStore.resetToSampleData()
                }
                Button(s.cancel, role: .cancel) {}
            } message: {
                Text(s.resetConfirmMsg)
            }
            .onAppear { refreshNotificationStatus() }
        }
    }

    // MARK: - Matrix theme picker

    private var matrixThemePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(matrixThemes) { theme in
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) { matrixTheme = theme.id }
                    } label: {
                        VStack(spacing: 6) {
                            // 2×2 colour swatch
                            ZStack {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color(uiColor: .secondarySystemBackground))
                                    .frame(width: 58, height: 58)
                                if matrixTheme == theme.id {
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.primary, lineWidth: 2)
                                        .frame(width: 58, height: 58)
                                }
                                Grid(horizontalSpacing: 3, verticalSpacing: 3) {
                                    GridRow {
                                        // top-left = Schedule, top-right = Do Now
                                        RoundedRectangle(cornerRadius: 3).fill(theme.schedule)
                                        RoundedRectangle(cornerRadius: 3).fill(theme.doFirst)
                                    }
                                    GridRow {
                                        // bottom-left = Eliminate, bottom-right = Delegate
                                        RoundedRectangle(cornerRadius: 3).fill(theme.eliminate)
                                        RoundedRectangle(cornerRadius: 3).fill(theme.delegateQ)
                                    }
                                }
                                .frame(width: 40, height: 40)
                            }
                            Text(s.themeName(theme.id))
                                .font(.caption2)
                                .foregroundColor(matrixTheme == theme.id ? .primary : .secondary)
                                .fontWeight(matrixTheme == theme.id ? .semibold : .regular)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Accent colour picker

    private var accentColorPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(accentOptions) { option in
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) { appAccent = option.id }
                    } label: {
                        ZStack {
                            Circle()
                                .fill(option.color)
                                .frame(width: 32, height: 32)
                            if appAccent == option.id {
                                Circle()
                                    .stroke(Color.primary, lineWidth: 2)
                                    .frame(width: 36, height: 36)
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var notificationBadge: some View {
        Group {
            switch notificationStatus {
            case .authorized:
                Text(s.notifOn).foregroundColor(.green).font(.subheadline)
            case .denied:
                Text(s.notifOff).foregroundColor(.red).font(.subheadline)
            default:
                Text(s.notifNotSet).foregroundColor(.secondary).font(.subheadline)
            }
        }
    }

    private func quadrantTitle(_ q: Quadrant) -> String { s.quadrantTitle(q) }
    private func quadrantSubtitle(_ q: Quadrant) -> String { s.quadrantSubtitle(q) }

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
    SettingsView().environmentObject(TaskStore())
}
