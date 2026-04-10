import SwiftUI

struct ContentView: View {
    @EnvironmentObject var taskStore: TaskStore

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
        }
        .tint(.blue)
    }
}

#Preview {
    ContentView().environmentObject(TaskStore())
}
