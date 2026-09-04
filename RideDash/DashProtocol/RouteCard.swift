import Foundation

struct RouteCard: Sendable {
    var title: String
    var remainingDistanceMeters: Int
    var projectionOn: Bool

    init(title: String, remainingDistanceMeters: Int = 0, projectionOn: Bool = true) {
        self.title = title
        self.remainingDistanceMeters = remainingDistanceMeters
        self.projectionOn = projectionOn
    }
}
