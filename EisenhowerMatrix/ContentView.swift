import SwiftUI

struct ContentView: View {
    @EnvironmentObject var taskStore: TaskStore
    @AppStorage("appTheme") private var appTheme = "system"
    @State private var showSearch = false

    var body: some View {
        TabView {
            MatrixView()
                .tabItem { Label("Matrix",    systemImage: "square.grid.2x2.fill") }

            ChecklistView()
                .tabItem { Label("Checklist", systemImage: "checklist") }

            CalendarView()
                .tabItem { Label("Calendar",  systemImage: "calendar") }

            DeadlineView()
                .tabItem { Label("Deadlines", systemImage: "clock.badge.exclamationmark") }

            DashboardView()
                .tabItem { Label("Dashboard", systemImage: "chart.bar.fill") }
        }
        .tint(.blue)
        .preferredColorScheme(colorScheme)
        .overlay(alignment: .topTrailing) {
            // Global search button floating above all tabs
            Button {
                showSearch = true
            } label: {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .medium))
                    .padding(10)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
            }
            .padding(.trailing, 16)
            .padding(.top, 8)
        }
        .sheet(isPresented: $showSearch) {
            SearchView()
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
