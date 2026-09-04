import AVFoundation
import CoreGraphics
import CoreMedia
import CoreVideo
import Foundation
import UIKit
import VideoToolbox

struct ProjectionUIState: Sendable, Hashable {
    var destination: String = "RideDash"
    var maneuver: String = "Continue"
    var distanceToManeuver: String = "--"
    var eta: String = "--"
    var remainingDistance: String = "--"
    var speedKph: Double = 0
    var gpsAccuracy: Double? = nil
    var isCalibrationGrid = false
    var statusMessage: String? = nil
}

// MARK: - Frame renderer

final class DashFrameRenderer {
    let width: Int
    let height: Int

    init(width: Int = 526, height: Int = 300) {
        self.width = width
        self.height = height
    }

    func render(_ state: ProjectionUIState) throws -> CVPixelBuffer {
        var pixelBuffer: CVPixelBuffer?
        let attributes: [CFString: Any] = [
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true,
            kCVPixelBufferIOSurfacePropertiesKey: [:]
        ]
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32BGRA,
            attributes as CFDictionary,
            &pixelBuffer
        )
        guard status == kCVReturnSuccess, let pixelBuffer else {
            throw ProjectionError.pixelBufferCreationFailed(status)
        }

        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }
        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            throw ProjectionError.pixelBufferMissingBaseAddress
        }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: baseAddress,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        ) else {
            throw ProjectionError.contextCreationFailed
        }

        // CoreGraphics coordinates are flipped relative to UIKit text APIs.
        context.setFillColor(UIColor.black.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        UIGraphicsPushContext(context)
        defer { UIGraphicsPopContext() }

        if state.isCalibrationGrid {
            drawCalibration(in: context)
        } else {
            drawNavigation(state, in: context)
        }
        return pixelBuffer
    }

    private func drawCalibration(in context: CGContext) {
        let rect = CGRect(x: 0, y: 0, width: width, height: height)
        context.setStrokeColor(UIColor.white.withAlphaComponent(0.35).cgColor)
        context.setLineWidth(1)
        stride(from: 0, through: width, by: 25).forEach { x in
            context.move(to: CGPoint(x: x, y: 0))
            context.addLine(to: CGPoint(x: x, y: height))
        }
        stride(from: 0, through: height, by: 25).forEach { y in
            context.move(to: CGPoint(x: 0, y: y))
            context.addLine(to: CGPoint(x: width, y: y))
        }
        context.strokePath()

        context.setStrokeColor(UIColor.systemOrange.cgColor)
        context.setLineWidth(3)
        context.strokeEllipse(in: rect.insetBy(dx: 7, dy: 7))
        context.move(to: CGPoint(x: width / 2, y: 0))
        context.addLine(to: CGPoint(x: width / 2, y: height))
        context.move(to: CGPoint(x: 0, y: height / 2))
        context.addLine(to: CGPoint(x: width, y: height / 2))
        context.strokePath()

        drawText("526 × 300 CALIBRATION", frame: CGRect(x: 80, y: 125, width: 366, height: 40), size: 24, weight: .bold, alignment: .center)
    }

    private func drawNavigation(_ state: ProjectionUIState, in context: CGContext) {
        let safe = CGRect(x: 34, y: 22, width: width - 68, height: height - 44)

        // Destination header.
        drawText(state.destination, frame: CGRect(x: safe.minX + 12, y: safe.minY + 2, width: safe.width - 24, height: 30), size: 18, weight: .semibold, alignment: .center, color: .systemGray3)

        // Maneuver card.
        let card = CGRect(x: safe.minX + 34, y: safe.minY + 40, width: safe.width - 68, height: 104)
        let path = UIBezierPath(roundedRect: card, cornerRadius: 24)
        UIColor(white: 0.10, alpha: 1).setFill()
        path.fill()
        drawText(state.maneuver, frame: CGRect(x: card.minX + 16, y: card.minY + 13, width: card.width - 32, height: 42), size: 32, weight: .bold, alignment: .center)
        drawText(state.distanceToManeuver, frame: CGRect(x: card.minX + 16, y: card.minY + 58, width: card.width - 32, height: 32), size: 24, weight: .semibold, alignment: .center, color: .systemOrange)

        // Bottom glance row.
        drawMetric(title: "ETA", value: state.eta, x: safe.minX + 22, y: safe.maxY - 70, width: 105)
        drawMetric(title: "LEFT", value: state.remainingDistance, x: safe.midX - 52, y: safe.maxY - 70, width: 105)
        drawMetric(title: "SPEED", value: "\(Int(state.speedKph.rounded()))", x: safe.maxX - 127, y: safe.maxY - 70, width: 105)

        if let status = state.statusMessage {
            drawText(status, frame: CGRect(x: 90, y: height - 25, width: width - 180, height: 18), size: 11, weight: .medium, alignment: .center, color: .systemYellow)
        }
    }

    private func drawMetric(title: String, value: String, x: CGFloat, y: CGFloat, width: CGFloat) {
        drawText(title, frame: CGRect(x: x, y: y, width: width, height: 17), size: 11, weight: .semibold, alignment: .center, color: .systemGray)
        drawText(value, frame: CGRect(x: x, y: y + 16, width: width, height: 29), size: 19, weight: .bold, alignment: .center)
    }

    private func drawText(
        _ text: String,
        frame: CGRect,
        size: CGFloat,
        weight: UIFont.Weight,
        alignment: NSTextAlignment,
        color: UIColor = .white
    ) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment
        paragraph.lineBreakMode = .byTruncatingTail
        (text as NSString).draw(
            in: frame,
            withAttributes: [
                .font: UIFont.systemFont(ofSize: size, weight: weight),
                .foregroundColor: color,
                .paragraphStyle: paragraph
            ]
        )
    }
}

// MARK: - H.264

struct H264NALUnit: Sendable, Hashable {
    let bytes: Data
    let isParameterSet: Bool
}

final class H264Encoder {
    var onNALUnits: (@Sendable ([H264NALUnit], CMTime) -> Void)?

    private let width: Int32
    private let height: Int32
    private let fps: Int
    private let bitrate: Int
    private var session: VTCompressionSession?

    init(width: Int, height: Int, fps: Int, bitrateKbps: Int) throws {
        self.width = Int32(width)
        self.height = Int32(height)
        self.fps = max(1, fps)
        self.bitrate = max(64, bitrateKbps) * 1_000
        try configure()
    }

    deinit {
        if let session {
            VTCompressionSessionCompleteFrames(session, untilPresentationTimeStamp: .invalid)
            VTCompressionSessionInvalidate(session)
        }
    }

    func encode(_ pixelBuffer: CVPixelBuffer, pts: CMTime) throws {
        guard let session else { throw ProjectionError.encoderNotReady }
        var flags = VTEncodeInfoFlags()
        let status = VTCompressionSessionEncodeFrame(
            session,
            imageBuffer: pixelBuffer,
            presentationTimeStamp: pts,
            duration: CMTime(value: 1, timescale: CMTimeScale(fps)),
            frameProperties: nil,
            sourceFrameRefcon: nil,
            infoFlagsOut: &flags
        )
        guard status == noErr else { throw ProjectionError.videoToolbox(status) }
    }

    private func configure() throws {
        var created: VTCompressionSession?
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        let status = VTCompressionSessionCreate(
            allocator: kCFAllocatorDefault,
            width: width,
            height: height,
            codecType: kCMVideoCodecType_H264,
            encoderSpecification: nil,
            imageBufferAttributes: nil,
            compressedDataAllocator: nil,
            outputCallback: Self.outputCallback,
            refcon: refcon,
            compressionSessionOut: &created
        )
        guard status == noErr, let created else { throw ProjectionError.videoToolbox(status) }
        session = created

        try set(kVTCompressionPropertyKey_RealTime, value: kCFBooleanTrue)
        try set(kVTCompressionPropertyKey_ProfileLevel, value: kVTProfileLevel_H264_Baseline_AutoLevel)
        try set(kVTCompressionPropertyKey_AllowFrameReordering, value: kCFBooleanFalse)
        try set(kVTCompressionPropertyKey_AverageBitRate, value: bitrate as CFNumber)
        try set(kVTCompressionPropertyKey_ExpectedFrameRate, value: fps as CFNumber)
        try set(kVTCompressionPropertyKey_MaxKeyFrameInterval, value: (fps * 2) as CFNumber)
        let dataRate: [Int] = [bitrate / 8, 1]
        try set(kVTCompressionPropertyKey_DataRateLimits, value: dataRate as CFArray)
        let prepare = VTCompressionSessionPrepareToEncodeFrames(created)
        guard prepare == noErr else { throw ProjectionError.videoToolbox(prepare) }
    }

    private func set(_ key: CFString, value: CFTypeRef) throws {
        guard let session else { throw ProjectionError.encoderNotReady }
        let status = VTSessionSetProperty(session, key: key, value: value)
        guard status == noErr else { throw ProjectionError.videoToolbox(status) }
    }

    private static let outputCallback: VTCompressionOutputCallback = { refcon, _, status, _, sampleBuffer in
        guard status == noErr,
              let refcon,
              let sampleBuffer,
              CMSampleBufferDataIsReady(sampleBuffer) else { return }
        let encoder = Unmanaged<H264Encoder>.fromOpaque(refcon).takeUnretainedValue()
        encoder.consume(sampleBuffer)
    }

    private func consume(_ sampleBuffer: CMSampleBuffer) {
        var units: [H264NALUnit] = []
        let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false)
        let isKeyframe: Bool = {
            guard let attachments,
                  CFArrayGetCount(attachments) > 0,
                  let raw = CFArrayGetValueAtIndex(attachments, 0) else { return false }
            let dictionary = unsafeBitCast(raw, to: CFDictionary.self) as NSDictionary
            return dictionary[kCMSampleAttachmentKey_NotSync] == nil
        }()

        if isKeyframe, let format = CMSampleBufferGetFormatDescription(sampleBuffer) {
            for index in 0..<2 {
                var pointer: UnsafePointer<UInt8>?
                var size = 0
                var count = 0
                var headerLength: Int32 = 0
                let result = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(
                    format,
                    parameterSetIndex: index,
                    parameterSetPointerOut: &pointer,
                    parameterSetSizeOut: &size,
                    parameterSetCountOut: &count,
                    nalUnitHeaderLengthOut: &headerLength
                )
                if result == noErr, let pointer {
                    units.append(.init(bytes: Data(bytes: pointer, count: size), isParameterSet: true))
                }
            }
        }

        guard let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else { return }
        var totalLength = 0
        var lengthAtOffset = 0
        var pointer: UnsafeMutablePointer<Int8>?
        let status = CMBlockBufferGetDataPointer(
            blockBuffer,
            atOffset: 0,
            lengthAtOffsetOut: &lengthAtOffset,
            totalLengthOut: &totalLength,
            dataPointerOut: &pointer
        )
        guard status == kCMBlockBufferNoErr, let pointer else { return }

        let bytes = UnsafeRawPointer(pointer).assumingMemoryBound(to: UInt8.self)
        var offset = 0
        while offset + 4 <= totalLength {
            let nalLength = Int(bytes[offset]) << 24 |
                Int(bytes[offset + 1]) << 16 |
                Int(bytes[offset + 2]) << 8 |
                Int(bytes[offset + 3])
            offset += 4
            guard nalLength > 0, offset + nalLength <= totalLength else { break }
            units.append(.init(bytes: Data(bytes: bytes + offset, count: nalLength), isParameterSet: false))
            offset += nalLength
        }

        if !units.isEmpty {
            onNALUnits?(units, CMSampleBufferGetPresentationTimeStamp(sampleBuffer))
        }
    }
}

// MARK: - RTP packetizer

final class H264RTPPacketizer {
    private(set) var sequence: UInt16 = UInt16.random(in: 0...UInt16.max)
    private(set) var timestamp: UInt32 = UInt32.random(in: 0...UInt32.max)
    private let ssrc = UInt32.random(in: 1...UInt32.max)
    private let payloadType: UInt8 = 96
    private let maxPayload: Int
    private let timestampStep: UInt32

    init(fps: Int, maxPayload: Int = 1_180) {
        self.maxPayload = max(300, maxPayload)
        self.timestampStep = UInt32(90_000 / max(1, fps))
    }

    func packetize(_ units: [H264NALUnit]) -> [Data] {
        var packets: [Data] = []
        for (unitIndex, unit) in units.enumerated() {
            let isLastUnit = unitIndex == units.count - 1
            let bytes = unit.bytes
            guard let first = bytes.first else { continue }
            if bytes.count <= maxPayload {
                packets.append(makePacket(payload: bytes, marker: isLastUnit))
            } else {
                let nri = first & 0x60
                let forbidden = first & 0x80
                let nalType = first & 0x1F
                let fuIndicator = forbidden | nri | 28
                let body = bytes.dropFirst()
                let fragmentSize = maxPayload - 2
                var offset = 0
                while offset < body.count {
                    let end = min(body.count, offset + fragmentSize)
                    let startBit: UInt8 = offset == 0 ? 0x80 : 0
                    let endBit: UInt8 = end == body.count ? 0x40 : 0
                    let fuHeader = startBit | endBit | nalType
                    var payload = Data([fuIndicator, fuHeader])
                    payload.append(body[offset..<end])
                    packets.append(makePacket(payload: payload, marker: isLastUnit && end == body.count))
                    offset = end
                }
            }
        }
        timestamp &+= timestampStep
        return packets
    }

    private func makePacket(payload: Data, marker: Bool) -> Data {
        var packet = Data(capacity: 12 + payload.count)
        packet.append(0x80) // RTP v2
        packet.append((marker ? 0x80 : 0) | payloadType)
        appendBE(sequence, to: &packet)
        appendBE(timestamp, to: &packet)
        appendBE(ssrc, to: &packet)
        packet.append(payload)
        sequence &+= 1
        return packet
    }

    private func appendBE<T: FixedWidthInteger>(_ value: T, to data: inout Data) {
        var be = value.bigEndian
        withUnsafeBytes(of: &be) { data.append(contentsOf: $0) }
    }
}

// MARK: - End-to-end streamer

@MainActor
final class ProjectionStreamer: ObservableObject {
    enum State: Equatable { case stopped, starting, streaming, failed(String) }

    @Published private(set) var state: State = .stopped
    @Published private(set) var renderedFrames = 0
    @Published private(set) var sentRTPPackets = 0
    @Published private(set) var encodedBytes = 0

    private var renderTask: Task<Void, Never>?
    private var encoder: H264Encoder?
    private var packetizer: H264RTPPacketizer?
    private let renderer: DashFrameRenderer

    init(renderer: DashFrameRenderer = DashFrameRenderer()) {
        self.renderer = renderer
    }

    func start(
        coordinator: DashSessionCoordinator,
        profile: DashProtocolProfile,
        stateProvider: @escaping @MainActor () -> ProjectionUIState
    ) throws {
        stop()
        state = .starting
        let encoder = try H264Encoder(
            width: profile.renderWidth,
            height: profile.renderHeight,
            fps: profile.fps,
            bitrateKbps: profile.bitrateKbps
        )
        let packetizer = H264RTPPacketizer(fps: profile.fps)
        self.encoder = encoder
        self.packetizer = packetizer

        encoder.onNALUnits = { [weak self, weak coordinator] units, _ in
            guard let self, let coordinator else { return }
            let packets = packetizer.packetize(units)
            let byteCount = units.reduce(0) { $0 + $1.bytes.count }
            Task { @MainActor in
                self.encodedBytes += byteCount
                for packet in packets {
                    do {
                        try await coordinator.transport.sendVideo(packet)
                        self.sentRTPPackets += 1
                    } catch {
                        self.state = .failed(error.localizedDescription)
                        coordinator.log.append(error.localizedDescription, category: "rtp", level: .error)
                        return
                    }
                }
            }
        }

        coordinator.beginProjectionHeartbeat()
        state = .streaming
        let frameDuration = 1.0 / Double(max(1, profile.fps))
        renderTask = Task { [weak self] in
            var frame: Int64 = 0
            while !Task.isCancelled {
                guard let self else { return }
                do {
                    let buffer = try self.renderer.render(stateProvider())
                    let pts = CMTime(value: frame, timescale: CMTimeScale(max(1, profile.fps)))
                    try encoder.encode(buffer, pts: pts)
                    self.renderedFrames += 1
                    frame += 1
                } catch {
                    self.state = .failed(error.localizedDescription)
                    coordinator.log.append(error.localizedDescription, category: "encoder", level: .error)
                    return
                }
                try? await Task.sleep(for: .seconds(frameDuration))
            }
        }
    }

    func stop() {
        renderTask?.cancel()
        renderTask = nil
        encoder = nil
        packetizer = nil
        if case .failed = state { return }
        state = .stopped
    }
}

enum ProjectionError: LocalizedError {
    case pixelBufferCreationFailed(CVReturn)
    case pixelBufferMissingBaseAddress
    case contextCreationFailed
    case encoderNotReady
    case videoToolbox(OSStatus)

    var errorDescription: String? {
        switch self {
        case .pixelBufferCreationFailed(let status): return "Pixel buffer creation failed (\(status))."
        case .pixelBufferMissingBaseAddress: return "Pixel buffer has no writable base address."
        case .contextCreationFailed: return "Could not create the dash frame graphics context."
        case .encoderNotReady: return "H.264 encoder is not ready."
        case .videoToolbox(let status): return "VideoToolbox returned status \(status)."
        }
    }
}
