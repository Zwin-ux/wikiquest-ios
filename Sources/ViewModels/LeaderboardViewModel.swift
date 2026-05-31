import Foundation

@MainActor
final class LeaderboardViewModel: ObservableObject {
    @Published var xpRows: [LeaderboardEntry] = []
    @Published var dailyRows: [DailyLeaderboardEntry] = []
    @Published var tab = 0
    @Published var isLoading = false
    @Published var error: String?

    private let api: WikiQuestAPIClient

    init(api: WikiQuestAPIClient) {
        self.api = api
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            async let xp = try api.leaderboard()
            async let daily = try api.dailyLeaderboard()
            xpRows = try await xp
            let dailyResult = try await daily
            dailyRows = dailyResult.entries
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }
}
