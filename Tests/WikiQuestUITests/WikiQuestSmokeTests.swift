import XCTest

final class WikiQuestSmokeTests: XCTestCase {
    func testFirstLaunchShowsBootupThenOnboarding() {
        let app = XCUIApplication()
        app.launchEnvironment["WIKIQUEST_RESET_BOOTUP"] = "1"
        app.launchEnvironment["WIKIQUEST_FAST_BOOTUP"] = "1"
        app.launch()

        XCTAssertTrue(app.wikiElement("BootupIntro").waitForExistence(timeout: 6))
        XCTAssertTrue(app.wikiElement("BootupTitle").exists)
        XCTAssertTrue(app.wikiElement("OnboardingTitle").waitForExistence(timeout: 6))
        XCTAssertTrue(app.buttons["Sign in with Apple"].waitForExistence(timeout: 6))
        XCTAssertTrue(app.buttons["Reveal clue"].waitForExistence(timeout: 6))
    }

    func testSignedOutLaunchShowsOnboardingGate() {
        let app = XCUIApplication()
        app.launchEnvironment["WIKIQUEST_SKIP_BOOTUP"] = "1"
        app.launch()

        XCTAssertTrue(app.wikiElement("OnboardingTitle").waitForExistence(timeout: 6))
        XCTAssertTrue(app.buttons["Sign in with Apple"].waitForExistence(timeout: 6))
        XCTAssertTrue(app.buttons["Reveal clue"].waitForExistence(timeout: 6))
        XCTAssertTrue(app.wikiElement(containingLabel: "The Great Wave off Kanagawa").exists)
        XCTAssertTrue(app.wikiElement(containingLabel: "Mystery").exists)
        XCTAssertTrue(app.wikiElement(containingLabel: "Race").exists)
        XCTAssertTrue(app.wikiElement(containingLabel: "Map").exists)
        XCTAssertFalse(app.wikiElement("WIKIQUEST OS").exists)
        XCTAssertFalse(app.wikiElement(containingLabel: "APPLE ID REQUIRED").exists)
        XCTAssertFalse(app.buttons["Today"].exists)
        XCTAssertFalse(app.buttons["Mystery"].exists)
    }

    func testOnboardingLegalLinksAreReachable() {
        let app = XCUIApplication()
        app.launchEnvironment["WIKIQUEST_SKIP_BOOTUP"] = "1"
        app.launch()

        XCTAssertTrue(app.wikiElement(containingLabel: "Privacy").waitForExistence(timeout: 6))
        XCTAssertTrue(app.wikiElement(containingLabel: "Terms").exists)
    }

    func testSignedInLaunchBypassesOnboarding() {
        let app = XCUIApplication()
        app.launchEnvironment["WIKIQUEST_SESSION_TOKEN"] = "ui-test-token"
        app.launch()

        XCTAssertTrue(app.buttons["Today"].waitForExistence(timeout: 6))
        XCTAssertTrue(app.wikiElement("QuestDeckCard").waitForExistence(timeout: 6))
        XCTAssertTrue(app.wikiElement("HomeMode-mystery").exists)
        XCTAssertTrue(app.wikiElement("HomeMode-race").exists)
        XCTAssertTrue(app.wikiElement("HomeMode-nearby").exists)
        XCTAssertFalse(app.buttons["Sign in with Apple"].exists)
    }
}

private extension XCUIApplication {
    func wikiElement(_ identifier: String) -> XCUIElement {
        let predicate = NSPredicate(format: "identifier == %@ OR label == %@", identifier, identifier)
        return descendants(matching: .any).matching(predicate).firstMatch
    }

    func wikiElement(containingLabel label: String) -> XCUIElement {
        let predicate = NSPredicate(format: "label CONTAINS[c] %@ OR identifier CONTAINS[c] %@", label, label)
        return descendants(matching: .any).matching(predicate).firstMatch
    }
}
