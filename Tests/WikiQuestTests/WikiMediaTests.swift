import XCTest
@testable import WikiQuest

final class WikiMediaTests: XCTestCase {
    func testWikiMediaBuildsFromSummaryURLs() throws {
        let media = try XCTUnwrap(
            WikiMedia.from(
                thumbnail: "https://upload.wikimedia.org/thumb.jpg",
                image: "https://upload.wikimedia.org/image.jpg",
                source: "https://en.wikipedia.org/wiki/WikiQuest",
                fallbackStyle: .mystery
            )
        )

        XCTAssertEqual(media.thumbnailURL?.absoluteString, "https://upload.wikimedia.org/thumb.jpg")
        XCTAssertEqual(media.imageURL?.absoluteString, "https://upload.wikimedia.org/image.jpg")
        XCTAssertEqual(media.sourceURL?.absoluteString, "https://en.wikipedia.org/wiki/WikiQuest")
        XCTAssertEqual(media.bestURL?.absoluteString, "https://upload.wikimedia.org/image.jpg")
        XCTAssertEqual(media.fallbackStyle, .mystery)
    }

    func testWikiMediaUsesThumbnailWhenOriginalImageIsMissing() throws {
        let media = try XCTUnwrap(
            WikiMedia.from(
                thumbnail: "https://upload.wikimedia.org/thumb.jpg",
                image: nil,
                source: nil
            )
        )

        XCTAssertEqual(media.bestURL?.absoluteString, "https://upload.wikimedia.org/thumb.jpg")
    }

    func testWikiMediaIsNilWhenNoUsableURLExists() {
        XCTAssertNil(WikiMedia.from(thumbnail: nil, image: nil, source: nil))
        XCTAssertNil(WikiMedia.from(thumbnail: "not a url", image: nil, source: nil))
    }

    func testMediaFallbackStylesHaveDisplayMetadata() {
        XCTAssertEqual(MediaFallbackStyle.archive.displayLabel, "Archive")
        XCTAssertEqual(MediaFallbackStyle.archive.systemImage, "building.columns.fill")
        XCTAssertEqual(MediaFallbackStyle.article.displayLabel, "Article")
        XCTAssertEqual(MediaFallbackStyle.mystery.systemImage, "questionmark.diamond.fill")
        XCTAssertEqual(MediaFallbackStyle.map.displayLabel, "Map")
        XCTAssertEqual(MediaFallbackStyle.map.systemImage, "map.fill")
    }
}
