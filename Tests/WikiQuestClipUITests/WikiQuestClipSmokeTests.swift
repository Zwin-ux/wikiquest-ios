import XCTest

final class WikiQuestClipSmokeTests: XCTestCase {
    func testBundledFallbackRenders() {
        let app = makeApp()
        app.launchEnvironment["WIKIQUEST_APP_CLIP_DISABLE_NETWORK"] = "1"
        app.launch()

        XCTAssertTrue(app.otherElements["ClipQuestRoot"].waitForExistence(timeout: 6))
        XCTAssertTrue(app.staticTexts["30-second Mystery."].waitForExistence(timeout: 3))
    }

    func testNetworkManifestReplacesFallback() {
        let app = makeApp()
        app.launchEnvironment["WIKIQUEST_APP_CLIP_MANIFEST_JSON"] = Self.manifestJSON
        app.launch()

        XCTAssertTrue(app.staticTexts["Network Mystery"].waitForExistence(timeout: 6))
        XCTAssertFalse(app.staticTexts["30-second Mystery."].exists)
    }

    func testTimeoutKeepsFallback() {
        let app = makeApp()
        app.launchEnvironment["WIKIQUEST_APP_CLIP_FORCE_TIMEOUT"] = "1"
        app.launch()

        XCTAssertTrue(app.staticTexts["30-second Mystery."].waitForExistence(timeout: 6))
    }

    func testResultCTAAppearsAfterChoice() {
        let app = makeApp()
        app.launchEnvironment["WIKIQUEST_APP_CLIP_DISABLE_NETWORK"] = "1"
        app.launch()

        XCTAssertTrue(app.buttons["ClipQuestChoice-great-wave"].waitForExistence(timeout: 6))
        app.buttons["ClipQuestChoice-great-wave"].tap()

        XCTAssertTrue(app.otherElements["ClipQuestResultBanner"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.descendants(matching: .any)["ClipQuestOpenFullApp"].waitForExistence(timeout: 3))
    }

    private func makeApp() -> XCUIApplication {
        let app = XCUIApplication(bundleIdentifier: "com.wikiquest.app.Clip")
        app.launchArguments += ["-UITests"]
        return app
    }

    private static let manifestJSON = """
    {
      "slug": "network",
      "kicker": "APP CLIP",
      "title": "Network Mystery",
      "prompt": "A manifest-loaded quest.",
      "imageURL": "https://upload.wikimedia.org/wikipedia/commons/example.png",
      "sourceURL": "https://en.wikipedia.org/wiki/Wikipedia",
      "clues": [
        "First clue",
        "Second clue",
        "Third clue"
      ],
      "choices": [
        { "id": "wrong-a", "title": "Wrong A", "detail": "No", "isCorrect": false },
        { "id": "correct", "title": "Correct", "detail": "Yes", "isCorrect": true },
        { "id": "wrong-b", "title": "Wrong B", "detail": "No", "isCorrect": false }
      ]
    }
    """
}
