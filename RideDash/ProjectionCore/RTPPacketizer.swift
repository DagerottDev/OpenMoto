import Foundation

struct RTPPacket: Sendable {
    let sequenceNumber: UInt16
    let timestamp: UInt32
    let marker: Bool
    let data: Data
}

final class RTPPacketizer {
    private var sequenceNumber: UInt16
    private let ssrc: UInt32
    private let payloadType: UInt8
    private let maxPayloadSize: Int

    init(
        initialSequence: UInt16 = UInt16.random(in: 0...UInt16.max),
        ssrc: UInt32 = UInt32.random(in: 1...UInt32.max),
        payloadType: UInt8 = 96,
        maxPayloadSize: Int = 1_180
    ) {
        self.sequenceNumber = initialSequence
        self.ssrc = ssrc
        self.payloadType = payloadType
        self.maxPayloadSize = max(256, maxPayloadSize)
    }

    func packetize(frame: EncodedH264Frame) -> [RTPPacket] {
        let scaled = max(0, frame.presentationTime) * 90_000
        let timestamp = UInt32(truncatingIfNeeded: UInt64(scaled.rounded()))
        var result: [RTPPacket] = []

        for (nalIndex, nal) in frame.nalUnits.enumerated() {
            let isFinalNAL = nalIndex == frame.nalUnits.count - 1
            if nal.data.count <= maxPayloadSize {
                result.append(makePacket(payload: nal.data, timestamp: timestamp, marker: isFinalNAL))
            } else {
                result.append(contentsOf: fragment(nal: nal, timestamp: timestamp, markerOnLast: isFinalNAL))
            }
        }
        return result
    }

    private func fragment(nal: H264NALUnit, timestamp: UInt32, markerOnLast: Bool) -> [RTPPacket] {
        guard let nalHeader = nal.data.first else { return [] }
        let payload = nal.data.dropFirst()
        let chunkSize = maxPayloadSize - 2
        let fuIndicator = (nalHeader & 0xE0) | 28
        let nalType = nalHeader & 0x1F

        var result: [RTPPacket] = []
        var offset = 0
        while offset < payload.count {
            let end = min(offset + chunkSize, payload.count)
            let isStart = offset == 0
            let isEnd = end == payload.count
            var fuHeader = nalType
            if isStart { fuHeader |= 0x80 }
            if isEnd { fuHeader |= 0x40 }

            var body = Data([fuIndicator, fuHeader])
            let lower = payload.index(payload.startIndex, offsetBy: offset)
            let upper = payload.index(payload.startIndex, offsetBy: end)
            body.append(contentsOf: payload[lower..<upper])
            result.append(
                makePacket(
                    payload: body,
                    timestamp: timestamp,
                    marker: markerOnLast && isEnd
                )
            )
            offset = end
        }
        return result
    }

    private func makePacket(payload: Data, timestamp: UInt32, marker: Bool) -> RTPPacket {
        let currentSequence = sequenceNumber
        sequenceNumber &+= 1

        var packet = Data(capacity: 12 + payload.count)
        packet.append(0x80) // RTP v2
        packet.append((marker ? 0x80 : 0x00) | (payloadType & 0x7F))
        appendUInt16(currentSequence, to: &packet)
        appendUInt32(timestamp, to: &packet)
        appendUInt32(ssrc, to: &packet)
        packet.append(payload)

        return RTPPacket(
            sequenceNumber: currentSequence,
            timestamp: timestamp,
            marker: marker,
            data: packet
        )
    }

    private func appendUInt16(_ value: UInt16, to data: inout Data) {
        data.append(UInt8((value >> 8) & 0xff))
        data.append(UInt8(value & 0xff))
    }

    private func appendUInt32(_ value: UInt32, to data: inout Data) {
        data.append(UInt8((value >> 24) & 0xff))
        data.append(UInt8((value >> 16) & 0xff))
        data.append(UInt8((value >> 8) & 0xff))
        data.append(UInt8(value & 0xff))
    }
}
