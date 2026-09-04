import Foundation
import SwiftData

enum ExpenseCategory: String, CaseIterable, Codable, Identifiable {
    case fuel, service, repair, accessory, gear, food, stay, transport, other
    var id: String { rawValue }
}

@Model
final class Expense {
    var id: UUID
    var date: Date
    var categoryRaw: String
    var amount: Double
    var odometerKM: Double?
    var note: String

    var category: ExpenseCategory {
        get { ExpenseCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }

    init(date: Date = .now, category: ExpenseCategory, amount: Double, odometerKM: Double? = nil, note: String = "") {
        id = UUID()
        self.date = date
        categoryRaw = category.rawValue
        self.amount = amount
        self.odometerKM = odometerKM
        self.note = note
    }
}

enum MaintenanceKind: String, CaseIterable, Codable, Identifiable {
    case service, chainClean, chainLube, tyre, brake, accessory, other
    var id: String { rawValue }
}

@Model
final class MaintenanceEntry {
    var id: UUID
    var date: Date
    var kindRaw: String
    var odometerKM: Double
    var note: String
    var nextDueKM: Double?
    var nextDueDate: Date?

    var kind: MaintenanceKind {
        get { MaintenanceKind(rawValue: kindRaw) ?? .other }
        set { kindRaw = newValue.rawValue }
    }

    init(date: Date = .now, kind: MaintenanceKind, odometerKM: Double, note: String = "", nextDueKM: Double? = nil, nextDueDate: Date? = nil) {
        id = UUID()
        self.date = date
        kindRaw = kind.rawValue
        self.odometerKM = odometerKM
        self.note = note
        self.nextDueKM = nextDueKM
        self.nextDueDate = nextDueDate
    }
}

@Model
final class FuelLog {
    var id: UUID
    var date: Date
    var odometerKM: Double
    var litres: Double
    var totalCost: Double
    var isFullTank: Bool

    init(date: Date = .now, odometerKM: Double, litres: Double, totalCost: Double, isFullTank: Bool) {
        id = UUID()
        self.date = date
        self.odometerKM = odometerKM
        self.litres = litres
        self.totalCost = totalCost
        self.isFullTank = isFullTank
    }
}

@Model
final class RideRecord {
    var id: UUID
    var startedAt: Date
    var endedAt: Date?
    var destination: String
    var distanceKM: Double
    var note: String

    init(startedAt: Date = .now, endedAt: Date? = nil, destination: String = "", distanceKM: Double = 0, note: String = "") {
        id = UUID()
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.destination = destination
        self.distanceKM = distanceKM
        self.note = note
    }
}
