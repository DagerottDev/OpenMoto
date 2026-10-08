import CoreGraphics
import CoreMedia
import CoreVideo
import Foundation
import UIKit
import VideoToolbox

struct ProjectionUIState: Sendable, Hashable {
    var destination = "OpenMoto"
    var maneuver = "Continue"
    var distanceToManeuver = "--"
    var eta = "--"
    var remainingDistance = "--"
    var speedKph: Double = 0
    var gpsAccuracy: Double?
    var isCalibrationGrid = false
    var statusMessage: String?
}

// MARK: - 526 × 300 renderer

final class DashFrameRenderer {
    let width: Int
    let height: Int

    init(width: Int = 526, height: Int = 300) {
        self.width = width
        self.height = height
    }

    func render(_ state: ProjectionUIState) throws -> CVPixelBuffer {
        var buffer: CVPixelBuffer?
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
            &buffer
        )
        guard status == kCVReturnSuccess, let buffer else {
            throw ProjectionError.pixelBufferCreationFailed(status)
        }

        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        guard let base = CVPixelBufferGetBaseAddress(buffer) else {
            throw ProjectionError.pixelBufferMissingBaseAddress
        }

        guard let context = CGContext(
            data: base,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        ) else {
            throw ProjectionError.contextCreationFailed
        }

        context.setFillColor(UIColor.black.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height)))
        UIGraphicsPushContext(context)
        defer { UIGraphicsPopContext() }

        if state.isCalibrationGrid {
            drawCalibration(context)
        } else {
            drawNavigation(state)
        }
        return buffer
    }

    private func drawCalibration(_ context: CGContext) {
        let w = CGFloat(width)
        let h = CGFloat(height)
        context.setStrokeColor(UIColor.white.withAlphaComponent(0.32).cgColor)
        context.setLineWidth(1)
        stride(from: 0, through: width, by: 25).forEach { x in
            context.move(to: CGPoint(x: CGFloat(x), y: 0))
            context.addLine(to: CGPoint(x: CGFloat(x), y: h))
        }
        stride(from: 0, through: height, by: 25).forEach { y in
            context.move(to: CGPoint(x: 0, y: CGFloat(y)))
            context.addLine(to: CGPoint(x: w, y: CGFloat(y)))
        }
        context.strokePath()

        context.setStrokeColor(UIColor.systemOrange.cgColor)
        context.setLineWidth(3)
        context.strokeEllipse(in: CGRect(x: 7, y: 7, width: w - 14, height: h - 14))
        context.move(to: CGPoint(x: w / 2, y: 0))
        context.addLine(to: CGPoint(x: w / 2, y: h))
        context.move(to: CGPoint(x: 0, y: h / 2))
        context.addLine(to: CGPoint(x: w, y: h / 2))
        context.strokePath()

        drawText(
            "526 × 300 CALIBRATION",
            frame: CGRect(x: 70, y: 124, width: w - 140, height: 42),
            size: 24,
            weight: .bold,
            alignment: .center
        )
    }

    private func drawNavigation(_ state: ProjectionUIState) {
        let w = CGFloat(width)
        let h = CGFloat(height)
        let safe = CGRect(x: 34, y: 22, width: w - 68, height: h - 44)

        drawText(
            state.destination,
            frame: CGRect(x: safe.minX + 12, y: safe.minY + 2, width: safe.width - 24, height: 30),
            size: 18,
            weight: .semibold,
            alignment: .center,
            color: .systemGray3
        )

        let card = CGRect(x: safe.minX + 34, y: safe.minY + 40, width: safe.width - 68, height: 104)
        UIColor(white: 0.10, alpha: 1).setFill()
        UIBezierPath(roundedRect: card, cornerRadius: 24).fill()

        drawText(
            state.maneuver,
            frame: CGRect(x: card.minX + 16, y: card.minY + 13, width: card.width - 32, height: 42),
            size: 30,
            weight: .bold,
            alignment: .center
        )
        drawText(
            state.distanceToManeuver,
            frame: CGRect(x: card.minX + 16, y: card.minY + 58, width: card.width - 32, height: 32),
            size: 24,
            weight: .semibold,
            alignment: .center,
            color: .systemOrange
        )

        drawMetric(title: "ETA", value: state.eta, x: safe.minX + 22, y: safe.maxY - 70, width: 105)
        drawMetric(title: "LEFT", value: state.remainingDistance, x: safe.midX - 52, y: safe.maxY - 70, width: 105)
        drawMetric(title: "SPEED", value: String(Int(state.speedKph.rounded())), x: safe.maxX - 127, y: safe.maxY - 70, width: 105)

        if let status = state.statusMessage {
            drawText(
                status,
                frame: CGRect(x: 80, y: h - 24, width: w - 160, height: 17),
                size: 11,
                weight: .medium,
                alignment: .center,
                color: .systemYellow
            )
        }
    }

    private func drawMetric(title: String, value: String, x: CGFloat, y: CGFloat, width: CGFloat) {
        drawText(title, frame: CGRect(x: x, y: y, width: width, height: 17), size: 11, weight: .semibold, alignment: .center, color: .systemGray)
        drawText(value, frame: CGRect(x: x, y: y + 16, width: width, height: 29), size: 19, weight: .bold, alignment: .center)
    }

    private func drawText(
        _ value: String,
        frame: CGRect,
        size: CGFloat,
        weight: UIFont.Weight,
        alignment: NSTextAlignment,
        color: UIColor = .white
    ) {
        let style = NSMutableParagraphStyle()
        style.alignment = alignment
        style.lineBreakMode = .byTruncatingTail
        (value as NSString).draw(
            in: frame,
            withAttributes: [
                .font: UIFont.systemFont(ofSize: size, weight: weight),
                .foregroundColor: color,
                .paragraphStyle: style
            ]
        )
    }
}

// MARK: - H.264 encoder

struct H264NALUnit: Sendable, Hashable {
    let bytes: Data
    let isParameterSet: Bool

    var type: UInt8 { (bytes.first ?? 0) & 0x1F }
}

final class H264Encoder {
    var onNALUnits: (([H264NALUnit], CMTime) -> Void)?

    private let fps: Int
    private let bitrate: Int
    private var session: VTCompressionSession?

    init(width: Int, height: Int, fps: Int, bitrateKbps: Int) throws {
        self.fps = max(1, fps)
        self.bitrate = max(64, bitrateKbps) * 1_000
        try configure(width: Int32(width), height: Int32(height))
    }

    deinit {
        if let session {
            VTCompressionSessionCompleteFrames(session, untilPresentationTimeStamp: CMTime.invalid)
            VTCompressionSessionInvalidate(session)
        }
    }

    func encode(_ buffer: CVPixelBuffer, pts: CMTime) throws {
        guard let session else { throw ProjectionError.encoderNotReady }
        var flags = VTEncodeInfoFlags()
        let status = VTCompressionSessionEncodeFrame(
            session,
            imageBuffer: buffer,
            presentationTimeStamp: pts,
            duration: CMTime(value: 1, timescale: CMTimeScale(fps)),
            frameProperties: nil,
            sourceFrameRefcon: nil,
            infoFlagsOut: &flags
        )
        guard status == noErr else { throw ProjectionError.videoToolbox(status) }
    }

    private func configure(width: Int32, height: Int32) throws {
        var created: VTCompressionSession?
        let status = VTCompressionSessionCreate(
            allocator: kCFAllocatorDefault,
            width: width,
            height: height,
            codecType: kCMVideoCodecType_H264,
            encoderSpecification: nil,
            imageBufferAttributes: nil,
            compressedDataAllocator: nil,
            outputCallback: Self.outputCallback,
            refcon: Unmanaged.passUnretained(self).toOpaque(),
            compressionSessionOut: &created
        )
        guard status == noErr, let created else { throw ProjectionError.videoToolbox(status) }
        session = created

        try set(kVTCompressionPropertyKey_RealTime, kCFBooleanTrue)
        try set(kVTCompressionPropertyKey_ProfileLevel, kVTProfileLevel_H264_Baseline_AutoLevel)
        try set(kVTCompressionPropertyKey_AllowFrameReordering, kCFBooleanFalse)
        try set(kVTCompressionPropertyKey_AverageBitRate, NSNumber(value: bitrate))
        try set(kVTCompressionPropertyKey_ExpectedFrameRate, NSNumber(value: fps))
        try set(kVTCompressionPropertyKey_MaxKeyFrameInterval, NSNumber(value: fps * 2))
        let rateLimits = [NSNumber(value: bitrate / 8), NSNumber(value: 1)] as CFArray
        try set(kVTCompressionPropertyKey_DataRateLimits, rateLimits)

        let prepare = VTCompressionSessionPrepareToEncodeFrames(created)
        guard prepare == noErr else { throw ProjectionError.videoToolbox(prepare) }
    }

    private func set(_ key: CFString, _ value: CFTypeRef) throws {
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

        // Ask VideoToolbox for the SPS/PPS matching the current encoder output.
        if let format = CMSampleBufferGetFormatDescription(sampleBuffer) {
            for index in 0..<2 {
                var pointer: UnsafePointer<UInt8>?
                var size = 0
                var setCount = 0
                var headerLength: Int32 = 0
                let result = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(
                    format,
                    parameterSetIndex: index,
                    parameterSetPointerOut: &pointer,
                    parameterSetSizeOut: &size,
                    parameterSetCountOut: &setCount,
                    nalUnitHeaderLengthOut: &headerLength
                )
                if result == noErr, let pointer, size > 0 {
                    units.append(H264NALUnit(bytes: Data(bytes: pointer, count: size), isParameterSet: true))
                }
            }
        }

        guard let block = CMSampleBufferGetDataBuffer(sampleBuffer) else { return }
        var totalLength = 0
        var contiguousLength = 0
        var pointer: UnsafeMutablePointer<Int8>?
        let pointerStatus = CMBlockBufferGetDataPointer(
            block,
            atOffset: 0,
            lengthAtOffsetOut: &contiguousLength,
            totalLengthOut: &totalLength,
            dataPointerOut: &pointer
        )
        guard pointerStatus == kCMBlockBufferNoErr, let pointer else { return }

        let bytes = UnsafeRawPointer(pointer).assumingMemoryBound(to: UInt8.self)
        var offset = 0
        while offset + 4 <= totalLength {
            let length = Int(bytes[offset]) << 24 |
                Int(bytes[offset + 1]) << 16 |
                Int(bytes[offset + 2]) << 8 |
                Int(bytes[offset + 3])
            offset += 4
            guard length > 0, offset + length <= totalLength else { break }
            units.append(
                H264NALUnit(
                    bytes: Data(bytes: bytes.advanced(by: offset), count: length),
                    isParameterSet: false
                )
            )
            offset += length
        }

        if !units.isEmpty {
            onNALUnits?(units, CMSampleBufferGetPresentationTimeStamp(sampleBuffer))
        }
    }
}

// MARK: - Dash-compatible H.264/RTP

final class H264RTPPacketizer {
    private var sequence = UInt16.random(in: 0...UInt16.max)
    private var timestamp = UInt32.random(in: 0...UInt32.max)
    private let ssrc = UInt32.random(in: 1...UInt32.max)
    private let payloadType: UInt8 = 96
    private let timestampStep: UInt32
    private let maxPayload: Int

    private var sps: Data?
    private var pps: Data?

    /// The working public reference uses ~1380 bytes. Keep it configurable if firmware needs tuning.
    init(fps: Int, maxPayload: Int = 1_380) {
        timestampStep = UInt32(90_000 / max(1, fps))
        self.maxPayload = max(300, maxPayload)
    }

    func packetize(_ units: [H264NALUnit]) -> [Data] {
        var frameNALs: [Data] = []

        for unit in units where !unit.bytes.isEmpty {
            switch unit.type {
            case 7:
                sps = unit.bytes
            case 8:
                pps = unit.bytes
            case 6, 9:
                // Drop SEI/AUD. The reference does not send them to the embedded decoder.
                continue
            case 5:
                if let sps, let pps {
                    var bundled = Data()
                    bundled.append(sps)
                    bundled.append(contentsOf: [0x00, 0x00, 0x00, 0x01])
                    bundled.append(pps)
                    bundled.append(contentsOf: [0x00, 0x00, 0x00, 0x01])
                    bundled.append(unit.bytes)
                    frameNALs.append(bundled)
                } else {
                    frameNALs.append(unit.bytes)
                }
            default:
                frameNALs.append(unit.bytes)
            }
        }

        guard !frameNALs.isEmpty else { return [] }
        var plannedPayloads: [Data] = []
        for nal in frameNALs {
            plannedPayloads.append(contentsOf: payloads(for: nal))
        }

        var result: [Data] = []
        result.reserveCapacity(plannedPayloads.count)
        for index in plannedPayloads.indices {
            result.append(makeRTPPacket(payload: plannedPayloads[index], marker: index == plannedPayloads.count - 1))
        }
        timestamp &+= timestampStep
        return result
    }

    private func payloads(for nal: Data) -> [Data] {
        guard let first = nal.first else { return [] }
        if nal.count <= maxPayload { return [nal] }

        let fuIndicator = (first & 0xE0) | 28
        let nalType = first & 0x1F
        let body = Data(nal.dropFirst())
        let chunkSize = maxPayload - 2
        var result: [Data] = []
        var offset = 0

        while offset < body.count {
            let end = min(body.count, offset + chunkSize)
            let startBit: UInt8 = offset == 0 ? 0x80 : 0
            let endBit: UInt8 = end == body.count ? 0x40 : 0
            let fuHeader = startBit | endBit | nalType
            var payload = Data([fuIndicator, fuHeader])
            payload.append(body.subdata(in: offset..<end))
            result.append(payload)
            offset = end
        }
        return result
    }

    private func makeRTPPacket(payload: Data, marker: Bool) -> Data {
        var packet = Data(capacity: 12 + payload.count)
        packet.append(0x80) // RTP v2
        packet.append((marker ? 0x80 : 0) | payloadType)
        appendBigEndian(sequence, to: &packet)
        appendBigEndian(timestamp, to: &packet)
        appendBigEndian(ssrc, to: &packet)
        packet.append(payload)
        sequence &+= 1
        return packet
    }

    private func appendBigEndian<T: FixedWidthInteger>(_ value: T, to data: inout Data) {
        var big = value.bigEndian
        withUnsafeBytes(of: &big) { data.append(contentsOf: $0) }
    }
}

// MARK: - Renderer → encoder → RTP → UDP

@MainActor
final class ProjectionStreamer: ObservableObject {
    enum State: Equatable {
        case stopped
        case starting
        case streaming
        case failed(String)
    }

    @Published private(set) var state: State = .stopped
    @Published private(set) var renderedFrames = 0
    @Published private(set) var sentRTPPackets = 0
    @Published private(set) var encodedBytes = 0

    private var renderTask: Task<Void, Never>?
    private var encoder: H264Encoder?
    private var packetizer: H264RTPPacketizer?
    private var renderer = DashFrameRenderer()

    func start(
        coordinator: DashSessionCoordinator,
        profile: DashProtocolProfile,
        stateProvider: @escaping @MainActor () -> ProjectionUIState
    ) throws {
        stop()
        state = .starting
        renderedFrames = 0
        sentRTPPackets = 0
        encodedBytes = 0

        renderer = DashFrameRenderer(width: profile.renderWidth, height: profile.renderHeight)
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
            let bytes = units.reduce(0) { $0 + $1.bytes.count }
            Task { @MainActor in
                self.encodedBytes += bytes
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
        let fps = max(1, profile.fps)
        let frameInterval = 1.0 / Double(fps)

        renderTask = Task { [weak self, weak coordinator] in
            guard let coordinator else { return }
            var frameNumber: Int64 = 0
            while !Task.isCancelled {
                guard let self else { return }
                do {
                    let pixelBuffer = try self.renderer.render(stateProvider())
                    let pts = CMTime(value: frameNumber, timescale: CMTimeScale(fps))
                    try encoder.encode(pixelBuffer, pts: pts)
                    self.renderedFrames += 1
                    frameNumber += 1
                } catch {
                    self.state = .failed(error.localizedDescription)
                    coordinator.log.append(error.localizedDescription, category: "encoder", level: .error)
                    return
                }
                try? await Task.sleep(for: .seconds(frameInterval))
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
        case .contextCreationFailed: return "Could not create the dash graphics context."
        case .encoderNotReady: return "H.264 encoder is not ready."
        case .videoToolbox(let status): return "VideoToolbox returned status \(status)."
        }
    }
}
