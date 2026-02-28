import SwiftUI
import SwiftData
import GoogleSignIn

@main
struct LedgrApp: App {

    @StateObject private var dependencies = AppDependencies()
    @State private var selectedTab = 0

    var body: some Scene {
        WindowGroup {
            TabView(selection: $selectedTab) {
                HomeView(selectedTab: $selectedTab)
                    .tabItem {
                        Image(systemName: "house.fill")
                        Text("Home")
                    }
                    .tag(0)

                HistoryView()
                    .tabItem {
                        Image(systemName: "chart.bar.fill")
                        Text("Analytics")
                    }
                    .tag(1)

                SettingsView()
                    .tabItem {
                        Image(systemName: "person.fill")
                        Text("Profile")
                    }
                    .tag(2)
            }
            .tint(Color.ledgrPrimary)
            .environmentObject(dependencies)
            .onOpenURL { url in
                GIDSignIn.sharedInstance.handle(url)
            }
            .task {
                await dependencies.authService.restorePreviousSignIn()
            }
        }
        .modelContainer(for: Expense.self)
    }
}
