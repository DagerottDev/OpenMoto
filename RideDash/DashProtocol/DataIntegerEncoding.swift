import Foundation

enum DataIntegerEncoding {
    static func stripLeadingZeroes(_ data: Data) -> Data {
        let bytes = data.drop { $0 == 0 }
        return bytes.isEmpty ? Data([0]) : Data(bytes)
    }
}
