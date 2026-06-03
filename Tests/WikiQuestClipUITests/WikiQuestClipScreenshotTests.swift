import Foundation
import XCTest

final class WikiQuestClipScreenshotTests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func testCaptureAppClipScreenshot() {
        let app = XCUIApplication(bundleIdentifier: "com.wikiquest.app.Clip")
        app.launchArguments += ["-UITests"]
        app.launchEnvironment["WIKIQUEST_APP_CLIP_DISABLE_NETWORK"] = "1"
        app.launchEnvironment["WIKIQUEST_APP_CLIP_PRESELECT_CHOICE_ID"] = "great-wave"
        app.launch()

        XCTAssertTrue(app.descendants(matching: .any)["ClipQuestRoot"].waitForExistence(timeout: 30))
        XCTAssertTrue(openFullAppCTA(in: app).waitForExistence(timeout: 12))
        settle()
        capture(app, name: "08-app-clip")
    }

    private func openFullAppCTA(in app: XCUIApplication) -> XCUIElement {
        let identifiedCTA = app.descendants(matching: .any)["ClipQuestOpenFullApp"]
        if identifiedCTA.exists {
            return identifiedCTA
        }
        if app.links["Open full app"].exists {
            return app.links["Open full app"]
        }
        if app.buttons["Open full app"].exists {
            return app.buttons["Open full app"]
        }
        return app.staticTexts["Open full app"]
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
