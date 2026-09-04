import Foundation

struct SharedDestination: Sendable {
    var query: String
}

enum NavigationShareParser {
    static func parse(_ text: String) -> SharedDestination? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let url = URL(string: trimmed), let components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            for key in ["q", "query", "destination", "daddr"] {
                if let value = components.queryItems?.first(where: { $0.name.lowercased() == key })?.value,
                   !value.isEmpty {
                    return SharedDestination(query: value)
                }
            }
        }
        return SharedDestination(query: trimmed)
    }
}
