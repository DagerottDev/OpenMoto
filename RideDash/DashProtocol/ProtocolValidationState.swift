import Foundation

struct ProtocolValidationState: Codable, Sendable {
    var authenticationValidated = false
    var routeCardValidated = false
    var navigationInfoValidated = false
    var videoValidated = false
    var inputValidated = false
}
