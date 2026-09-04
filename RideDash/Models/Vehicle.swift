import Foundation
import SwiftData

@Model
final class Vehicle {
    var id: UUID
    var name: String
    var registrationNumber: String
    var odometerKM: Double
    var insuranceExpiry: Date?
    var pollutionCertificateExpiry: Date?
    var lastServiceDate: Date?
    var isActive: Bool

    init(
        name: String,
        registrationNumber: String = "",
        odometerKM: Double = 0,
        insuranceExpiry: Date? = nil,
        pollutionCertificateExpiry: Date? = nil,
        lastServiceDate: Date? = nil,
        isActive: Bool = false
    ) {
        id = UUID()
        self.name = name
        self.registrationNumber = registrationNumber
        self.odometerKM = odometerKM
        self.insuranceExpiry = insuranceExpiry
        self.pollutionCertificateExpiry = pollutionCertificateExpiry
        self.lastServiceDate = lastServiceDate
        self.isActive = isActive
    }
}
