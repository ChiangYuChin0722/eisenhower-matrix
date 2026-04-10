import SwiftUI

struct PomodoroView: View {
    @EnvironmentObject var taskStore: TaskStore
    @Environment(\.dismiss)     var dismiss
    @Environment(\.scenePhase) private var scenePhase

    @AppStorage("appLanguage")        private var lang: String = "en"
    @AppStorage("appAccent")          private var appAccent: String = "blue"
    @AppStorage("matrixTheme")        private var matrixTheme: String = "classic"
    @AppStorage("pomodoroWork")       private var workMinutes = 25
    @AppStorage("pomodoroShortBreak") private var shortBreak  = 5
    @AppStorage("pomodoroLongBreak")  private var longBreak   = 15

    var initialTask: EisTask? = nil

    // MARK: - Mode

    enum Mode { case focus, shortBreak, longBreak }

    @State private var mode              = Mode.focus
    @State private var secondsRemaining  = 0
    @State private var isRunning         = false
    @State private var sessionsCompleted = 0
    @State private var backgroundedAt: Date? = nil

    private let sessionsPerCycle = 4

    // MARK: - Computed

    private var s: Str { Str(lang) }
    private var accent: Color { .accent(appAccent) }
    private func qColor(_ q: Quadrant) -> Color { q.color(theme: matrixTheme) }

    private var totalSeconds: Int {
        switch mode {
        case .focus:       return workMinutes * 60
        case .shortBreak:  return shortBreak  * 60
        case .longBreak:   return longBreak   * 60
        }
    }

    private var progress: Double {
        guard totalSeconds > 0 else { return 0 }
        return 1.0 - Double(secondsRemaining) / Double(totalSeconds)
    }

    private var ringColor: Color {
        switch mode {
        case .focus:      return accent
        case .shortBreak: return .green
        case .longBreak:  return .teal
        }
    }

    private var modeLabel: String {
        switch mode {
        case .focus:      return s.focusMode
        case .shortBreak: return s.shortBreakLabel
        case .longBreak:  return s.longBreakLabel
        }
    }

    private var timeString: String {
        String(format: "%02d:%02d", secondsRemaining / 60, secondsRemaining % 60)
    }

    // MARK: - Body

    var body: some View {
        NavigationView {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Task indicator
                    if let task = initialTask {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(qColor(task.quadrant))
                                .frame(width: 8, height: 8)
                            Text(task.title)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        .padding(.top, 4)
                    }

                    Spacer()

                    // Session dots
                    HStack(spacing: 10) {
                        ForEach(0..<sessionsPerCycle, id: \.self) { i in
                            Circle()
                                .fill(i < sessionsCompleted % sessionsPerCycle
                                      ? ringColor
                                      : Color.secondary.opacity(0.2))
                                .frame(width: 10, height: 10)
                                .animation(.spring(response: 0.3), value: sessionsCompleted)
                        }
                    }
                    .padding(.bottom, 24)

                    // Ring + time
                    ZStack {
                        Circle()
                            .stroke(ringColor.opacity(0.12), lineWidth: 14)

                        Circle()
                            .trim(from: 0, to: progress)
                            .stroke(ringColor, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .animation(.linear(duration: 1), value: progress)

                        VStack(spacing: 6) {
                            Text(timeString)
                                .font(.system(size: 60, weight: .thin, design: .monospaced))
                                .foregroundColor(.primary)
                                .monospacedDigit()
                            Text(modeLabel)
                                .font(.subheadline).fontWeight(.semibold)
                                .foregroundColor(ringColor)
                        }
                    }
                    .frame(width: 270, height: 270)
                    .padding(.bottom, 44)

                    // Controls: reset  ▶/⏸  skip
                    HStack(spacing: 28) {
                        circleButton(icon: "arrow.counterclockwise", size: 22, frame: 54,
                                     bg: Color.secondary.opacity(0.1), fg: .secondary) { resetTimer() }

                        circleButton(icon: isRunning ? "pause.fill" : "play.fill", size: 30, frame: 72,
                                     bg: ringColor, fg: .white) { toggleTimer() }
                            .shadow(color: ringColor.opacity(0.35), radius: 10, y: 5)

                        circleButton(icon: "forward.end.fill", size: 22, frame: 54,
                                     bg: Color.secondary.opacity(0.1), fg: .secondary) { skipPhase() }
                    }
                    .padding(.bottom, 36)

                    // Duration badges
                    HStack(spacing: 12) {
                        durationBadge(icon: "brain.head.profile", minutes: workMinutes,
                                      label: s.focusMode,       active: mode == .focus)
                        durationBadge(icon: "cup.and.saucer",    minutes: shortBreak,
                                      label: s.shortBreakLabel, active: mode == .shortBreak)
                        durationBadge(icon: "moon.zzz",          minutes: longBreak,
                                      label: s.longBreakLabel,  active: mode == .longBreak)
                    }

                    Spacer()
                }
                .padding(.horizontal, 32)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Label(s.pomodoroTitle, systemImage: "timer")
                        .font(.headline)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(s.done) {
                        isRunning = false
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            secondsRemaining = workMinutes * 60
        }
        .onChange(of: scenePhase) { phase in
            if phase == .background {
                backgroundedAt = isRunning ? Date() : nil
            } else if phase == .active, let bg = backgroundedAt {
                backgroundedAt = nil
                let elapsed = Int(Date().timeIntervalSince(bg))
                let remaining = secondsRemaining - elapsed
                if remaining <= 0 {
                    timerDone()
                } else {
                    secondsRemaining = remaining
                }
            }
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            guard isRunning else { return }
            if secondsRemaining > 0 {
                secondsRemaining -= 1
            } else {
                timerDone()
            }
        }
    }

    // MARK: - Sub-views

    private func circleButton(icon: String, size: CGFloat, frame: CGFloat,
                               bg: Color, fg: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size, weight: .semibold))
                .foregroundColor(fg)
                .frame(width: frame, height: frame)
                .background(bg)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }

    private func durationBadge(icon: String, minutes: Int, label: String, active: Bool) -> some View {
        VStack(spacing: 2) {
            HStack(spacing: 3) {
                Image(systemName: icon).font(.system(size: 10))
                Text("\(minutes)m").font(.caption).fontWeight(.semibold)
            }
            .foregroundColor(active ? ringColor : .secondary)
            Text(label).font(.system(size: 9)).foregroundColor(.secondary)
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background((active ? ringColor : Color.secondary).opacity(0.08))
        .cornerRadius(8)
    }

    // MARK: - Actions

    private func toggleTimer() {
        HapticManager.shared.impact(.medium)
        isRunning.toggle()
    }

    private func resetTimer() {
        HapticManager.shared.impact(.light)
        isRunning = false
        secondsRemaining = totalSeconds
    }

    private func skipPhase() {
        HapticManager.shared.impact(.light)
        isRunning = false
        advanceMode()
    }

    private func timerDone() {
        isRunning = false
        HapticManager.shared.notification(.success)
        if mode == .focus { sessionsCompleted += 1 }
        advanceMode()
        isRunning = true   // auto-start next phase
    }

    private func advanceMode() {
        switch mode {
        case .focus:
            if sessionsCompleted > 0 && sessionsCompleted % sessionsPerCycle == 0 {
                mode = .longBreak
                secondsRemaining = longBreak * 60
            } else {
                mode = .shortBreak
                secondsRemaining = shortBreak * 60
            }
        case .shortBreak, .longBreak:
            mode = .focus
            secondsRemaining = workMinutes * 60
        }
    }
}

#Preview {
    PomodoroView(initialTask: nil).environmentObject(TaskStore())
}
