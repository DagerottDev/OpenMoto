import Combine
import SwiftUI
import UIKit

struct DiagnosticsView: View {
    @StateObject private var wiFiManager = TripperWiFiManager()
    @StateObject private var networkMonitor = LocalNetworkMonitor()
    @StateObject private var transport = DashTransport()
    @StateObject private var log = DiagnosticLog()
    @StateObject private var deviceHealth = DeviceHealthMonitor()

    @AppStorage("dash.test.bikeModel") private var bikeModel = "Test motorcycle"
    @AppStorage("dash.test.firmware") private var dashFirmware = ""
    @AppStorage("dash.test.ssid") private var dashSSID = ""
    @AppStorage("dash.test.host") private var dashHost = "192.168.1.1"
    @AppStorage("dash.test.port") private var dashPort = 2000

    @State private var passphrase = ""
    @State private var selfCheckResult: ProtocolSelfCheck.Result?

    private var profile: DashTestProfile {
        var profile = DashTestProfile.defaultProfile
        profile.bikeModel = bikeModel
        profile.dashFirmware = dashFirmware
        profile.dashSSID = dashSSID
        profile.dashHost = dashHost
        return profile
    }

    var body: some View {
        Form {
            hardwareSection
            deviceHealthSection
            wiFiSection
            networkSection
            transportSection
            selfCheckSection
            logSection
        }
        .navigationTitle("Dash Diagnostics")
        .onAppear {
            networkMonitor.start()
            deviceHealth.start()
            log.append("Diagnostics screen opened", category: "app")
            logDeviceHealth()
        }
        .onDisappear {
            transport.stop()
            deviceHealth.stop()
        }
        .onChange(of: networkMonitor.statusText) { _, newValue in
            log.append("Path status: \(newValue); Wi-Fi=\(networkMonitor.usesWiFi)", category: "network")
        }
        .onChange(of: transport.state) { _, newValue in
            log.append("Transport: \(newValue.description)", category: "udp")
        }
        .onChange(of: deviceHealth.thermalStateText) { _, _ in logDeviceHealth() }
    }

    private var hardwareSection: some View {
        Section("Hardware test profile") {
            TextField("Motorcycle model", text: $bikeModel)
            TextField("Display firmware", text: $dashFirmware)
                .textInputAutocapitalization(.never)
            LabeledContent("Phone", value: profile.iPhoneModel)
            LabeledContent("iOS", value: profile.iOSVersion)
        }
    }

    private var deviceHealthSection: some View {
        Section {
            LabeledContent("Thermal", value: deviceHealth.thermalStateText)
            LabeledContent("Battery", value: deviceHealth.batteryLevelText)
            LabeledContent("Battery state", value: deviceHealth.batteryStateText)
            LabeledContent("Low Power Mode", value: deviceHealth.lowPowerMode ? "On" : "Off")
        } header: {
            Text("Device health")
        } footer: {
            Text("Use these values during 30/60/120-minute projection tests to correlate throttling, battery drain and stream instability.")
        }
    }

    private var wiFiSection: some View {
        Section {
            TextField("Display Wi-Fi SSID", text: $dashSSID)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            SecureField("Wi-Fi password (if required)", text: $passphrase)

            Button("Request Wi-Fi Join") {
                Task {
                    log.append("Wi-Fi join requested for configured display SSID", category: "wifi")
                    do {
                        try await wiFiManager.join(ssid: dashSSID, passphrase: passphrase)
                        log.append("Wi-Fi join request completed", category: "wifi")
                        passphrase = ""
                    } catch {
                        log.append(error.localizedDescription, category: "wifi", level: .error)
                    }
                }
            }
            .disabled(dashSSID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            Button("Remove Saved Configuration", role: .destructive) {
                Task {
                    await wiFiManager.removeConfiguration(forSSID: dashSSID)
                    log.append("Removed app-managed Wi-Fi configuration", category: "wifi")
                }
            }

            LabeledContent("Join state", value: wiFiManager.status.description)
        } header: {
            Text("Wi-Fi")
        } footer: {
            Text("The password exists only in this screen state and is never written to diagnostic logs.")
        }
    }

    private var networkSection: some View {
        Section("Local network") {
            LabeledContent("Path", value: networkMonitor.statusText)
            LabeledContent("Using Wi-Fi", value: networkMonitor.usesWiFi ? "Yes" : "No")
            if networkMonitor.interfaceNames.isEmpty {
                Text("No interfaces reported yet").foregroundStyle(.secondary)
            } else {
                ForEach(networkMonitor.interfaceNames, id: \.self) { name in
                    Text(name).font(.caption)
                }
            }
        }
    }

    private var transportSection: some View {
        Section {
            TextField("Display host", text: $dashHost)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            TextField("UDP port", value: $dashPort, format: .number)
                .keyboardType(.numberPad)

            Button("Open UDP Route") {
                do {
                    try transport.start(host: dashHost, port: UInt16(clamping: dashPort))
                    log.append("Opening UDP route to \(dashHost):\(dashPort)", category: "udp")
                } catch {
                    log.append(error.localizedDescription, category: "udp", level: .error)
                }
            }

            Button("Stop UDP Route", role: .destructive) {
                transport.stop()
            }

            LabeledContent("Transport", value: transport.state.description)
            LabeledContent("RX packets", value: "\(transport.receivedPackets)")
            LabeledContent("TX packets", value: "\(transport.sentPackets)")
        } header: {
            Text("UDP diagnostic route")
        } footer: {
            Text("This screen is intentionally transport-only. Use Settings → Connection & Projection for authentication, navigation-mode control and H.264/RTP projection.")
        }
    }

    private var selfCheckSection: some View {
        Section {
            Button("Run Protocol + RTP Self-Check") {
                let result = ProtocolSelfCheck.run()
                selfCheckResult = result
                log.append(
                    "Self-check \(result.passed ? "passed" : "failed"): \(result.summary)",
                    category: "self-check",
                    level: result.passed ? .info : .error
                )
            }

            if let result = selfCheckResult {
                Label(result.passed ? "Passed" : "Failed", systemImage: result.passed ? "checkmark.circle.fill" : "xmark.octagon.fill")
                    .foregroundStyle(result.passed ? .green : .red)
                Text(result.summary)
                    .font(.caption)
                    .textSelection(.enabled)
            }
        } header: {
            Text("Local self-check")
        } footer: {
            Text("This performs deterministic in-app checks of K1G decoding/sequence patching, route-card generation and RTP/FU-A packet construction. It sends nothing to the motorcycle.")
        }
    }

    private var logSection: some View {
        Section {
            if log.entries.isEmpty {
                Text("No diagnostic events yet").foregroundStyle(.secondary)
            } else {
                ForEach(log.entries.suffix(30)) { entry in
                    VStack(alignment: .leading, spacing: 3) {
                        Text("\(entry.category.uppercased()) · \(entry.level.rawValue.uppercased())")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(entry.message).font(.caption)
                    }
                }
            }

            ShareLink(
                item: log.exportText(profile: profile),
                subject: Text("OpenMoto diagnostic log"),
                message: Text("Sanitized OpenMoto hardware test log")
            ) {
                Label("Export Diagnostic Log", systemImage: "square.and.arrow.up")
            }

            Button("Clear Log", role: .destructive) { log.clear() }
        } header: {
            Text("Session log")
        } footer: {
            Text("Export redacts most of the SSID and excludes the Wi-Fi password, cryptographic session keys and route history.")
        }
    }

    private func logDeviceHealth() {
        log.append(
            "Thermal=\(deviceHealth.thermalStateText), battery=\(deviceHealth.batteryLevelText), state=\(deviceHealth.batteryStateText), lowPower=\(deviceHealth.lowPowerMode)",
            category: "health"
        )
    }
}

@MainActor
final class DeviceHealthMonitor: ObservableObject {
    @Published private(set) var thermalStateText = "Unknown"
    @Published private(set) var batteryLevelText = "Unknown"
    @Published private(set) var batteryStateText = "Unknown"
    @Published private(set) var lowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled

    private var cancellables: Set<AnyCancellable> = []

    func start() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        refresh()

        NotificationCenter.default.publisher(for: ProcessInfo.thermalStateDidChangeNotification)
            .merge(with: NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refresh() }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: UIDevice.batteryLevelDidChangeNotification)
            .merge(with: NotificationCenter.default.publisher(for: UIDevice.batteryStateDidChangeNotification))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refresh() }
            .store(in: &cancellables)
    }

    func stop() {
        cancellables.removeAll()
        UIDevice.current.isBatteryMonitoringEnabled = false
    }

    private func refresh() {
        switch ProcessInfo.processInfo.thermalState {
        case .nominal: thermalStateText = "Nominal"
        case .fair: thermalStateText = "Fair"
        case .serious: thermalStateText = "Serious"
        case .critical: thermalStateText = "Critical"
        @unknown default: thermalStateText = "Unknown"
        }

        let level = UIDevice.current.batteryLevel
        batteryLevelText = level < 0 ? "Unknown" : "\(Int((level * 100).rounded()))%"

        switch UIDevice.current.batteryState {
        case .unknown: batteryStateText = "Unknown"
        case .unplugged: batteryStateText = "Unplugged"
        case .charging: batteryStateText = "Charging"
        case .full: batteryStateText = "Full"
        @unknown default: batteryStateText = "Unknown"
        }

        lowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
    }
}

enum ProtocolSelfCheck {
    struct Result {
        let passed: Bool
        let summary: String
    }

    static func run() -> Result {
        do {
            let auth = try HexCodec.data(from: K1GCodec.requestAuthHex)
            guard K1GCodec.decode(auth) != nil else {
                return .init(passed: false, summary: "K1G request-auth packet did not decode")
            }

            let patched = try K1GCodec.patchSequence(auth, sequence: 0xA5)
            guard let marker = patched.range(of: Data("K1G ".utf8)), marker.upperBound < patched.endIndex,
                  patched[marker.upperBound] == 0xA5 else {
                return .init(passed: false, summary: "Rolling sequence patch did not update the K1G sequence byte")
            }

            let route = try K1GCodec.routeCard(title: "OpenMoto Self Check", projectionOn: true)
            guard K1GCodec.decode(route) != nil else {
                return .init(passed: false, summary: "Generated route card did not decode")
            }

            let packetizer = H264RTPPacketizer(fps: 4, maxPayload: 300)
            _ = packetizer.packetize([
                H264NALUnit(bytes: Data([0x67, 0x42, 0x00, 0x1E]), isParameterSet: true),
                H264NALUnit(bytes: Data([0x68, 0xCE, 0x06, 0xE2]), isParameterSet: true)
            ])
            let oversizedIDR = Data([0x65]) + Data(repeating: 0xAB, count: 900)
            let rtp = packetizer.packetize([H264NALUnit(bytes: oversizedIDR, isParameterSet: false)])
            guard rtp.count > 1,
                  rtp.allSatisfy({ $0.count >= 12 && $0[0] == 0x80 && ($0[1] & 0x7F) == 96 }) else {
                return .init(passed: false, summary: "RTP/FU-A packetization did not produce valid RTP v2/PT96 fragments")
            }

            return .init(
                passed: true,
                summary: "K1G decode, sequence patch, route-card generation and RTP/FU-A fragmentation all passed"
            )
        } catch {
            return .init(passed: false, summary: error.localizedDescription)
        }
    }
}

#Preview {
    NavigationStack { DiagnosticsView() }
}
