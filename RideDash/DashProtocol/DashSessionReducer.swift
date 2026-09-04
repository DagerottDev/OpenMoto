import Foundation

enum DashSessionReducer {
    static func reduce(state: DashSessionState, event: DashSessionEvent) -> DashSessionState {
        switch event {
        case .wifiJoinRequested: return .joiningWiFi
        case .networkSatisfied: return .networkReady
        case .transportReady: return .transportReady
        case .authenticationStarted: return .authenticating
        case .authenticationSucceeded: return .authenticated
        case .authenticationFailed: return .failed
        case .navigationReady: return .navigationReady
        case .projectionStarted: return .projecting
        case .projectionStopped: return .navigationReady
        case .input: return state
        case .transportLost: return .recovering
        }
    }
}
