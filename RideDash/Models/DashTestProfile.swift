import Foundation
import UIKit

struct DashTestProfile: Codable, Equatable {
    var bikeModel: String
    var dashFirmware: String
    var dashSSID: String
    var dashHost: String
    var iPhoneModel: String
    var iOSVersion: String

    static var defaultProfile: DashTestProfile {
        DashTestProfile(
            bikeModel: "Test motorcycle",
            dashFirmware: "",
            dashSSID: "",
            dashHost: "192.168.1.1",
            iPhoneModel: UIDevice.current.model,
            iOSVersion: UIDevice.current.systemVersion
        )
    }
}
