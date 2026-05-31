import CoreLocation
import XCTest
@testable import WikiQuest

final class NearbyScoringTests: XCTestCase {
    func testDistanceUsesMeters() {
        let a = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        let b = CLLocationCoordinate2D(latitude: 37.7759, longitude: -122.4194)

        let meters = NearbyScoring.distanceMeters(from: a, to: b)

        XCTAssertGreaterThan(meters, 100)
        XCTAssertLessThan(meters, 125)
    }

    func testScoreBandsRewardCloserPins() {
        XCTAssertGreaterThan(NearbyScoring.score(for: 20), NearbyScoring.score(for: 700))
        XCTAssertEqual(NearbyScoring.score(for: 2_000), 20)
    }
}
