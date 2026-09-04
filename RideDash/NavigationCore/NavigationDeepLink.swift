import Foundation

enum NavigationDeepLink {
    static func destination(from url: URL) -> SharedDestination? {
        guard url.scheme?.lowercased() == "ridedash" else { return nil }
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        if url.host == "route",
           let value = components?.queryItems?.first(where: { $0.name == "q" || $0.name == "url" })?.value {
            return NavigationShareParser.parse(value)
        }
        return nil
    }
}
