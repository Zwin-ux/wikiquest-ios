import XCTest
@testable import WikiQuest

final class WikiDisplayFormatTests: XCTestCase {
    func testResetCountdownUsesNextUtcMidnight() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
        let date = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 5, day: 30, hour: 23, minute: 59, second: 10)))

        XCTAssertEqual(WikiDisplayFormat.resetCountdown(now: date), "00:00:50")
    }

    func testTimeFormatsMillisecondsAsClock() {
        XCTAssertEqual(WikiDisplayFormat.time(milliseconds: 65_000), "1:05")
        XCTAssertEqual(WikiDisplayFormat.time(milliseconds: -1), "0:00")
    }
}
