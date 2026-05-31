import Foundation

struct DailyRandomState: Codable, Identifiable, Equatable {
    var id: String { date }
    let date: String
    let puzzleNumber: Int
    let totalHints: Int
    let hintsRevealed: Int
    let maxGuesses: Int
    let revealedHints: [WikiHint]
    let guesses: [GuessRecord]
    let guessCount: Int
    let guessesRemaining: Int
    let isCorrect: Bool
    let isComplete: Bool
    let score: Int
    let timeMs: Int
    let startedAt: String
    let answer: WikiAnswer?
}

struct PracticeState: Codable, Equatable {
    let puzzleId: String
    let totalHints: Int
    let hintsRevealed: Int
    let guessesUsed: Int
    let maxGuesses: Int
    let revealedHints: [WikiHint]
    let isComplete: Bool?
    let isCorrect: Bool?
    let score: Int?
    let answer: WikiAnswer?
}

struct WikiHint: Codable, Equatable, Identifiable {
    let index: Int
    let type: String
    let value: HintValue
    var id: Int { index }
}

enum HintValue: Codable, Equatable {
    case string(String)
    case strings([String])
    case fingerprint(FingerprintHint)
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let strings = try? container.decode([String].self) {
            self = .strings(strings)
        } else if let fingerprint = try? container.decode(FingerprintHint.self) {
            self = .fingerprint(fingerprint)
        } else {
            self = .string("")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value):
            try container.encode(value)
        case .strings(let value):
            try container.encode(value)
        case .fingerprint(let value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }
}

struct FingerprintHint: Codable, Equatable {
    let titleWords: Int?
    let extractChars: Int?
    let extractWords: Int?
    let sectionsCount: Int?
    let referencesCount: Int?
    let incomingLinks: Int?
    let lengthBand: String?
}

struct GuessRecord: Codable, Equatable, Identifiable {
    let text: String
    let correct: Bool
    let hintAt: Int
    var id: String { "\(text)-\(hintAt)" }
}

struct WikiAnswer: Codable, Equatable {
    let title: String
    let pageUrl: String?
}

struct UserProfile: Codable, Equatable {
    let accountUserId: String
    let displayName: String?
    let customDisplayName: String?
    let bio: String?
    let xp: Int
    let level: Int
    let currentStreak: Int?
    let longestStreak: Int?
    let subscription: UserSubscription?
    let barnstars: [Barnstar]?

    enum CodingKeys: String, CodingKey {
        case accountUserId = "clerkUserId"
        case displayName
        case customDisplayName
        case bio
        case xp
        case level
        case currentStreak
        case longestStreak
        case subscription
        case barnstars
    }
}

struct ProfileUpdateRequest: Codable {
    let customDisplayName: String?
    let bio: String?
}

struct DeleteAccountResponse: Codable, Equatable {
    let deleted: Bool
}

struct UserSubscription: Codable, Equatable {
    let source: String?
    let status: String
    let lookupKey: String?
    let currentPeriodEnd: String?
    let trialEnd: String?
    let cancelAtPeriodEnd: Bool
}

struct EntitlementSummary: Codable, Equatable {
    let isMember: Bool
    let subscription: UserSubscription?
    let entitlements: [UserEntitlement]
}

struct UserEntitlement: Codable, Equatable, Identifiable {
    let source: String
    let entitlement: String
    let productId: String
    let status: String
    let currentPeriodEnd: String?
    var id: String { "\(source)-\(entitlement)-\(productId)" }
}

struct Barnstar: Codable, Equatable, Identifiable {
    let slug: String
    let name: String
    let description: String
    let rarity: String
    var id: String { slug }
}

struct LeaderboardEntry: Codable, Equatable, Identifiable {
    let accountUserId: String
    let displayName: String
    let xp: Int
    let level: Int
    let currentStreak: Int
    let longestStreak: Int
    var id: String { accountUserId }

    enum CodingKeys: String, CodingKey {
        case accountUserId = "clerkUserId"
        case displayName
        case xp
        case level
        case currentStreak
        case longestStreak
    }
}

struct DailyLeaderboard: Codable, Equatable {
    let date: String
    let total: Int
    let limit: Int
    let offset: Int
    let entries: [DailyLeaderboardEntry]
    let viewer: DailyLeaderboardViewer?
}

struct DailyLeaderboardEntry: Codable, Equatable, Identifiable {
    let rank: Int
    let accountUserId: String
    let displayName: String
    let score: Int
    let timeMs: Int
    let hintsRevealed: Int
    var id: String { "\(rank)-\(accountUserId)" }

    enum CodingKeys: String, CodingKey {
        case rank
        case accountUserId = "clerkUserId"
        case displayName
        case score
        case timeMs
        case hintsRevealed
    }
}

struct DailyLeaderboardViewer: Codable, Equatable {
    let rank: Int
    let score: Int
    let timeMs: Int
    let total: Int
}

struct CompletionRequest: Codable {
    let runId: String
    let articleTitle: String
    let mode: String
    let displayName: String?
}

struct CompletionResponse: Codable {
    let xpAwarded: Int
}

struct ContributionLogEntry: Codable, Equatable, Identifiable {
    let id: Int
    let accountUserId: String
    let runId: String
    let articleTitle: String
    let mode: String
    let xpEarned: Int
    let completedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case accountUserId = "clerkUserId"
        case runId
        case articleTitle
        case mode
        case xpEarned
        case completedAt
    }
}

struct MysteryStats: Codable, Equatable {
    let totalGames: Int
    let totalSolved: Int
    let avgScore: Int
    let bestScore: Int
    let avgTimeMs: Int
    let bestTimeMs: Int
    let avgHints: Int
    let currentStreak: Int
    let avgRank: Int
    let bestRank: Int
}

struct AppleSignInRequest: Codable {
    let identityToken: String
    let authorizationCode: String?
    let nonce: String?
    let email: String?
    let displayName: String?
}

struct AppleSignInResponse: Codable, Equatable {
    let token: String
    let tokenType: String
    let expiresAt: String
    let userId: String
    let displayName: String
}
