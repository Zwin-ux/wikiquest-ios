import Foundation
import XCTest
@testable import WikiQuest

final class NativeCapabilityTests: XCTestCase {
    func testWikiQuestRoutesParseCustomScheme() throws {
        let daily = try XCTUnwrap(URL(string: "wikiquest://daily"))
        let race = try XCTUnwrap(URL(string: "wikiquest://race"))
        let nearby = try XCTUnwrap(URL(string: "wikiquest://nearby"))

        XCTAssertEqual(AppRoute(url: daily), .daily)
        XCTAssertEqual(AppRoute(url: race), .race)
        XCTAssertEqual(AppRoute(url: nearby), .nearby)
    }

    func testWidgetSnapshotRoundTripsWithoutAuthTokens() {
        let snapshot = WikiQuestWidgetSnapshot(
            displayName: "Player",
            streak: 7,
            xp: 420,
            isMember: true,
            dailyTitle: "Daily Mystery",
            updatedAt: Date(timeIntervalSince1970: 1_780_000_000)
        )

        WikiQuestSnapshotStore.save(snapshot: snapshot)

        XCTAssertEqual(WikiQuestSnapshotStore.readSnapshot(), snapshot)
    }

    func testPendingRouteRoundTripsAndIsConsumed() {
        WikiQuestSnapshotStore.setPendingRoute(.nearby)

        XCTAssertEqual(WikiQuestSnapshotStore.takePendingRoute(), .nearby)
        XCTAssertNil(WikiQuestSnapshotStore.takePendingRoute())
    }

    func testOnboardingPolicyTracksSignedInState() {
        XCTAssertTrue(OnboardingGatePolicy.shouldShowOnboarding(isSignedIn: false))
        XCTAssertFalse(OnboardingGatePolicy.shouldShowOnboarding(isSignedIn: true))
    }

    func testBootupPolicyOnlyShowsForUnsignedFirstLaunch() {
        XCTAssertTrue(OnboardingBootupPolicy.shouldShowBootup(isSignedIn: false, hasCompletedBootup: false))
        XCTAssertFalse(OnboardingBootupPolicy.shouldShowBootup(isSignedIn: false, hasCompletedBootup: true))
        XCTAssertFalse(OnboardingBootupPolicy.shouldShowBootup(isSignedIn: true, hasCompletedBootup: false))
    }

    func testGameCenterRewardEventsUseConcreteGameCopy() throws {
        let id = try XCTUnwrap(UUID(uuidString: "f887d7ce-454c-4f09-9d31-e6c7866d28af"))

        let daily = GameCenterRewardEvent.dailyMystery(score: 180, streak: 7, id: id)
        XCTAssertEqual(daily.id, id)
        XCTAssertEqual(daily.kind, .streak)
        XCTAssertEqual(daily.title, "7-day streak synced")
        XCTAssertEqual(daily.detail, "Daily score 180 / 7d streak")
        XCTAssertEqual(daily.score, 180)

        let nearby = GameCenterRewardEvent.nearby(distanceMeters: 42, score: 260, id: id)
        XCTAssertEqual(nearby.kind, .nearby)
        XCTAssertEqual(nearby.title, "Bullseye synced")
        XCTAssertEqual(nearby.detail, "42 m from target")
        XCTAssertEqual(nearby.score, 260)

        let race = GameCenterRewardEvent.linkRace(elapsedSeconds: 0, id: id)
        XCTAssertEqual(race.kind, .race)
        XCTAssertEqual(race.detail, "1s submitted to Game Center")
        XCTAssertEqual(race.score, 1)
    }
}
