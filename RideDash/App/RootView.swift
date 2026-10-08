import CoreLocation
import SwiftData
import SwiftUI

struct RootView: View {
    typealias Tab = UsageAnalytics.Screen

    @Environment(\.modelContext) private var modelContext
    @StateObject private var session = DashSessionCoordinator()
    @StateObject private var navigation = NavigationViewModel()
    @StateObject private var streamer = ProjectionStreamer()
    @State private var selectedTab: Tab = .home
    @State private var activeRide: RideRecord?
    @State private var previousRideLocation: CLLocation?

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
            UsageAnalytics.shared.screenViewed(selectedTab)
        }
        .onChange(of: selectedTab) { _, tab in UsageAnalytics.shared.screenViewed(tab) }
        .onChange(of: session.state) { oldState, newState in
            handleSessionTransition(from: oldState, to: newState)
        }
        .onReceive(navigation.locationService.$location.compactMap { $0 }) { location in
            recordRideLocation(location)
        }
        .onOpenURL { url in
            navigation.importURL(url)
            selectedTab = .navigation
        }
    }

    private func handleSessionTransition(from oldState: DashSessionCoordinator.State, to newState: DashSessionCoordinator.State) {
        if newState == .projecting, activeRide == nil {
            let ride = RideRecord(
                startedAt: .now,
                destination: navigation.destination?.name ?? "",
                distanceKm: 0,
                notes: "Recorded automatically during display projection"
            )
            modelContext.insert(ride)
            activeRide = ride
            previousRideLocation = navigation.locationService.location
            session.log.append("Automatic ride recording started", category: "ride")
        }

        if oldState == .projecting, newState != .projecting, let ride = activeRide {
            ride.endedAt = .now
            activeRide = nil
            previousRideLocation = nil
            session.log.append(
                "Automatic ride recording stopped at \(String(format: "%.2f", ride.distanceKm)) km",
                category: "ride"
            )
        }
    }

    private func recordRideLocation(_ location: CLLocation) {
        guard let ride = activeRide,
              location.horizontalAccuracy >= 0,
              location.horizontalAccuracy <= 50 else { return }

        defer { previousRideLocation = location }
        guard let previousRideLocation else { return }

        let delta = location.distance(from: previousRideLocation)
        // Ignore GPS jitter and implausible one-sample jumps. Real route deviation is handled separately.
        guard delta >= 2, delta <= 500 else { return }
        ride.distanceKm += delta / 1_000
    }
}

#Preview {
    RootView()
        .modelContainer(for: [Vehicle.self, Expense.self, FuelLog.self, MaintenanceRecord.self, RideRecord.self], inMemory: true)
}
