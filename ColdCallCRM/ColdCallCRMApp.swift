import SwiftUI
import SwiftData

@main
struct ColdCallCRMApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
                .tint(Palette.accent)
        }
        .modelContainer(for: [Lead.self, CallRecord.self, DayPlan.self])
    }
}

struct ContentView: View {
    var body: some View {
        TabView {
            TodayView()
                .tabItem { Label("Сегодня", systemImage: "phone.arrow.up.right.fill") }
            LeadsView()
                .tabItem { Label("Лиды", systemImage: "flame.fill") }
            StatsView()
                .tabItem { Label("Итоги", systemImage: "chart.bar.xaxis") }
            SettingsView()
                .tabItem { Label("Ещё", systemImage: "ellipsis.circle.fill") }
        }
    }
}
