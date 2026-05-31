import Foundation

enum AppRoute: String, Codable, CaseIterable, Identifiable {
    case home
    case daily
    case race
    case nearby
    case leaderboard
    case profile

    var id: String { rawValue }

    init?(url: URL) {
        guard url.scheme == "wikiquest" || url.scheme == "https" else { return nil }
        let candidate = url.host?.isEmpty == false ? url.host : url.pathComponents.dropFirst().first
        guard let raw = candidate?.lowercased() else { return nil }
        switch raw {
        case "home":
            self = .home
        case "daily", "mystery", "practice":
            self = .daily
        case "race", "link-race", "linkrace":
            self = .race
        case "nearby", "map":
            self = .nearby
        case "leaderboard", "ranks":
            self = .leaderboard
        case "profile", "account":
            self = .profile
        default:
            return nil
        }
    }

    var url: URL {
        var components = URLComponents()
        components.scheme = "wikiquest"
        components.host = rawValue
        return components.url ?? URL(fileURLWithPath: "/")
    }
}
