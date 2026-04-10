import SwiftUI

@main
struct EisenhowerMatrixApp: App {
    @StateObject private var taskStore = TaskStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(taskStore)
        }
    }
}
