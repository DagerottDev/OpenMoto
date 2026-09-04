import Foundation

enum DashSessionCommand: Sendable {
    case requestAuthentication
    case enterNavigation
    case startProjection
    case stopProjection
    case acknowledgeInput(DashInputEvent)
}
