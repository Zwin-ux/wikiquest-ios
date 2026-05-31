import Foundation

struct LinkRacePage: Equatable {
    let article: WikiArticle
    let links: [WikiLink]
}

@MainActor
final class LinkRaceViewModel: ObservableObject {
    @Published var targets: LinkRaceTargets?
    @Published var targetArticle: WikiArticle?
    @Published var path: [String] = []
    @Published var current: LinkRacePage?
    @Published var linkMedia: [String: WikiMedia] = [:]
    @Published var visitedTitles = Set<String>()
    @Published var loadingTitle: String?
    @Published var error: String?
    @Published var completed = false
    @Published var savedXP: Int?
    @Published var startedAt: Date?
    @Published var completedAt: Date?

    private let api: WikiQuestAPIClient
    private let wikipedia: WikipediaClient

    init(api: WikiQuestAPIClient, wikipedia: WikipediaClient = WikipediaClient()) {
        self.api = api
        self.wikipedia = wikipedia
    }

    var clickCount: Int {
        max(0, path.count - 1)
    }

    func newRace() async {
        targets = nil
        targetArticle = nil
        path = []
        current = nil
        linkMedia = [:]
        visitedTitles = []
        loadingTitle = "Picking route"
        completed = false
        savedXP = nil
        startedAt = nil
        completedAt = nil
        error = nil
        do {
            let picked = try await wikipedia.pickLinkRaceTargets()
            startedAt = Date()
            targets = picked
            targetArticle = try? await wikipedia.summary(title: picked.target)
            try await load(title: picked.start, append: false)
        } catch {
            self.error = error.localizedDescription
            Haptics.error()
        }
        loadingTitle = nil
    }

    func move(to title: String, session: SessionStore) async {
        guard loadingTitle == nil, !visitedTitles.contains(title), !completed else { return }
        loadingTitle = title
        visitedTitles.insert(title)
        Haptics.light()
        do {
            try await load(title: title, append: true)
            if let canonical = current?.article.title {
                visitedTitles.insert(canonical)
                if canonical == targets?.target {
                    completed = true
                    completedAt = Date()
                    Haptics.success()
                    if session.isSignedIn {
                        let response = try? await api.recordCompletion(
                            articleTitle: canonical,
                            mode: "link-race",
                            displayName: session.displayName
                        )
                        savedXP = response?.xpAwarded
                    }
                }
            }
        } catch {
            visitedTitles.remove(title)
            self.error = "Could not load that article. Try another blue link."
            Haptics.error()
        }
        loadingTitle = nil
    }

    private func load(title: String, append: Bool) async throws {
        let article = try await wikipedia.summary(title: title)
        let links = try await wikipedia.links(title: article.title)
        current = LinkRacePage(article: article, links: links)
        path = append ? path + [article.title] : [article.title]
        visitedTitles.insert(article.title)
        Task { await prefetchLinkMedia(for: links) }
    }

    func media(for link: WikiLink) -> WikiMedia? {
        linkMedia[link.title]
    }

    private func prefetchLinkMedia(for links: [WikiLink]) async {
        for link in links.prefix(8) {
            if linkMedia[link.title] != nil { continue }
            if let article = try? await wikipedia.summary(title: link.title), let media = article.media {
                linkMedia[link.title] = media
            }
        }
    }

    func elapsedSeconds(now: Date = Date()) -> Int {
        guard let startedAt else { return 0 }
        let end = completedAt ?? now
        return max(0, Int(end.timeIntervalSince(startedAt)))
    }
}
