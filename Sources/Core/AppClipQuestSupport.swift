import Combine
import Foundation

struct AppClipInvocation: Equatable {
    static let defaultSlug = "today"

    let slug: String

    init(slug: String = Self.defaultSlug) {
        self.slug = Self.validSlug(slug) ?? Self.defaultSlug
    }

    init(url: URL?) {
        self.slug = Self.slug(from: url) ?? Self.defaultSlug
    }

    static func slug(from url: URL?) -> String? {
        guard let url else { return nil }
        guard url.scheme?.lowercased() == "https" else { return nil }

        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        if let querySlug = components?.queryItems?.first(where: { $0.name == "slug" })?.value,
           let valid = validSlug(querySlug) {
            return valid
        }

        let path = url.pathComponents.filter { $0 != "/" }
        guard let clipIndex = path.firstIndex(of: "clip") else { return nil }
        let tail = path.suffix(from: clipIndex)
        guard tail.count >= 2, tail.dropFirst().first == "mystery" else { return nil }
        let rawSlug = tail.dropFirst(2).first ?? defaultSlug
        return validSlug(rawSlug)
    }

    static func validSlug(_ raw: String) -> String? {
        let slug = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !slug.isEmpty, slug.count <= 64 else { return nil }
        guard slug.range(of: #"^[a-z0-9][a-z0-9-]*$"#, options: .regularExpression) != nil else {
            return nil
        }
        return slug
    }
}

struct ClipQuestManifest: Decodable, Equatable {
    let slug: String
    let kicker: String
    let title: String
    let prompt: String
    let imageURL: URL?
    let sourceURL: URL?
    let clues: [String]
    let choices: [ClipQuestChoice]

    var quest: ClipQuest {
        ClipQuest(
            kicker: kicker,
            title: title,
            prompt: prompt,
            imageURL: imageURL,
            sourceURL: sourceURL,
            clues: clues,
            choices: choices
        )
    }
}

enum AppClipQuestResolver {
    static func fallback(for invocation: AppClipInvocation = AppClipInvocation()) -> ClipQuest {
        switch invocation.slug {
        case AppClipInvocation.defaultSlug:
            return .wikipedia
        default:
            return .wikipedia
        }
    }

    static func decodeManifest(_ data: Data) throws -> ClipQuest {
        let manifest = try JSONDecoder().decode(ClipQuestManifest.self, from: data)
        guard manifest.clues.count == 3, manifest.choices.count == 3 else {
            throw AppClipQuestError.invalidManifest
        }
        guard manifest.choices.filter(\.isCorrect).count == 1 else {
            throw AppClipQuestError.invalidManifest
        }
        return manifest.quest
    }

    static func endpoint(baseURL: URL, invocation: AppClipInvocation) -> URL {
        var components = URLComponents(
            url: baseURL
                .appendingPathComponent("api")
                .appendingPathComponent("app-clip")
                .appendingPathComponent("quest"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [URLQueryItem(name: "slug", value: invocation.slug)]
        return components?.url ?? baseURL
    }
}

enum AppClipQuestError: Error, Equatable {
    case invalidManifest
    case badStatus(Int)
}

enum AppClipQuestLoadState: Equatable {
    case fallback
    case loaded
    case failed
}

protocol ClipQuestDataFetching {
    func data(for request: URLRequest) async throws -> Data
}

struct URLSessionClipQuestFetcher: ClipQuestDataFetching {
    func data(for request: URLRequest) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { return data }
        guard (200..<300).contains(http.statusCode) else {
            throw AppClipQuestError.badStatus(http.statusCode)
        }
        return data
    }
}

@MainActor
final class AppClipQuestViewModel: ObservableObject {
    @Published private(set) var quest: ClipQuest
    @Published private(set) var loadState: AppClipQuestLoadState

    private let fallbackQuest: ClipQuest
    private let baseURL: URL
    private let fetcher: any ClipQuestDataFetching
    private let environment: [String: String]

    init(
        fallbackQuest: ClipQuest = .wikipedia,
        baseURL: URL? = nil,
        fetcher: any ClipQuestDataFetching = URLSessionClipQuestFetcher(),
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) {
        self.fallbackQuest = fallbackQuest
        self.quest = fallbackQuest
        self.loadState = .fallback
        self.baseURL = baseURL ?? Self.defaultAPIBaseURL()
        self.fetcher = fetcher
        self.environment = environment
    }

    func load(invocationURL: URL? = nil) async {
        let invocation = AppClipInvocation(url: invocationURL)
        quest = AppClipQuestResolver.fallback(for: invocation)
        loadState = .fallback

        if let manifestJSON = environment["WIKIQUEST_APP_CLIP_MANIFEST_JSON"] {
            do {
                quest = try AppClipQuestResolver.decodeManifest(Data(manifestJSON.utf8))
                loadState = .loaded
            } catch {
                quest = fallbackQuest
                loadState = .failed
            }
            return
        }

        if environment["WIKIQUEST_APP_CLIP_DISABLE_NETWORK"] == "1" ||
            environment["WIKIQUEST_APP_CLIP_FORCE_TIMEOUT"] == "1" {
            return
        }

        do {
            let endpoint = AppClipQuestResolver.endpoint(baseURL: baseURL, invocation: invocation)
            var request = URLRequest(url: endpoint, timeoutInterval: 1.5)
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            let data = try await fetcher.data(for: request)
            quest = try AppClipQuestResolver.decodeManifest(data)
            loadState = .loaded
        } catch {
            quest = fallbackQuest
            loadState = .failed
        }
    }

    private static func defaultAPIBaseURL() -> URL {
        let rawInfo = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String
        let rawEnv = ProcessInfo.processInfo.environment["API_BASE_URL"]
        let raw = [rawInfo, rawEnv]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty && !$0.contains("$(") }
        return raw.flatMap(URL.init(string:)) ?? URL(string: "https://wikiquest.app")!
    }
}
