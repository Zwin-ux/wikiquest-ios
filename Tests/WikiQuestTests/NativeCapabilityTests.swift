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
}
