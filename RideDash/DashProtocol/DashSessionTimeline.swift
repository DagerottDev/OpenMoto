import Foundation

struct DashSessionTimelineEntry: Identifiable, Sendable {
    let id = UUID()
    let timestamp = Date()
    let state: DashSessionState
    let message: String
}
