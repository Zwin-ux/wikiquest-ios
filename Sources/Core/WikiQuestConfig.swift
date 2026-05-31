import Foundation

enum WikiQuestConfig {
    static var apiBaseURL: URL {
        let raw = setting("API_BASE_URL", fallback: "http://localhost:5000")
        return URL(string: raw) ?? URL(string: "http://localhost:5000")!
    }

    static var revenueCatAPIKey: String {
        setting("REVENUECAT_IOS_API_KEY")
    }

    static var revenueCatAPIKeyKind: RevenueCatAPIKeyKind {
        RevenueCatAPIKeyKind(rawValue: revenueCatAPIKey)
    }

    static func setting(_ key: String, fallback: String = "") -> String {
        let raw = Bundle.main.object(forInfoDictionaryKey: key) as? String
        let env = ProcessInfo.processInfo.environment[key]
        let value = [raw, env]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty && !$0.contains("$(") }
        return value ?? fallback
    }
}

enum RevenueCatAPIKeyKind: Equatable {
    case missing
    case applePublic
    case testStore
    case secret
    case unknown

    init(rawValue: String) {
        if rawValue.isEmpty {
            self = .missing
        } else if rawValue.hasPrefix("appl_") {
            self = .applePublic
        } else if rawValue.hasPrefix("test_") {
            self = .testStore
        } else if rawValue.hasPrefix("sk_") {
            self = .secret
        } else {
            self = .unknown
        }
    }

    var isClientUsable: Bool {
        switch self {
        case .applePublic, .testStore:
            return true
        case .missing, .secret, .unknown:
            return false
        }
    }
}
