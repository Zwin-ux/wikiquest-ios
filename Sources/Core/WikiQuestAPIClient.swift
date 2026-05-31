import Foundation

enum APIError: Error, LocalizedError {
    case invalidResponse
    case http(Int, String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "The server returned an invalid response."
        case .http(let code, let text):
            return "API \(code): \(text)"
        }
    }
}

struct EmptyBody: Encodable {}

struct WikiQuestAPIClient {
    var baseURL: URL = WikiQuestConfig.apiBaseURL
    var tokenProvider: () async -> String?

    func get<T: Decodable>(_ path: String) async throws -> T {
        try await request(path, method: "GET", encodedBody: nil)
    }

    func post<T: Decodable>(_ path: String) async throws -> T {
        try await request(path, method: "POST", encodedBody: try JSONEncoder().encode(EmptyBody()))
    }

    func post<T: Decodable, Body: Encodable>(_ path: String, body: Body) async throws -> T {
        try await request(path, method: "POST", encodedBody: try JSONEncoder().encode(body))
    }

    func patch<T: Decodable, Body: Encodable>(_ path: String, body: Body) async throws -> T {
        try await request(path, method: "PATCH", encodedBody: try JSONEncoder().encode(body))
    }

    func delete<T: Decodable>(_ path: String) async throws -> T {
        try await request(path, method: "DELETE", encodedBody: nil)
    }

    private func request<T: Decodable>(
        _ path: String,
        method: String,
        encodedBody: Data?
    ) async throws -> T {
        guard let url = URL(string: path, relativeTo: baseURL)?.absoluteURL else {
            throw APIError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = await tokenProvider() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = encodedBody

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            throw APIError.http(http.statusCode, String(data: data, encoding: .utf8) ?? http.description)
        }
        return try JSONDecoder().decode(T.self, from: data)
    }
}

extension WikiQuestAPIClient {
    func signInWithApple(
        identityToken: String,
        authorizationCode: String?,
        nonce: String?,
        email: String?,
        displayName: String?
    ) async throws -> AppleSignInResponse {
        try await post(
            "/api/auth/apple",
            body: AppleSignInRequest(
                identityToken: identityToken,
                authorizationCode: authorizationCode,
                nonce: nonce,
                email: email,
                displayName: displayName
            )
        )
    }

    func dailyMystery() async throws -> DailyRandomState {
        try await get("/api/daily-random/today")
    }

    func revealDailyHint() async throws -> DailyRandomState {
        try await post("/api/daily-random/hint")
    }

    func submitDailyGuess(_ guess: String) async throws -> DailyRandomState {
        try await post("/api/daily-random/guess", body: ["guess": guess])
    }

    func practiceMystery() async throws -> PracticeState {
        try await get("/api/daily-random/practice")
    }

    func revealPracticeHint(puzzleId: String) async throws -> PracticeState {
        try await post("/api/daily-random/practice/hint", body: ["puzzleId": puzzleId])
    }

    func submitPracticeGuess(puzzleId: String, guess: String) async throws -> PracticeState {
        try await post("/api/daily-random/practice/guess", body: ["puzzleId": puzzleId, "guess": guess])
    }

    func userProfile() async throws -> UserProfile {
        try await get("/api/user/me")
    }

    func updateProfile(displayName: String?, bio: String?) async throws -> UserProfile {
        try await patch("/api/user/me", body: ProfileUpdateRequest(customDisplayName: displayName, bio: bio))
    }

    func deleteAccount() async throws -> DeleteAccountResponse {
        try await delete("/api/user/me")
    }

    func contributionLog() async throws -> [ContributionLogEntry] {
        try await get("/api/user/contribution-log")
    }

    func mysteryStats() async throws -> MysteryStats {
        try await get("/api/daily-random/stats")
    }

    func entitlements() async throws -> EntitlementSummary {
        try await get("/api/entitlements/me")
    }

    func leaderboard() async throws -> [LeaderboardEntry] {
        try await get("/api/user/leaderboard")
    }

    func dailyLeaderboard() async throws -> DailyLeaderboard {
        try await get("/api/daily-random/leaderboard?limit=10")
    }

    func recordCompletion(articleTitle: String, mode: String, displayName: String?) async throws -> CompletionResponse {
        let runId = "\(mode)-ios-\(UUID().uuidString)"
        return try await post(
            "/api/user/complete",
            body: CompletionRequest(runId: runId, articleTitle: articleTitle, mode: mode, displayName: displayName)
        )
    }
}
