import Foundation

enum ProjectionControlPackets {
    static func authenticationRequest() throws -> Data {
        try HexCodec.data(from: DashProtocolConstants.requestAuthenticationHex)
    }

    static func navigationContext() throws -> Data {
        try HexCodec.data(from: DashProtocolConstants.navigationContextHex)
    }

    static func emptyNavigationLists() throws -> Data {
        try HexCodec.data(from: DashProtocolConstants.emptyNavigationListsHex)
    }

    static func startNavigation() throws -> Data {
        try HexCodec.data(from: DashProtocolConstants.startNavigationHex)
    }

    static func projectionFrame() throws -> Data {
        try HexCodec.data(from: DashProtocolConstants.projectionFrameHex)
    }

    static func projectionOn() throws -> Data {
        try HexCodec.data(from: DashProtocolConstants.projectionOnHex)
    }

    static func projectionStop() throws -> Data {
        try HexCodec.data(from: DashProtocolConstants.projectionStopHex)
    }

    static func projectionOff() throws -> Data {
        try HexCodec.data(from: DashProtocolConstants.projectionOffHex)
    }
}
