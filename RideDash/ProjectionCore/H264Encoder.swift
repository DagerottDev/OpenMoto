import CoreMedia
import Foundation
import VideoToolbox

final class H264Encoder {
    var onEncodedFrame: ((EncodedH264Frame) -> Void)?
    var onError: ((Error) -> Void)?

    private var session: VTCompressionSession?
    private let width: Int32
    private let height: Int32
    private let fps: Int32
    private let bitrate: Int

    init(width: Int, height: Int, fps: Double, bitrate: Int) throws {
        self.width = Int32(width)
        self.height = Int32(height)
        self.fps = Int32(max(1, fps.rounded()))
        self.bitrate = bitrate
        try configure()
    }

    deinit { invalidate() }

    func encode(_ pixelBuffer: CVPixelBuffer, presentationTime: CMTime) throws {
        guard let session else { throw H264EncoderError.sessionUnavailable }
        var flags = VTEncodeInfoFlags()
        let status = VTCompressionSessionEncodeFrame(
            session,
            imageBuffer: pixelBuffer,
            presentationTimeStamp: presentationTime,
            duration: CMTime(value: 1, timescale: fps),
            frameProperties: nil,
            sourceFrameRefcon: nil,
            infoFlagsOut: &flags
        )
        guard status == noErr else { throw H264EncoderError.encodeFailed(status) }
    }

    func completeFrames() {
        if let session {
            VTCompressionSessionCompleteFrames(session, untilPresentationTimeStamp: .invalid)
        }
    }

    func invalidate() {
        if let session {
            VTCompressionSessionInvalidate(session)
            self.session = nil
        }
    }

    private func configure() throws {
        var created: VTCompressionSession?
        let status = VTCompressionSessionCreate(
            allocator: kCFAllocatorDefault,
            width: width,
            height: height,
            codecType: kCMVideoCodecType_H264,
            encoderSpecification: nil,
            imageBufferAttributes: nil,
            compressedDataAllocator: nil,
            outputCallback: h264OutputCallback,
            refcon: Unmanaged.passUnretained(self).toOpaque(),
            compressionSessionOut: &created
        )
        guard status == noErr, let created else {
            throw H264EncoderError.sessionCreationFailed(status)
        }
        session = created

        set(kVTCompressionPropertyKey_RealTime, value: kCFBooleanTrue)
        set(kVTCompressionPropertyKey_AllowFrameReordering, value: kCFBooleanFalse)
        set(kVTCompressionPropertyKey_AverageBitRate, value: NSNumber(value: bitrate))
        set(kVTCompressionPropertyKey_ExpectedFrameRate, value: NSNumber(value: fps))
        set(kVTCompressionPropertyKey_MaxKeyFrameInterval, value: NSNumber(value: max(1, fps * 2)))
        set(kVTCompressionPropertyKey_ProfileLevel, value: kVTProfileLevel_H264_Baseline_AutoLevel)

        let prepareStatus = VTCompressionSessionPrepareToEncodeFrames(created)
        guard prepareStatus == noErr else {
            throw H264EncoderError.prepareFailed(prepareStatus)
        }
    }

    private func set(_ key: CFString, value: CFTypeRef) {
        guard let session else { return }
        VTSessionSetProperty(session, key: key, value: value)
    }

    fileprivate func handle(status: OSStatus, sampleBuffer: CMSampleBuffer?) {
        guard status == noErr else {
            onError?(H264EncoderError.encodeFailed(status))
            return
        }
        guard let sampleBuffer, CMSampleBufferDataIsReady(sampleBuffer) else { return }

        let isKeyFrame: Bool = {
            guard let attachments = CMSampleBufferGetSampleAttachmentsArray(
                sampleBuffer,
                createIfNecessary: false
            ) as? [[CFString: Any]], let first = attachments.first else { return false }
            return first[kCMSampleAttachmentKey_NotSync] == nil
        }()

        var nalUnits: [H264NALUnit] = []
        if isKeyFrame, let format = CMSampleBufferGetFormatDescription(sampleBuffer) {
            nalUnits.append(contentsOf: parameterSets(from: format))
        }
        nalUnits.append(contentsOf: avccNALUnits(from: sampleBuffer))

        guard !nalUnits.isEmpty else { return }
        let pts = CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sampleBuffer))
        onEncodedFrame?(
            EncodedH264Frame(
                presentationTime: pts.isFinite ? pts : 0,
                isKeyFrame: isKeyFrame,
                nalUnits: nalUnits
            )
        )
    }

    private func parameterSets(from format: CMFormatDescription) -> [H264NALUnit] {
        var result: [H264NALUnit] = []
        for index in 0..<2 {
            var pointer: UnsafePointer<UInt8>?
            var size = 0
            var count = 0
            var headerLength: Int32 = 0
            let status = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(
                format,
                parameterSetIndex: index,
                parameterSetPointerOut: &pointer,
                parameterSetSizeOut: &size,
                parameterSetCountOut: &count,
                nalUnitHeaderLengthOut: &headerLength
            )
            if status == noErr, let pointer, size > 0 {
                result.append(H264NALUnit(data: Data(bytes: pointer, count: size)))
            }
        }
        return result
    }

    private func avccNALUnits(from sampleBuffer: CMSampleBuffer) -> [H264NALUnit] {
        guard let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else { return [] }
        let totalLength = CMBlockBufferGetDataLength(blockBuffer)
        guard totalLength > 4 else { return [] }

        var bytes = Data(count: totalLength)
        let status = bytes.withUnsafeMutableBytes { destination in
            CMBlockBufferCopyDataBytes(
                blockBuffer,
                atOffset: 0,
                dataLength: totalLength,
                destination: destination.baseAddress!
            )
        }
        guard status == kCMBlockBufferNoErr else { return [] }

        var result: [H264NALUnit] = []
        var offset = 0
        while offset + 4 <= bytes.count {
            let length = bytes[offset..<(offset + 4)].reduce(0) { ($0 << 8) | Int($1) }
            offset += 4
            guard length > 0, offset + length <= bytes.count else { break }
            result.append(H264NALUnit(data: bytes.subdata(in: offset..<(offset + length))))
            offset += length
        }
        return result
    }
}

private let h264OutputCallback: VTCompressionOutputCallback = { refcon, _, status, _, sampleBuffer in
    guard let refcon else { return }
    let encoder = Unmanaged<H264Encoder>.fromOpaque(refcon).takeUnretainedValue()
    encoder.handle(status: status, sampleBuffer: sampleBuffer)
}

enum H264EncoderError: LocalizedError {
    case sessionCreationFailed(OSStatus)
    case prepareFailed(OSStatus)
    case encodeFailed(OSStatus)
    case sessionUnavailable

    var errorDescription: String? {
        switch self {
        case .sessionCreationFailed(let code): return "H.264 session creation failed (\(code))."
        case .prepareFailed(let code): return "H.264 encoder prepare failed (\(code))."
        case .encodeFailed(let code): return "H.264 encode failed (\(code))."
        case .sessionUnavailable: return "H.264 encoder session is unavailable."
        }
    }
}
