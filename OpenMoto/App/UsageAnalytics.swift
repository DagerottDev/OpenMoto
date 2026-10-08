import Combine
import Foundation

/// Explicit screen names only: this API cannot accept user content or arbitrary properties.
@MainActor
final class UsageAnalytics: ObservableObject {
    enum Screen: String, CaseIterable {
        case home, navigation, garage, expenses, rides, settings, connection, diagnostics
    }

    struct Configuration {
        let appID: String
        let endpoint: URL

        init?(appID: String, namespace: String) {
            guard let uuid = UUID(uuidString: appID),
                  !namespace.isEmpty, namespace.count <= 100,
                  namespace.range(of: #"\A[a-z0-9]+(?:[.-][a-z0-9]+)*\z"#, options: .regularExpression) != nil,
                  let url = URL(string: "https://nom.telemetrydeck.com/v2/namespace/\(namespace)/") else { return nil }
            self.appID = uuid.uuidString
            self.endpoint = url
        }

        static var bundled: Configuration? {
            // Development and Simulator use must never pollute tester analytics.
            #if DEBUG || targetEnvironment(simulator)
            return nil
            #else
            return Configuration(
                appID: Bundle.main.object(forInfoDictionaryKey: "TelemetryDeckAppID") as? String ?? "",
                namespace: Bundle.main.object(forInfoDictionaryKey: "TelemetryDeckNamespace") as? String ?? ""
            )
            #endif
        }
    }

    static let shared = UsageAnalytics()
    static let consentKey = "privacy.usageAnalytics"

    @Published var enabled: Bool {
        didSet {
            defaults.set(enabled, forKey: Self.consentKey)
            if !enabled {
                tasks.values.forEach { $0.cancel() }
                tasks.removeAll()
                sessionID = UUID().uuidString
            }
        }
    }

    var isConfigured: Bool { configuration != nil }
    private let configuration: Configuration?
    private let defaults: UserDefaults
    private let session: URLSession
    private var sessionID = UUID().uuidString
    private var tasks: [UUID: URLSessionDataTask] = [:]

    init(configuration: Configuration? = .bundled, defaults: UserDefaults = .standard, session: URLSession? = nil) {
        self.configuration = configuration
        self.defaults = defaults
        let network = URLSessionConfiguration.ephemeral
        network.httpCookieStorage = nil
        network.httpShouldSetCookies = false
        network.urlCache = nil
        network.timeoutIntervalForRequest = 5
        network.timeoutIntervalForResource = 5
        self.session = session ?? URLSession(configuration: network)
        enabled = defaults.bool(forKey: Self.consentKey)
    }

    func screenViewed(_ screen: Screen) {
        guard enabled, let configuration else { return }
        // ponytail: best-effort, at most 4 in-flight events; no offline queue or retries.
        guard tasks.count < 4 else { return }
        let event: [String: Any] = [
            "appID": configuration.appID,
            "clientUser": sessionID,
            "sessionID": sessionID,
            "type": "OpenMoto.Screen.viewed",
            "isTestMode": false,
            "payload": [
                "OpenMoto.screen": screen.rawValue,
                "OpenMoto.platform": "iOS",
                "OpenMoto.releaseStage": "testing"
            ]
        ]
        guard let body = try? JSONSerialization.data(withJSONObject: [event]) else { return }
        var request = URLRequest(url: configuration.endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        let id = UUID()
        let task = session.dataTask(with: request) { [weak self] _, _, _ in
            Task { @MainActor [weak self] in self?.tasks.removeValue(forKey: id) }
        }
        tasks[id] = task
        task.resume()
    }
}
