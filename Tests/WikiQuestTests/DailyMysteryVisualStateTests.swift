import XCTest
@testable import WikiQuest

@MainActor
final class DailyMysteryVisualStateTests: XCTestCase {
    func testMysteryPhotoStaysLockedBeforeThumbnailHint() {
        let viewModel = DailyMysteryViewModel(api: testAPI)
        viewModel.daily = state(hints: [
            WikiHint(index: 1, type: "description", value: .string("Open encyclopedia"))
        ])

        XCTAssertNil(viewModel.mysteryMedia)
        XCTAssertEqual(viewModel.photoVisualState, .locked)
        XCTAssertEqual(viewModel.photoTitle, "Hidden article")
    }

    func testMysteryPhotoUsesThumbnailHintWithoutRevealingAnswer() {
        let viewModel = DailyMysteryViewModel(api: testAPI)
        viewModel.daily = state(hints: [
            WikiHint(index: 5, type: "thumbnail", value: .string("https://upload.wikimedia.org/thumb.jpg"))
        ])

        XCTAssertEqual(viewModel.mysteryMedia?.bestURL?.absoluteString, "https://upload.wikimedia.org/thumb.jpg")
        XCTAssertEqual(viewModel.photoVisualState, .clue)
        XCTAssertEqual(viewModel.photoTitle, "Hidden article")
    }

    func testMysteryPhotoRevealsAfterCompletion() {
        let viewModel = DailyMysteryViewModel(api: testAPI)
        viewModel.daily = state(
            hints: [
                WikiHint(index: 5, type: "thumbnail", value: .string("https://upload.wikimedia.org/thumb.jpg"))
            ],
            complete: true,
            correct: true,
            answer: WikiAnswer(title: "Wikipedia", pageUrl: "https://en.wikipedia.org/wiki/Wikipedia")
        )

        XCTAssertEqual(viewModel.photoVisualState, .revealed)
        XCTAssertEqual(viewModel.photoTitle, "Wikipedia")
    }

    func testDailyDeckVisualStaysLockedBeforeThumbnailHint() {
        let visual = DailyDeckVisualState.make(from: state(hints: [
            WikiHint(index: 1, type: "description", value: .string("Open encyclopedia"))
        ]))

        XCTAssertEqual(visual.title, "Daily Mystery #1")
        XCTAssertEqual(visual.visualState, .locked)
        XCTAssertEqual(visual.stateLabel, "Locked")
        XCTAssertEqual(visual.stateSystemImage, "lock.fill")
        XCTAssertEqual(visual.commandText, "Reveal first clue")
        XCTAssertEqual(visual.commandSystemImage, "lock.open.fill")
        XCTAssertNil(visual.media)
    }

    func testDailyDeckVisualUsesThumbnailWithoutRevealingAnswer() {
        let visual = DailyDeckVisualState.make(from: state(
            hints: [
                WikiHint(index: 5, type: "thumbnail", value: .string("https://upload.wikimedia.org/thumb.jpg"))
            ],
            answer: WikiAnswer(title: "Wikipedia", pageUrl: "https://en.wikipedia.org/wiki/Wikipedia")
        ))

        XCTAssertEqual(visual.title, "Daily Mystery #1")
        XCTAssertEqual(visual.visualState, .clue)
        XCTAssertEqual(visual.stateLabel, "Clue")
        XCTAssertEqual(visual.stateSystemImage, "camera.aperture")
        XCTAssertEqual(visual.commandText, "Finish mystery")
        XCTAssertEqual(visual.commandSystemImage, "scope")
        XCTAssertEqual(visual.media?.bestURL?.absoluteString, "https://upload.wikimedia.org/thumb.jpg")
        XCTAssertNil(visual.media?.sourceURL)
    }

    func testDailyDeckVisualRevealsAnswerAfterCompletion() {
        let visual = DailyDeckVisualState.make(from: state(
            hints: [
                WikiHint(index: 5, type: "thumbnail", value: .string("https://upload.wikimedia.org/thumb.jpg"))
            ],
            complete: true,
            correct: true,
            answer: WikiAnswer(title: "Wikipedia", pageUrl: "https://en.wikipedia.org/wiki/Wikipedia")
        ))

        XCTAssertEqual(visual.title, "Wikipedia")
        XCTAssertEqual(visual.visualState, .revealed)
        XCTAssertEqual(visual.stateLabel, "Solved")
        XCTAssertEqual(visual.stateSystemImage, "checkmark.seal.fill")
        XCTAssertEqual(visual.commandText, "Review result")
        XCTAssertEqual(visual.commandSystemImage, "checkmark.seal.fill")
        XCTAssertEqual(visual.media?.sourceURL?.absoluteString, "https://en.wikipedia.org/wiki/Wikipedia")
    }

    func testDailyDeckVisualUsesRevealIconForFailedCompletion() {
        let visual = DailyDeckVisualState.make(from: state(
            hints: [],
            complete: true,
            correct: false,
            answer: WikiAnswer(title: "Wikipedia", pageUrl: "https://en.wikipedia.org/wiki/Wikipedia")
        ))

        XCTAssertEqual(visual.title, "Wikipedia")
        XCTAssertEqual(visual.visualState, .revealed)
        XCTAssertEqual(visual.stateLabel, "Revealed")
        XCTAssertEqual(visual.stateSystemImage, "eye.fill")
        XCTAssertEqual(visual.commandText, "Review result")
        XCTAssertEqual(visual.commandSystemImage, "eye.fill")
    }

    func testDailyDeckVisualLoadCommandWhenStateMissing() {
        let visual = DailyDeckVisualState.make(from: nil)

        XCTAssertEqual(visual.title, "Daily Mystery")
        XCTAssertEqual(visual.commandText, "Load daily")
        XCTAssertEqual(visual.commandSystemImage, "arrow.clockwise")
    }

    private var testAPI: WikiQuestAPIClient {
        WikiQuestAPIClient(baseURL: URL(string: "https://wikiquest.test")!, tokenProvider: { nil })
    }

    private func state(
        hints: [WikiHint],
        complete: Bool = false,
        correct: Bool = false,
        answer: WikiAnswer? = nil
    ) -> DailyRandomState {
        DailyRandomState(
            date: "2026-05-31",
            puzzleNumber: 1,
            totalHints: 6,
            hintsRevealed: hints.count,
            maxGuesses: 6,
            revealedHints: hints,
            guesses: [],
            guessCount: 0,
            guessesRemaining: 6,
            isCorrect: correct,
            isComplete: complete,
            score: complete ? 120 : 0,
            timeMs: 0,
            startedAt: "2026-05-31T00:00:00.000Z",
            answer: answer
        )
    }
}
