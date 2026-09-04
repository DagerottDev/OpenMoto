import Foundation

@MainActor
final class DiagnosticLog: ObservableObject {
    struct Entry: Identifiable, Codable, Equatable {
        enum Level: String, Codable {
            case info
            case warning
            case error
        }

        let id: UUID
        let timestamp: Date
        let level: Level
        let category: String
        let message: String

        init(level: Level, category: String, message: String) {
            self.id = UUID()
            self.timestamp = Date()
            self.level = level
            self.category = category
            self.message = message
        }
    }

    @Published private(set) var entries: [Entry] = []

    func append(_ message: String, category: String, level: Entry.Level = .info) {
        entries.append(Entry(level: level, category: category, message: message))
    }

    func clear() {
        entries.removeAll()
    }

    func exportText(profile: DashTestProfile) -> String {
        let formatter = ISO8601DateFormatter()
        var lines: [String] = [
            "RideDash diagnostic session",
            "Generated: \(formatter.string(from: Date()))",
            "Bike: \(profile.bikeModel)",
            "Dash firmware: \(profile.dashFirmware.isEmpty ? "unknown" : profile.dashFirmware)",
            "Dash SSID: \(sanitizedSSID(profile.dashSSID))",
            "Dash host: \(profile.dashHost)",
            "Phone: \(profile.iPhoneModel)",
            "iOS: \(profile.iOSVersion)",
            "",
            "Timeline"
        ]

        lines.append(contentsOf: entries.map { entry in
            "\(formatter.string(from: entry.timestamp)) [\(entry.level.rawValue.uppercased())] [\(entry.category)] \(entry.message)"
        })

        lines.append("")
        lines.append("Credentials, private keys and precise route history are intentionally excluded.")
        return lines.joined(separator: "\n")
    }

    private func sanitizedSSID(_ ssid: String) -> String {
        guard !ssid.isEmpty else { return "unknown" }
        guard ssid.count > 4 else { return "<redacted>" }
        return "\(ssid.prefix(2))…\(ssid.suffix(2))"
    }
}
