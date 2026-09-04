import SwiftUI

struct RootView: View {
    enum Tab: Hashable { case home, navigation, garage, expenses, rides, settings }

    @StateObject private var session = DashSessionCoordinator()
    @StateObject private var navigation = NavigationViewModel()
    @StateObject private var streamer = ProjectionStreamer()
    @State private var selectedTab: Tab = .home

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack { DashboardView() }
                .tabItem { Label("Home", systemImage: "motorcycle") }
                .tag(Tab.home)

            NavigationStack { RideNavigationView() }
                .tabItem { Label("Navigate", systemImage: "map.fill") }
                .tag(Tab.navigation)

            NavigationStack { GarageView() }
                .tabItem { Label("Garage", systemImage: "wrench.and.screwdriver.fill") }
                .tag(Tab.garage)

            NavigationStack { ExpensesView() }
                .tabItem { Label("Expenses", systemImage: "indianrupeesign.circle.fill") }
                .tag(Tab.expenses)

            NavigationStack { RidesView() }
                .tabItem { Label("Rides", systemImage: "road.lanes") }
                .tag(Tab.rides)

            NavigationStack { SettingsView() }
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                .tag(Tab.settings)
        }
        .tint(.orange)
        .environmentObject(session)
        .environmentObject(navigation)
        .environmentObject(streamer)
        .onAppear {
            session.onButton = { [weak navigation] button in
                navigation?.handleDashButton(button)
            }
            navigation.startLocation()
        }
        .onOpenURL { url in
            navigation.importURL(url)
            selectedTab = .navigation
        }
    }
}

#Preview {
    RootView()
        .modelContainer(for: [Vehicle.self, Expense.self, FuelLog.self, MaintenanceRecord.self, RideRecord.self], inMemory: true)
}
