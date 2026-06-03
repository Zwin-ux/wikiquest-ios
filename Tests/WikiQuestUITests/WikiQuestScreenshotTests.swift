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

        XCTAssertTrue(onboarding.wikiElement("PlayablePreviewQuest").waitForExistence(timeout: 12))
        XCTAssertTrue(onboarding.wikiElement("PreviewPhotoStage").exists)
        settle()
        capture(onboarding, name: "01-onboarding")
        onboarding.terminate()

        let app = XCUIApplication()
        app.launchEnvironment["WIKIQUEST_SESSION_TOKEN"] = "ui-test-token"
        app.launchEnvironment["WIKIQUEST_SCREENSHOT_MYSTERY_REVEALED"] = "1"
        app.launch()

        XCTAssertTrue(app.wikiElement("QuestDeckCard").waitForExistence(timeout: 12))
        settle()
        capture(app, name: "02-quest-deck")

        tapDock("WikiDock-mystery", in: app)
        XCTAssertTrue(app.wikiElement("MysteryPhotoStage").waitForExistence(timeout: 12))
        XCTAssertTrue(app.wikiElement("MysteryCommandDeck").exists)
        settle()
        capture(app, name: "03-mystery-revealed")

        tapDock("WikiDock-race", in: app)
        XCTAssertTrue(waitForAny([
            app.wikiElement("RacePhotoStage"),
            app.wikiElement("RaceRouteBootStage"),
            app.wikiElement("RaceRecoveryNotice")
        ], timeout: 14))
        settle()
        capture(app, name: "04-race")

        tapDock("WikiDock-map", in: app)
        dismissLocationPromptIfNeeded()
        XCTAssertTrue(app.wikiElement("NearbyMapStage").waitForExistence(timeout: 14))
        settle()
        capture(app, name: "05-map")

        tapDock("WikiDock-ranks", in: app)
        XCTAssertTrue(app.wikiElement("LeaderboardBoardSwitch").waitForExistence(timeout: 12))
        settle()
        capture(app, name: "06-ranks")

        tapDock("WikiDock-profile", in: app)
        XCTAssertTrue(app.wikiElement("ProfileOSHeader").waitForExistence(timeout: 12))
        settle()
        capture(app, name: "07-me")
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
}
