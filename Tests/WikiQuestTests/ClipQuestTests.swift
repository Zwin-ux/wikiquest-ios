import XCTest
@testable import WikiQuest

final class ClipQuestTests: XCTestCase {
    func testInitialSessionShowsOnlyTheFirstClue() {
        let quest = ClipQuest.wikipedia
        let session = ClipQuestSession()

        XCTAssertEqual(session.visibleClues(in: quest), [quest.clues[0]])
        XCTAssertTrue(session.canRevealMore(in: quest))
        XCTAssertNil(session.result(in: quest))
    }

    func testRevealNextStopsAtAvailableClues() {
        let quest = ClipQuest.wikipedia
        var session = ClipQuestSession()

        for _ in 0...quest.clues.count {
            session.revealNext(in: quest)
        }

        XCTAssertEqual(session.visibleClues(in: quest), quest.clues)
        XCTAssertFalse(session.canRevealMore(in: quest))
    }

    func testCorrectChoiceProducesXpPreviewAndLocksSelection() throws {
        let quest = ClipQuest.wikipedia
        let correctChoice = try XCTUnwrap(quest.correctChoice)
        var session = ClipQuestSession()

        session.choose(choiceID: correctChoice.id, in: quest)
        session.revealNext(in: quest)

        XCTAssertEqual(session.selectedChoiceID, correctChoice.id)
        XCTAssertEqual(session.result(in: quest), .correct(title: correctChoice.title, xpPreview: 120))
        XCTAssertEqual(session.visibleClues(in: quest), [quest.clues[0]])
    }

    func testWrongChoiceReportsCorrectTitle() throws {
        let quest = ClipQuest.wikipedia
        let wrongChoice = try XCTUnwrap(quest.choices.first { !$0.isCorrect })
        let correctChoice = try XCTUnwrap(quest.correctChoice)
        var session = ClipQuestSession()

        session.choose(choiceID: wrongChoice.id, in: quest)

        XCTAssertEqual(
            session.result(in: quest),
            .missed(selectedTitle: wrongChoice.title, correctTitle: correctChoice.title)
        )
    }

    func testInvalidChoiceDoesNotLockQuest() {
        let quest = ClipQuest.wikipedia
        var session = ClipQuestSession()

        session.choose(choiceID: "not-a-choice", in: quest)

        XCTAssertNil(session.selectedChoiceID)
        XCTAssertNil(session.result(in: quest))
        XCTAssertTrue(session.canRevealMore(in: quest))
    }

    func testResetReturnsToFirstClueAndClearsSelection() throws {
        let quest = ClipQuest.wikipedia
        let correctChoice = try XCTUnwrap(quest.correctChoice)
        var session = ClipQuestSession()

        session.revealNext(in: quest)
        session.choose(choiceID: correctChoice.id, in: quest)
        session.reset()

        XCTAssertEqual(session.visibleClues(in: quest), [quest.clues[0]])
        XCTAssertNil(session.selectedChoiceID)
        XCTAssertNil(session.result(in: quest))
    }

    func testAppClipInvocationParsesMysterySlug() throws {
        let url = try XCTUnwrap(URL(string: "https://wikiquest.app/clip/mystery/great-wave"))

        XCTAssertEqual(AppClipInvocation(url: url).slug, "great-wave")
    }

    func testAppClipInvocationParsesQuerySlug() throws {
        let url = try XCTUnwrap(URL(string: "https://wikiquest.app/clip/mystery?slug=today"))

        XCTAssertEqual(AppClipInvocation(url: url).slug, "today")
    }

    func testAppClipInvocationFallsBackForBadSlug() throws {
        let url = try XCTUnwrap(URL(string: "https://wikiquest.app/clip/mystery/../../admin"))

        XCTAssertEqual(AppClipInvocation(url: url).slug, AppClipInvocation.defaultSlug)
    }

    func testClipQuestManifestDecodesIntoPlayableQuest() throws {
        let quest = try AppClipQuestResolver.decodeManifest(Self.networkManifestData)

        XCTAssertEqual(quest.title, "Network Mystery")
        XCTAssertEqual(quest.clues.count, 3)
        XCTAssertEqual(quest.choices.count, 3)
        XCTAssertEqual(quest.correctChoice?.id, "correct")
        XCTAssertEqual(quest.sourceURL?.absoluteString, "https://en.wikipedia.org/wiki/Wikipedia")
    }

    func testFallbackSelectionKeepsBundledQuest() {
        let quest = AppClipQuestResolver.fallback(for: AppClipInvocation(slug: "unknown"))

        XCTAssertEqual(quest, .wikipedia)
    }

    @MainActor
    func testNetworkManifestReplacesFallbackQuest() async {
        let model = AppClipQuestViewModel(
            baseURL: URL(string: "https://wikiquest.app")!,
            fetcher: StubClipQuestFetcher(result: .success(Self.networkManifestData)),
            environment: [:]
        )

        await model.load(invocationURL: URL(string: "https://wikiquest.app/clip/mystery/network"))

        XCTAssertEqual(model.loadState, .loaded)
        XCTAssertEqual(model.quest.title, "Network Mystery")
    }

    @MainActor
    func testTimeoutKeepsBundledFallbackQuest() async {
        let model = AppClipQuestViewModel(
            baseURL: URL(string: "https://wikiquest.app")!,
            fetcher: StubClipQuestFetcher(result: .failure(URLError(.timedOut))),
            environment: [:]
        )

        await model.load(invocationURL: URL(string: "https://wikiquest.app/clip/mystery/today"))

        XCTAssertEqual(model.loadState, .failed)
        XCTAssertEqual(model.quest, .wikipedia)
    }

    private static let networkManifestData = Data(
        """
        {
          "slug": "network",
          "kicker": "APP CLIP",
          "title": "Network Mystery",
          "prompt": "A manifest-loaded quest.",
          "imageURL": "https://upload.wikimedia.org/wikipedia/commons/example.png",
          "sourceURL": "https://en.wikipedia.org/wiki/Wikipedia",
          "clues": [
            "First clue",
            "Second clue",
            "Third clue"
          ],
          "choices": [
            { "id": "wrong-a", "title": "Wrong A", "detail": "No", "isCorrect": false },
            { "id": "correct", "title": "Correct", "detail": "Yes", "isCorrect": true },
            { "id": "wrong-b", "title": "Wrong B", "detail": "No", "isCorrect": false }
          ]
        }
        """.utf8
    )
}

private struct StubClipQuestFetcher: ClipQuestDataFetching {
    let result: Result<Data, Error>

    func data(for request: URLRequest) async throws -> Data {
        switch result {
        case .success(let data):
            return data
        case .failure(let error):
            throw error
        }
    }
}
