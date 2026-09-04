import Foundation

struct H264NALUnit: Sendable, Hashable {
    let data: Data

    var type: UInt8 { data.first.map { $0 & 0x1F } ?? 0 }
    var isIDR: Bool { type == 5 }
    var isSPS: Bool { type == 7 }
    var isPPS: Bool { type == 8 }
}

struct EncodedH264Frame: Sendable {
    let presentationTime: Double
    let isKeyFrame: Bool
    let nalUnits: [H264NALUnit]
}
