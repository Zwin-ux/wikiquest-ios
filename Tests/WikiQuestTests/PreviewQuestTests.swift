import XCTest
@testable import WikiQuest

final class PreviewQuestTests: XCTestCase {
    func testPreviewStartsWithOneVisibleClueAndNoResult() {
        let quest = PreviewQuest.firstRun
        let session = PreviewQuestSession()

        XCTAssertEqual(session.visibleClues(in: quest), [quest.clues[0]])
        XCTAssertTrue(session.canRevealMore(in: quest))
        XCTAssertNil(session.result(in: quest))
    }

    func testPreviewRevealStopsBeforeChoiceLock() {
        let quest = PreviewQuest.firstRun
        var session = PreviewQuestSession()

        for _ in 0...quest.clues.count {
            session.revealNext(in: quest)
        }

        XCTAssertEqual(session.visibleClues(in: quest), quest.clues)
        XCTAssertFalse(session.canRevealMore(in: quest))
    }

    func testCorrectPreviewChoiceLocksAndSolves() throws {
        let quest = PreviewQuest.firstRun
        let correctChoice = try XCTUnwrap(quest.correctChoice)
        var session = PreviewQuestSession()

        session.choose(choiceID: correctChoice.id, in: quest)
        session.revealNext(in: quest)

        XCTAssertEqual(session.selectedChoiceID, correctChoice.id)
        XCTAssertEqual(session.result(in: quest), .correct(title: correctChoice.title))
        XCTAssertEqual(session.visibleClues(in: quest), [quest.clues[0]])
    }

    func testWrongPreviewChoiceReportsCorrectTitle() throws {
        let quest = PreviewQuest.firstRun
        let wrongChoice = try XCTUnwrap(quest.choices.first { !$0.isCorrect })
        let correctChoice = try XCTUnwrap(quest.correctChoice)
        var session = PreviewQuestSession()

        session.choose(choiceID: wrongChoice.id, in: quest)

        XCTAssertEqual(
            session.result(in: quest),
            .missed(selectedTitle: wrongChoice.title, correctTitle: correctChoice.title)
        )
    }
}
