import Foundation
import XCTest
@testable import WikiQuest

final class APIClientAuthTests: XCTestCase {
    override func tearDown() {
        CaptureURLProtocol.authorization = nil
        CaptureURLProtocol.responseBody = Data()
        URLProtocol.unregisterClass(CaptureURLProtocol.self)
        super.tearDown()
    }

    func testAuthHeaderIsInjected() async throws {
        URLProtocol.registerClass(CaptureURLProtocol.self)
        CaptureURLProtocol.responseBody = Data(
            """
            {
              "clerkUserId": "user_123",
              "displayName": "Explorer",
              "customDisplayName": null,
              "bio": null,
              "xp": 10,
              "level": 1,
              "currentStreak": 0,
              "longestStreak": 0,
              "subscription": null,
              "barnstars": []
            }
            """.utf8
        )

        let api = WikiQuestAPIClient(
            baseURL: URL(string: "https://wikiquest.test")!,
            tokenProvider: { "token_abc" }
        )

        let profile = try await api.userProfile()

        XCTAssertEqual(CaptureURLProtocol.authorization, "Bearer token_abc")
        XCTAssertEqual(profile.accountUserId, "user_123")
    }
}

private final class CaptureURLProtocol: URLProtocol {
    static var authorization: String?
    static var responseBody = Data()

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        Self.authorization = request.value(forHTTPHeaderField: "Authorization")
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.responseBody)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
