import Foundation
import UIKit

#if canImport(GameKit)
import GameKit
#endif

enum WikiQuestAchievementID {
    static let firstSolve = "wikiquest.first_solve"
    static let streak7 = "wikiquest.streak_7"
    static let streak30 = "wikiquest.streak_30"
    static let linkRaceFinish = "wikiquest.link_race_finish"
    static let nearbyBullseye = "wikiquest.nearby_bullseye"
    static let memberFounder = "wikiquest.member_founder"
}

enum WikiQuestLeaderboardID {
    static let dailyMysteryScore = "wikiquest.daily_mystery_score"
    static let weeklyXP = "wikiquest.weekly_xp"
    static let linkRaceBestTime = "wikiquest.link_race_best_time"
    static let nearbyClosestGuess = "wikiquest.nearby_closest_guess"
}

@MainActor
final class GameCenterStore: ObservableObject {
    @Published var isAuthenticated = false
    @Published var statusText = "Game Center idle"
    @Published var lastError: String?

    func authenticate() {
        #if canImport(GameKit)
        GKLocalPlayer.local.authenticateHandler = { [weak self] viewController, error in
            Task { @MainActor in
                if let viewController {
                    Self.present(viewController)
                    return
                }
                if let error {
                    self?.lastError = error.localizedDescription
                    self?.statusText = "Game Center unavailable"
                    self?.isAuthenticated = false
                    return
                }
                self?.isAuthenticated = GKLocalPlayer.local.isAuthenticated
                self?.statusText = self?.isAuthenticated == true ? "Game Center connected" : "Game Center signed out"
            }
        }
        #else
        statusText = "Game Center is unavailable in this build"
        #endif
    }

    func reportDailyMystery(score: Int, solved: Bool, streak: Int) {
        guard solved else { return }
        reportAchievement(WikiQuestAchievementID.firstSolve)
        if streak >= 7 { reportAchievement(WikiQuestAchievementID.streak7) }
        if streak >= 30 { reportAchievement(WikiQuestAchievementID.streak30) }
        reportScore(score, leaderboardID: WikiQuestLeaderboardID.dailyMysteryScore)
    }

    func reportWeeklyXP(_ xp: Int) {
        reportScore(max(0, xp), leaderboardID: WikiQuestLeaderboardID.weeklyXP)
    }

    func reportLinkRaceCompletion(elapsedSeconds: Int) {
        reportAchievement(WikiQuestAchievementID.linkRaceFinish)
        reportScore(max(1, elapsedSeconds), leaderboardID: WikiQuestLeaderboardID.linkRaceBestTime)
    }

    func reportNearbyResult(distanceMeters: Double, score: Int) {
        if distanceMeters <= 100 {
            reportAchievement(WikiQuestAchievementID.nearbyBullseye)
        }
        reportScore(max(1, Int(distanceMeters.rounded())), leaderboardID: WikiQuestLeaderboardID.nearbyClosestGuess)
        if score > 0 {
            reportScore(score, leaderboardID: WikiQuestLeaderboardID.weeklyXP)
        }
    }

    func reportMemberFounder() {
        reportAchievement(WikiQuestAchievementID.memberFounder)
    }

    private func reportAchievement(_ identifier: String) {
        #if canImport(GameKit)
        guard GKLocalPlayer.local.isAuthenticated else { return }
        let achievement = GKAchievement(identifier: identifier)
        achievement.percentComplete = 100
        achievement.showsCompletionBanner = true
        GKAchievement.report([achievement]) { [weak self] error in
            guard let error else { return }
            Task { @MainActor in self?.lastError = error.localizedDescription }
        }
        #endif
    }

    private func reportScore(_ score: Int, leaderboardID: String) {
        #if canImport(GameKit)
        guard GKLocalPlayer.local.isAuthenticated else { return }
        GKLeaderboard.submitScore(
            score,
            context: 0,
            player: GKLocalPlayer.local,
            leaderboardIDs: [leaderboardID]
        ) { [weak self] error in
            guard let error else { return }
            Task { @MainActor in self?.lastError = error.localizedDescription }
        }
        #endif
    }

    private static func present(_ viewController: UIViewController) {
        guard
            let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first,
            let root = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController
        else {
            return
        }
        root.present(viewController, animated: true)
    }
}
