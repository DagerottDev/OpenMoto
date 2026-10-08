import Combine
import Foundation
import Network

final class LocalNetworkMonitor: ObservableObject {
    @Published private(set) var statusText = "Not started"
    @Published private(set) var interfaceNames: [String] = []
    @Published private(set) var usesWiFi = false

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "dev.dagerott.OpenMoto.path-monitor")
    private var started = false

    func start() {
        guard !started else { return }
        started = true

        monitor.pathUpdateHandler = { [weak self] path in
            let statusText: String
            switch path.status {
            case .satisfied: statusText = "Satisfied"
            case .unsatisfied: statusText = "Unsatisfied"
            case .requiresConnection: statusText = "Requires connection"
            @unknown default: statusText = "Unknown"
            }

            let interfaces = path.availableInterfaces.map { interface in
                "\(Self.name(for: interface.type)): \(interface.name)"
            }
            let usesWiFi = path.usesInterfaceType(.wifi)

            DispatchQueue.main.async {
                self?.statusText = statusText
                self?.interfaceNames = interfaces
                self?.usesWiFi = usesWiFi
            }
        }

        monitor.start(queue: queue)
    }

    func stop() {
        monitor.cancel()
    }

    private static func name(for type: NWInterface.InterfaceType) -> String {
        switch type {
        case .wifi: return "Wi-Fi"
        case .cellular: return "Cellular"
        case .wiredEthernet: return "Ethernet"
        case .loopback: return "Loopback"
        case .other: return "Other"
        @unknown default: return "Unknown"
        }
    }
}
