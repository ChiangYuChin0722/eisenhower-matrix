import SwiftUI

struct ContentView: View {
    @EnvironmentObject var taskStore: TaskStore
    @AppStorage("appTheme")           private var appTheme: String  = "system"
    @AppStorage("appLanguage")        private var lang: String      = "en"
    @AppStorage("appAccent")          private var appAccent: String = "blue"
    @AppStorage("hasSeenOnboarding")  private var hasSeenOnboarding = false

    private var s: Str { Str(lang) }
    private var accent: Color { .accent(appAccent) }

    var body: some View {
        TabView {
            MatrixView()
                .tabItem { Label(s.tabMatrix,    systemImage: "square.grid.2x2.fill") }

            ChecklistView()
                .tabItem { Label(s.tabChecklist, systemImage: "checklist") }

            CalendarView()
                .tabItem { Label(s.tabCalendar,  systemImage: "calendar") }

            DeadlineView()
                .tabItem { Label(s.tabDeadlines, systemImage: "clock.badge.exclamationmark") }

            DashboardView()
                .tabItem { Label(s.tabDashboard, systemImage: "chart.bar.fill") }
        }
        .tint(accent)
        .preferredColorScheme(colorScheme)
        .fullScreenCover(isPresented: .init(
            get: { !hasSeenOnboarding },
            set: { _ in }
        )) {
            OnboardingView()
        }
    }

    private var colorScheme: ColorScheme? {
        switch appTheme {
        case "light": return .light
        case "dark":  return .dark
        default:      return nil
        }
    }
}

#Preview {
    ContentView().environmentObject(TaskStore())
}
