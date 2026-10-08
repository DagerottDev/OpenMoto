import Foundation

final class AnalyticsStub: URLProtocol {
    static let lock = NSLock()
    static var requests: [URLRequest] = []
    static var hold = false
    static var cancellations = 0

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.lock.lock()
        Self.requests.append(request)
        let hold = Self.hold
        Self.lock.unlock()
        if !hold { client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet)) }
    }
    override func stopLoading() {
        Self.lock.lock()
        Self.cancellations += 1
        Self.lock.unlock()
    }
    static func snapshot() -> ([URLRequest], Int) {
        lock.lock(); defer { lock.unlock() }
        return (requests, cancellations)
    }
    static func reset(hold: Bool = false) {
        lock.lock(); defer { lock.unlock() }
        requests = []; cancellations = 0; Self.hold = hold
    }
}

@main
struct UsageAnalyticsCheck {
    @MainActor
    static func main() async throws {
        let suite = "OpenMoto.AnalyticsCheck.\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let network = URLSessionConfiguration.ephemeral
        network.protocolClasses = [AnalyticsStub.self]
        let session = URLSession(configuration: network)
        defer { session.invalidateAndCancel() }
        let appID = "F25CD2AB-6AD8-4B1C-9125-889438406FF9"
        let config = UsageAnalytics.Configuration(appID: appID, namespace: "test-app")!
        assert(UsageAnalytics.Configuration(appID: "", namespace: "test-app") == nil)
        assert(UsageAnalytics.Configuration(appID: appID, namespace: "../other") == nil)
        assert(UsageAnalytics.Configuration(appID: appID, namespace: "test?email=private") == nil)
        assert(UsageAnalytics.Configuration(appID: appID, namespace: "") == nil)
        assert(UsageAnalytics.Configuration(appID: appID, namespace: "test\n") == nil)
        assert(UsageAnalytics.Configuration(appID: appID, namespace: "dev.dagerott.ridedash") != nil)
        #if DEBUG
        assert(UsageAnalytics.Configuration.bundled == nil)
        #endif

        let analytics = UsageAnalytics(configuration: config, defaults: defaults, session: session)
        assert(!analytics.enabled)
        analytics.screenViewed(.home)
        try await Task.sleep(for: .milliseconds(50))
        assert(AnalyticsStub.snapshot().0.isEmpty, "Default opt-out must send nothing")

        analytics.enabled = true
        assert(defaults.bool(forKey: UsageAnalytics.consentKey))
        for screen in UsageAnalytics.Screen.allCases {
            analytics.screenViewed(screen)
            try await Task.sleep(for: .milliseconds(50))
        }
        let requests = AnalyticsStub.snapshot().0
        assert(requests.count == UsageAnalytics.Screen.allCases.count, "Failures must not block later events")
        var originalID = ""
        for (request, screen) in zip(requests, UsageAnalytics.Screen.allCases) {
            assert(request.url?.absoluteString == "https://nom.telemetrydeck.com/v2/namespace/test-app/")
            assert(request.httpMethod == "POST")
            assert(request.value(forHTTPHeaderField: "Content-Type") == "application/json; charset=utf-8")
            let event = try decode(request)
            assert(Set(event.keys) == ["appID", "clientUser", "sessionID", "type", "isTestMode", "payload"])
            assert(event["appID"] as? String == appID)
            assert(event["type"] as? String == "OpenMoto.Screen.viewed")
            assert(event["isTestMode"] as? Bool == false)
            let payload = event["payload"] as! [String: String]
            assert(payload == ["OpenMoto.screen": screen.rawValue, "OpenMoto.platform": "iOS", "OpenMoto.releaseStage": "testing"])
            let id = event["clientUser"] as! String
            assert(UUID(uuidString: id) != nil && event["sessionID"] as? String == id)
            if originalID.isEmpty { originalID = id }
            assert(id == originalID)
        }

        analytics.enabled = false
        analytics.screenViewed(.home)
        try await Task.sleep(for: .milliseconds(50))
        assert(AnalyticsStub.snapshot().0.count == requests.count)
        analytics.enabled = true
        analytics.screenViewed(.home)
        try await Task.sleep(for: .milliseconds(50))
        let resetID = try decode(AnalyticsStub.snapshot().0.last!)["clientUser"] as? String
        assert(resetID != originalID)
        let relaunched = UsageAnalytics(configuration: config, defaults: defaults, session: session)
        assert(relaunched.enabled, "Consent should persist")
        relaunched.screenViewed(.home)
        try await Task.sleep(for: .milliseconds(50))
        let relaunchedID = try decode(AnalyticsStub.snapshot().0.last!)["clientUser"] as? String
        assert(relaunchedID != originalID && relaunchedID != resetID)

        AnalyticsStub.reset()
        let unconfigured = UsageAnalytics(configuration: nil, defaults: defaults, session: session)
        unconfigured.screenViewed(.home)
        try await Task.sleep(for: .milliseconds(50))
        assert(AnalyticsStub.snapshot().0.isEmpty && !unconfigured.isConfigured)
        AnalyticsStub.reset(hold: true)
        for _ in 0..<10 { analytics.screenViewed(.home) }
        try await Task.sleep(for: .milliseconds(100))
        assert(AnalyticsStub.snapshot().0.count == 4, "In-flight events must be bounded")
        analytics.enabled = false
        try await Task.sleep(for: .milliseconds(100))
        assert(AnalyticsStub.snapshot().1 == 4, "Opt-out must cancel pending requests")
        assert(!defaults.bool(forKey: UsageAnalytics.consentKey))
        print("PASS: consent, configuration, exact payload allowlist, failure isolation, ID reset, request bound and cancellation; no external traffic")
    }

    static func decode(_ request: URLRequest) throws -> [String: Any] {
        var data = request.httpBody ?? Data()
        if data.isEmpty, let stream = request.httpBodyStream {
            stream.open(); defer { stream.close() }
            var bytes = [UInt8](repeating: 0, count: 4096)
            while stream.hasBytesAvailable {
                let count = stream.read(&bytes, maxLength: bytes.count)
                guard count > 0 else { break }
                data.append(contentsOf: bytes.prefix(count))
            }
        }
        return (try JSONSerialization.jsonObject(with: data) as! [[String: Any]])[0]
    }
}
