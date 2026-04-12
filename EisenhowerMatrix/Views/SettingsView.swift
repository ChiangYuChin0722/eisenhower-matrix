import SwiftUI
import UserNotifications

struct SettingsView: View {
    @EnvironmentObject var taskStore: TaskStore
    @EnvironmentObject var authManager: AuthManager
    @AppStorage("showCompletedTasks")     private var showCompletedTasks = true
    @AppStorage("appTheme")              private var appTheme           = "system"
    @AppStorage("appLanguage")           private var lang               = "en"
    @AppStorage("appAccent")             private var appAccent          = "blue"
    @AppStorage("matrixTheme")           private var matrixTheme        = "classic"
    @AppStorage("quadrantName_do")       private var nameDoFirst        = ""
    @AppStorage("quadrantName_schedule") private var nameSchedule       = ""
    @AppStorage("quadrantName_delegate") private var nameDelegate       = ""
    @AppStorage("quadrantName_eliminate")private var nameEliminate      = ""
    @AppStorage("pomodoroWork")          private var pomodoroWork       = 25
    @AppStorage("pomodoroShortBreak")    private var pomodoroShort      = 5
    @AppStorage("pomodoroLongBreak")     private var pomodoroLong       = 15
    @AppStorage("countdownPrecision")    private var countdownPrecision = "dhms"
    @State private var showingResetConfirm   = false
    @State private var showingQuadrantEdit   = false
    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined

    private var s: Str { Str(lang) }

    var body: some View {
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

                // MARK: Custom quadrant names
                Section {
                    ForEach(Quadrant.allCases) { q in
                        HStack(spacing: 10) {
                            Circle()
                                .fill(q.color(theme: matrixTheme))
                                .frame(width: 10, height: 10)
                            Text(s.quadrantTitle(q))
                                .font(.subheadline)
                        }
                    }
                    Button {
                        showingQuadrantEdit = true
                    } label: {
                        Label(lang == "zh" ? "編輯象限名稱" : "Edit Quadrant Names",
                              systemImage: "pencil")
                    }
                } header: {
                    Text(s.customQuadrantSection)
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

                // MARK: Pomodoro
                Section(s.pomodoroSection) {
                    pomodoroStepper(s.workDuration,       icon: "brain.head.profile", value: $pomodoroWork,  range: 5...90,  step: 5)
                    pomodoroStepper(s.shortBreakDuration, icon: "cup.and.saucer",     value: $pomodoroShort, range: 1...30,  step: 1)
                    pomodoroStepper(s.longBreakDuration,  icon: "moon.zzz",           value: $pomodoroLong,  range: 5...60,  step: 5)
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

                // MARK: Countdown precision
                Section(s.countdownPrecisionSection) {
                    Picker(s.countdownPrecisionSection, selection: $countdownPrecision) {
                        Text(s.precisionD).tag("d")
                        Text(s.precisionDH).tag("dh")
                        Text(s.precisionDHM).tag("dhm")
                        Text(s.precisionDHMS).tag("dhms")
                    }
                }

                // MARK: Reset
                Section(s.resetSectionTitle) {
                    Button(role: .destructive) {
                        showingResetConfirm = true
                    } label: {
                        Label(s.resetButton, systemImage: "arrow.counterclockwise")
                    }
                }

                // MARK: Account
                Section(lang == "zh" ? "帳號" : "Account") {
                    NavigationLink {
                        ProfileEditView()
                            .environmentObject(authManager)
                    } label: {
                        HStack(spacing: 10) {
                            authManager.avatarView(size: 36)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(authManager.user?.displayName ?? (lang == "zh" ? "使用者" : "User"))
                                    .font(.subheadline)
                                Text(authManager.user?.email ?? "")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    Button(role: .destructive) {
                        try? authManager.signOut()
                    } label: {
                        Label(lang == "zh" ? "登出" : "Sign Out",
                              systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
        }
        .scrollContentBackground(.hidden)
        .background(Color.appBackground)
        .navigationTitle(s.settingsTitle)
        .navigationBarTitleDisplayMode(.inline)
        .alert(s.resetConfirmTitle, isPresented: $showingResetConfirm) {
            Button(s.resetConfirmAction, role: .destructive) {
                taskStore.resetToSampleData()
            }
            Button(s.cancel, role: .cancel) {}
        } message: {
            Text(s.resetConfirmMsg)
        }
        .onAppear { refreshNotificationStatus() }
        .sheet(isPresented: $showingQuadrantEdit) {
            quadrantEditSheet
        }
    }

    // MARK: - Quadrant name edit sheet

    private var quadrantEditSheet: some View {
        NavigationView {
            Form {
                Section(footer: Text(lang == "zh" ? "留空以使用預設名稱" : "Leave blank to use default names").font(.caption).foregroundColor(.secondary)) {
                    quadrantNameRow(.doFirst,   $nameDoFirst)
                    quadrantNameRow(.schedule,  $nameSchedule)
                    quadrantNameRow(.delegate,  $nameDelegate)
                    quadrantNameRow(.eliminate, $nameEliminate)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.appBackground)
            .navigationTitle(lang == "zh" ? "編輯象限名稱" : "Edit Quadrant Names")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(s.doneButton) { showingQuadrantEdit = false }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: - Matrix theme picker

    private var matrixThemePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(matrixThemes) { theme in
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            matrixTheme = theme.id
                            appAccent   = theme.accentId
                        }
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

    private func quadrantNameRow(_ q: Quadrant, _ binding: Binding<String>) -> some View {
        HStack(spacing: 10) {
            Circle().fill(q.color(theme: matrixTheme)).frame(width: 10, height: 10)
            TextField(s.quadrantDefaultTitle(q), text: binding)
        }
    }

    private func pomodoroStepper(_ label: String, icon: String, value: Binding<Int>, range: ClosedRange<Int>, step: Int) -> some View {
        Stepper(value: value, in: range, step: step) {
            HStack {
                Label(label, systemImage: icon)
                Spacer()
                Text("\(value.wrappedValue) min").foregroundColor(.secondary).font(.subheadline)
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
    let color: Color
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(color.opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(color)
            }
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
        .environmentObject(AuthManager())
}
