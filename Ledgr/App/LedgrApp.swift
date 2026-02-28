import SwiftUI
import SwiftData

@main
struct LedgrApp: App {

    @StateObject private var dependencies = AppDependencies()

    var body: some Scene {
        WindowGroup {
            TabView {
                HomeView()
                    .tabItem {
                        Image(systemName: "house.fill")
                        Text("Home")
                    }

                HistoryView()
                    .tabItem {
                        Image(systemName: "chart.bar.fill")
                        Text("Analytics")
                    }

                SettingsView()
                    .tabItem {
                        Image(systemName: "person.fill")
                        Text("Profile")
                    }
            }
            .tint(Color.ledgrPrimary)
            .environmentObject(dependencies)
        }
        .modelContainer(for: Expense.self)
    }
}
