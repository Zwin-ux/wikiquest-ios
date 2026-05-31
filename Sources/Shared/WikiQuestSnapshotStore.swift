import Foundation

struct WikiQuestWidgetSnapshot: Codable, Equatable {
    let displayName: String
    let streak: Int
    let xp: Int
    let isMember: Bool
    let dailyTitle: String
    let updatedAt: Date

    static let signedOut = WikiQuestWidgetSnapshot(
        displayName: "Explorer",
        streak: 0,
        xp: 0,
        isMember: false,
        dailyTitle: "Daily Mystery",
        updatedAt: .distantPast
    )
}

enum WikiQuestSnapshotStore {
    static let appGroupID = "group.com.wikiquest.app"
    private static let snapshotKey = "wikiquest.widget.snapshot"
    private static let pendingRouteKey = "wikiquest.pending.route"

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }

    static func save(snapshot: WikiQuestWidgetSnapshot) {
        if let data = try? JSONEncoder().encode(snapshot) {
            defaults.set(data, forKey: snapshotKey)
        }
    }

    static func readSnapshot() -> WikiQuestWidgetSnapshot {
        guard
            let data = defaults.data(forKey: snapshotKey),
            let snapshot = try? JSONDecoder().decode(WikiQuestWidgetSnapshot.self, from: data)
        else {
            return .signedOut
        }
        return snapshot
    }

    static func setPendingRoute(_ route: AppRoute) {
        defaults.set(route.rawValue, forKey: pendingRouteKey)
    }

    static func takePendingRoute() -> AppRoute? {
        guard let raw = defaults.string(forKey: pendingRouteKey) else { return nil }
        defaults.removeObject(forKey: pendingRouteKey)
        return AppRoute(rawValue: raw)
    }
}
