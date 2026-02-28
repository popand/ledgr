import SwiftUI
import SwiftData
import GoogleSignIn

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
            .onOpenURL { url in
                GIDSignIn.sharedInstance.handle(url)
            }
        }
        .modelContainer(for: Expense.self)
    }
}
