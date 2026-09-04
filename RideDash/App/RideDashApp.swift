import SwiftData
import SwiftUI

@main
struct RideDashApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: [
            Vehicle.self,
            Expense.self,
            FuelLog.self,
            MaintenanceRecord.self,
            RideRecord.self
        ])
    }
}
