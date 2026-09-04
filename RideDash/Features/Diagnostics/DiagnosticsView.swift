import SwiftUI

struct DiagnosticsView: View {
    @StateObject private var wiFiManager = TripperWiFiManager()
    @StateObject private var networkMonitor = LocalNetworkMonitor()
    @StateObject private var transport = DashTransport()
    @StateObject private var log = DiagnosticLog()

    @AppStorage("dash.test.bikeModel") private var bikeModel = "Guerrilla 450"
    @AppStorage("dash.test.firmware") private var dashFirmware = ""
    @AppStorage("dash.test.ssid") private var dashSSID = ""
    @AppStorage("dash.test.host") private var dashHost = "192.168.1.1"
    @AppStorage("dash.test.port") private var dashPort = 5000

    @State private var passphrase = ""

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
            wiFiSection
            networkSection
            transportSection
            logSection
        }
        .navigationTitle("Dash Diagnostics")
        .onAppear {
            networkMonitor.start()
            log.append("Diagnostics screen opened", category: "app")
        }
        .onChange(of: networkMonitor.statusText) { _, newValue in
            log.append("Path status: \(newValue); Wi-Fi=\(networkMonitor.usesWiFi)", category: "network")
        }
        .onChange(of: transport.state) { _, newValue in
            log.append("Transport: \(newValue.description)", category: "udp")
        }
    }

    private var hardwareSection: some View {
        Section("Hardware test profile") {
            TextField("Bike model", text: $bikeModel)
            TextField("Dash firmware", text: $dashFirmware)
                .textInputAutocapitalization(.never)
            LabeledContent("Phone", value: profile.iPhoneModel)
            LabeledContent("iOS", value: profile.iOSVersion)
        }
    }

    private var wiFiSection: some View {
        Section {
            TextField("Dash Wi-Fi SSID", text: $dashSSID)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            SecureField("Wi-Fi password (if required)", text: $passphrase)

            Button("Request Wi-Fi Join") {
                Task {
                    log.append("Wi-Fi join requested for configured dash SSID", category: "wifi")
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
            Text("RideDash uses Apple's Hotspot Configuration API. iOS controls the user approval flow. The password is kept only in this screen state and is never written to the diagnostic log.")
        }
    }

    private var networkSection: some View {
        Section("Local network") {
            LabeledContent("Path", value: networkMonitor.statusText)
            LabeledContent("Using Wi-Fi", value: networkMonitor.usesWiFi ? "Yes" : "No")
            if networkMonitor.interfaceNames.isEmpty {
                Text("No interfaces reported yet")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(networkMonitor.interfaceNames, id: \.self) { name in
                    Text(name)
                        .font(.caption)
                }
            }
        }
    }

    private var transportSection: some View {
        Section {
            TextField("Dash host", text: $dashHost)
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
        } header: {
            Text("UDP diagnostic route")
        } footer: {
            Text("A UDP connection reaching Ready only proves iOS has a route/socket. It does not prove the motorcycle dash responded. Phase 2 will add receive loops and validated, non-destructive protocol probes.")
        }
    }

    private var logSection: some View {
        Section {
            if log.entries.isEmpty {
                Text("No diagnostic events yet")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(log.entries.suffix(30)) { entry in
                    VStack(alignment: .leading, spacing: 3) {
                        Text("\(entry.category.uppercased()) · \(entry.level.rawValue.uppercased())")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(entry.message)
                            .font(.caption)
                    }
                }
            }

            ShareLink(
                item: log.exportText(profile: profile),
                subject: Text("RideDash diagnostic log"),
                message: Text("Sanitized RideDash hardware test log")
            ) {
                Label("Export Diagnostic Log", systemImage: "square.and.arrow.up")
            }

            Button("Clear Log", role: .destructive) {
                log.clear()
            }
        } header: {
            Text("Session log")
        } footer: {
            Text("Export deliberately redacts most of the SSID and does not include the Wi-Fi password, cryptographic secrets, or route history.")
        }
    }
}

#Preview {
    NavigationStack {
        DiagnosticsView()
    }
}
