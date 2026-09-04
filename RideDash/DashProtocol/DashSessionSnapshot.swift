import Foundation

struct DashSessionSnapshot: Sendable {
    var state: DashSessionState
    var lastError: String?
    var metrics: DashSessionMetrics
    var compatibility: DashCompatibilityProfile
}
