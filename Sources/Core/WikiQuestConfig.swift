import Foundation

enum WikiQuestConfig {
    static var apiBaseURL: URL {
        let raw = setting("API_BASE_URL", fallback: "http://localhost:5000")
        return URL(string: raw) ?? URL(string: "http://localhost:5000")!
    }

    static var revenueCatAPIKey: String {
        setting("REVENUECAT_IOS_API_KEY")
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
