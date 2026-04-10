import SwiftUI

struct ContentView: View {
    @EnvironmentObject var taskStore: TaskStore
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            MatrixView()
                .tabItem { Label("Matrix",    systemImage: "square.grid.2x2.fill") }
                .tag(0)

            DashboardView()
                .tabItem { Label("Dashboard", systemImage: "chart.bar.fill") }
                .tag(1)

            TreeView()
                .tabItem { Label("Tree",      systemImage: "list.bullet.indent") }
                .tag(2)

            CalendarView()
                .tabItem { Label("Calendar",  systemImage: "calendar") }
                .tag(3)

            ChatView()
                .tabItem { Label("Chat",      systemImage: "bubble.left.and.bubble.right.fill") }
                .tag(4)
        }
        .tint(.blue)
    }
}

#Preview {
    ContentView()
        .environmentObject(TaskStore())
}
