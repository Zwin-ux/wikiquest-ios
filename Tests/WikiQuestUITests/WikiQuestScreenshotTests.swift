import Foundation
import XCTest

final class WikiQuestScreenshotTests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func testCaptureDesignReviewScreenshots() {
        let onboarding = XCUIApplication()
        onboarding.launchEnvironment["WIKIQUEST_SKIP_BOOTUP"] = "1"
        onboarding.launch()

        let onboardingReady = onboarding.wikiElement("OnboardingTitle").waitForExistence(timeout: 16)
        settle()
        capture(onboarding, name: "01-onboarding")
        XCTAssertTrue(onboardingReady)
        onboarding.terminate()

        let app = XCUIApplication()
        app.launchEnvironment["WIKIQUEST_SESSION_TOKEN"] = "ui-test-token"
        app.launchEnvironment["WIKIQUEST_SCREENSHOT_MYSTERY_REVEALED"] = "1"
        app.launch()

        let questDeckReady = waitForAny([
            app.buttons["Today"],
            app.wikiElement("WikiDock"),
            app.wikiElement("QuestDeckCard"),
            app.wikiElement("HomeMode-mystery")
        ], timeout: 16)
        settle()
        capture(app, name: "02-quest-deck")
        XCTAssertTrue(questDeckReady)

        tapDock("WikiDock-mystery", in: app)
        let mysteryReady = waitForAny([
            app.wikiElement("MysteryPhotoStage"),
            app.wikiElement("MysteryCommandDeck"),
            app.wikiElement("MysteryModeSwitch"),
            app.wikiElement("MysteryRecoveryNotice"),
            app.wikiElement(containingLabel: "REVEALED")
        ], timeout: 16)
        settle()
        capture(app, name: "03-mystery-revealed")
        XCTAssertTrue(mysteryReady)

        tapDock("WikiDock-race", in: app)
        let raceReady = waitForAny([
            app.wikiElement("RacePhotoStage"),
            app.wikiElement("RaceRouteBootStage"),
            app.wikiElement("RaceRecoveryNotice"),
            app.wikiElement(containingLabel: "SPECIAL:LINK-RACE")
        ], timeout: 16)
        settle()
        capture(app, name: "04-race")
        XCTAssertTrue(raceReady)

        tapDock("WikiDock-map", in: app)
        dismissLocationPromptIfNeeded()
        let mapReady = waitForAny([
            app.wikiElement("NearbyMapStage"),
            app.wikiElement("NearbyQuestStatus"),
            app.wikiElement("NearbyControlSheet"),
            app.maps.firstMatch
        ], timeout: 16)
        settle()
        capture(app, name: "05-map")
        XCTAssertTrue(mapReady)

        tapDock("WikiDock-ranks", in: app)
        let ranksReady = waitForAny([
            app.wikiElement("LeaderboardBoardSwitch"),
            app.wikiElement("LeaderboardLoadingGlyph"),
            app.wikiElement("LeaderboardRecoveryNotice"),
            app.wikiElement(containingLabel: "RANKS")
        ], timeout: 16)
        settle()
        capture(app, name: "06-ranks")
        XCTAssertTrue(ranksReady)

        tapDock("WikiDock-profile", in: app)
        let profileReady = waitForAny([
            app.wikiElement("ProfileOSHeader"),
            app.wikiElement("ProfileLoadingGlyph"),
            app.wikiElement("ProfileRecoveryNotice"),
            app.wikiElement(containingLabel: "Profile")
        ], timeout: 16)
        settle()
        capture(app, name: "07-me")
        XCTAssertTrue(profileReady)
    }

    private func tapDock(_ identifier: String, in app: XCUIApplication) {
        let dockItem = app.wikiElement(identifier)
        XCTAssertTrue(dockItem.waitForExistence(timeout: 12))
        dockItem.tap()
    }

    private func waitForAny(_ elements: [XCUIElement], timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if elements.contains(where: { $0.exists }) {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        return elements.contains(where: { $0.exists })
    }

    private func dismissLocationPromptIfNeeded() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let alert = springboard.alerts.firstMatch
        guard alert.waitForExistence(timeout: 2) else { return }
        for title in ["Allow Once", "Allow While Using App", "Don't Allow", "Not Now"] {
            let button = alert.buttons[title]
            if button.exists {
                button.tap()
                return
            }
        }
        alert.buttons.firstMatch.tap()
    }

    private func settle() {
        RunLoop.current.run(until: Date().addingTimeInterval(0.55))
    }

    private func capture(_ app: XCUIApplication, name: String) {
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)

        guard let directory = ProcessInfo.processInfo.environment["WIKIQUEST_SCREENSHOT_DIR"] else {
            return
        }
        let root = URL(fileURLWithPath: directory)
        do {
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            try screenshot.pngRepresentation.write(to: root.appendingPathComponent("\(name).png"))
        } catch {
            XCTFail("Could not write screenshot \(name): \(error)")
        }
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
