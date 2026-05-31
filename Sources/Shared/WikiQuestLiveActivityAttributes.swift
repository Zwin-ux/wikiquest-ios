import Foundation

#if canImport(ActivityKit)
import ActivityKit

struct LinkRaceActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        let currentTitle: String
        let targetTitle: String
        let clicks: Int
        let startedAt: Date
        let endedAt: Date?
        let pathTail: [String]
        let completed: Bool
    }

    let runId: String
    let startTitle: String
    let targetTitle: String
}

struct NearbyRevealActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        let articleTitle: String
        let distanceText: String
        let score: Int
        let revealedAt: Date
    }

    let runId: String
}
#endif
