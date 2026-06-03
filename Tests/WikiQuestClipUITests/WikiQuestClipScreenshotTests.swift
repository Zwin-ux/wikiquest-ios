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

        let clipReady = waitForAny([
            app.descendants(matching: .any)["ClipQuestRoot"],
            app.staticTexts["30-second Mystery."],
            app.staticTexts["Open full app"],
            openFullAppCTA(in: app)
        ], timeout: 30)
        settle()
        capture(app, name: "08-app-clip")
        noteReadiness(clipReady, name: "08-app-clip")
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

    private func noteReadiness(_ ready: Bool, name: String) {
        guard !ready else { return }
        let attachment = XCTAttachment(string: "\(name) captured before the readiness anchor was visible.")
        attachment.name = "\(name)-readiness-note"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func capture(_ app: XCUIApplication, name: String) {
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)

        let root = screenshotDirectory()
        do {
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            try screenshot.pngRepresentation.write(to: root.appendingPathComponent("\(name).png"))
        } catch {
            XCTFail("Could not write screenshot \(name): \(error)")
        }
    }

    private func screenshotDirectory() -> URL {
        if let directory = ProcessInfo.processInfo.environment["WIKIQUEST_SCREENSHOT_DIR"] {
            return URL(fileURLWithPath: directory)
        }
        return URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("build/screenshots")
    }
}
