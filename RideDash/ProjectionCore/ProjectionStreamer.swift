import Combine
import CoreMedia
import Foundation

@MainActor
final class ProjectionStreamer: ObservableObject {
    @Published private(set) var isRunning = false
    @Published private(set) var encodedFrameCount = 0
    @Published private(set) var sentPacketCount = 0
    @Published private(set) var lastError: String?

    private let transport: DashDatagramTransport
    private let configuration: DashProtocolConfiguration
    private let renderer: DashRenderer
    private let packetizer = RTPPacketizer()
    private var encoder: H264Encoder?
    private var renderTask: Task<Void, Never>?
    private var stateProvider: (() -> ProjectionUIState)?

    init(
        transport: DashDatagramTransport,
        configuration: DashProtocolConfiguration
    ) {
        self.transport = transport
        self.configuration = configuration
        renderer = DashRenderer(width: configuration.renderWidth, height: configuration.renderHeight)
    }

    func start(stateProvider: @escaping () -> ProjectionUIState) throws {
        stop()
        self.stateProvider = stateProvider

        let encoder = try H264Encoder(
            width: configuration.renderWidth,
            height: configuration.renderHeight,
            fps: configuration.projectionFPS,
            bitrate: configuration.videoBitrate
        )
        encoder.onEncodedFrame = { [weak self] frame in
            Task { @MainActor in
                await self?.handle(frame)
            }
        }
        encoder.onError = { [weak self] error in
            Task { @MainActor in self?.lastError = error.localizedDescription }
        }
        self.encoder = encoder
        isRunning = true

        let fps = max(1, configuration.projectionFPS)
        let frameDuration = 1.0 / fps
        let timescale = Int32(max(1, fps.rounded()))

        renderTask = Task { [weak self] in
            guard let self else { return }
            var frameIndex: Int64 = 0
            while !Task.isCancelled, self.isRunning {
                do {
                    guard let provider = self.stateProvider,
                          let encoder = self.encoder else { break }
                    let pixelBuffer = try self.renderer.render(provider())
                    try encoder.encode(
                        pixelBuffer,
                        presentationTime: CMTime(value: frameIndex, timescale: timescale)
                    )
                    frameIndex += 1
                } catch {
                    self.lastError = error.localizedDescription
                }

                do {
                    try await Task.sleep(for: .seconds(frameDuration))
                } catch {
                    break
                }
            }
        }
    }

    func stop() {
        isRunning = false
        renderTask?.cancel()
        renderTask = nil
        encoder?.completeFrames()
        encoder?.invalidate()
        encoder = nil
        stateProvider = nil
    }

    private func handle(_ frame: EncodedH264Frame) async {
        encodedFrameCount += 1
        let packets = packetizer.packetize(frame: frame)
        for packet in packets {
            do {
                try await transport.sendVideo(packet.data)
                sentPacketCount += 1
            } catch {
                lastError = error.localizedDescription
                break
            }
        }
    }
}
