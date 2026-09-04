import Foundation

enum DashProtocolConstants {
    // Public interoperability reference values. Keep centralized for firmware tuning.
    static let requestAuthenticationHex = "0016000200000000020100054B314720000804000101"
    static let navigationContextHex = "0016000200000000020100054B31472000052E00011E"
    static let emptyNavigationListsHex = "002A000600000000020100054B31472000052F0001000530000100053100010005320001000533000100"
    static let startNavigationHex = "0016000200000000020100054B31472000068000010B"
    static let projectionFrameHex = "0016000200000000020100054B314720000556000155"
    static let projectionOnHex = "0016000200000000020100054B314720000605000155"
    static let projectionStopHex = "0016000200000000020100054B3147200005560001AA"
    static let projectionOffHex = "0016000200000000020100054B3147200006050001AA"
    static let authenticationPayloadPrefixHex = "0095000200000000020100054B3147200008000080"

    static let buttonRight: UInt8 = 0x13
    static let buttonLeft: UInt8 = 0x14
    static let buttonDown: UInt8 = 0x15
    static let buttonClick: UInt8 = 0x18
    static let buttonAckPrefixHex = "0016000200000000020100054B3147200006800001"
}
