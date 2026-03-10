import SwiftUI

struct MainWindowView: View {
    var taskStore: TaskStore
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            TodayView(taskStore: taskStore)
                .tabItem { Label("Today", systemImage: "sun.max.fill") }
                .tag(0)

            HistoryView(taskStore: taskStore)
                .tabItem { Label("History", systemImage: "clock.fill") }
                .tag(1)

            UpcomingView(taskStore: taskStore)
                .tabItem { Label("Schedule", systemImage: "calendar") }
                .tag(2)

            SettingsView(taskStore: taskStore)
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                .tag(3)
        }
        .frame(minWidth: 420, minHeight: 500)
        .alert("New Day!", isPresented: Binding(
            get: { taskStore.showDateChangeAlert },
            set: { taskStore.showDateChangeAlert = $0 }
        )) {
            Button("Move All to Today") {
                taskStore.moveAllMissedToToday()
                selectedTab = 0
            }
            Button("Keep as Missed", role: .cancel) {}
        } message: {
            Text("You have \(taskStore.dateChangeIncompleteCount) incomplete task(s) from previous days. Would you like to move them to today?")
        }
    }
}
