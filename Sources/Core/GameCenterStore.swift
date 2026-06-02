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

struct GameCenterRewardEvent: Identifiable, Equatable {
    enum Kind: String, Equatable {
        case daily
        case streak
        case race
        case nearby
        case member
    }

    let id: UUID
    let kind: Kind
    let title: String
    let detail: String
    let systemImage: String
    let score: Int?

    init(
        id: UUID = UUID(),
        kind: Kind,
        title: String,
        detail: String,
        systemImage: String,
        score: Int? = nil
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.detail = detail
        self.systemImage = systemImage
        self.score = score
    }

    static func dailyMystery(score: Int, streak: Int, id: UUID = UUID()) -> GameCenterRewardEvent {
        if streak >= 30 {
            return GameCenterRewardEvent(
                id: id,
                kind: .streak,
                title: "30-day streak synced",
                detail: "Daily score \(score) / \(streak)d streak",
                systemImage: "flame.fill",
                score: score
            )
        }
        if streak >= 7 {
            return GameCenterRewardEvent(
                id: id,
                kind: .streak,
                title: "7-day streak synced",
                detail: "Daily score \(score) / \(streak)d streak",
                systemImage: "flame.fill",
                score: score
            )
        }
        return GameCenterRewardEvent(
            id: id,
            kind: .daily,
            title: "Daily score synced",
            detail: "Mystery result posted to Game Center",
            systemImage: "questionmark.circle.fill",
            score: score
        )
    }

    static func linkRace(elapsedSeconds: Int, id: UUID = UUID()) -> GameCenterRewardEvent {
        GameCenterRewardEvent(
            id: id,
            kind: .race,
            title: "Race time synced",
            detail: "\(max(1, elapsedSeconds))s submitted to Game Center",
            systemImage: "flag.checkered",
            score: max(1, elapsedSeconds)
        )
    }

    static func nearby(distanceMeters: Double, score: Int, id: UUID = UUID()) -> GameCenterRewardEvent {
        let distance = NearbyScoring.format(distanceMeters)
        return GameCenterRewardEvent(
            id: id,
            kind: .nearby,
            title: distanceMeters <= 100 ? "Bullseye synced" : "Map result synced",
            detail: "\(distance) from target",
            systemImage: distanceMeters <= 100 ? "scope" : "mappin.and.ellipse",
            score: score
        )
    }

    static func memberFounder(id: UUID = UUID()) -> GameCenterRewardEvent {
        GameCenterRewardEvent(
            id: id,
            kind: .member,
            title: "Member Founder synced",
            detail: "Achievement posted to Game Center",
            systemImage: "sparkles"
        )
    }
}

@MainActor
final class GameCenterStore: ObservableObject {
    @Published var isAuthenticated = false
    @Published var statusText = "Game Center idle"
    @Published var lastError: String?
    @Published var rewardEvent: GameCenterRewardEvent?

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
        emitRewardIfAvailable(.dailyMystery(score: score, streak: streak))
        reportAchievement(WikiQuestAchievementID.firstSolve)
        if streak >= 7 { reportAchievement(WikiQuestAchievementID.streak7) }
        if streak >= 30 { reportAchievement(WikiQuestAchievementID.streak30) }
        reportScore(score, leaderboardID: WikiQuestLeaderboardID.dailyMysteryScore)
    }

    func reportWeeklyXP(_ xp: Int) {
        reportScore(max(0, xp), leaderboardID: WikiQuestLeaderboardID.weeklyXP)
    }

    func reportLinkRaceCompletion(elapsedSeconds: Int) {
        emitRewardIfAvailable(.linkRace(elapsedSeconds: elapsedSeconds))
        reportAchievement(WikiQuestAchievementID.linkRaceFinish)
        reportScore(max(1, elapsedSeconds), leaderboardID: WikiQuestLeaderboardID.linkRaceBestTime)
    }

    func reportNearbyResult(distanceMeters: Double, score: Int) {
        emitRewardIfAvailable(.nearby(distanceMeters: distanceMeters, score: score))
        if distanceMeters <= 100 {
            reportAchievement(WikiQuestAchievementID.nearbyBullseye)
        }
        reportScore(max(1, Int(distanceMeters.rounded())), leaderboardID: WikiQuestLeaderboardID.nearbyClosestGuess)
        if score > 0 {
            reportScore(score, leaderboardID: WikiQuestLeaderboardID.weeklyXP)
        }
    }

    func reportMemberFounder() {
        emitRewardIfAvailable(.memberFounder())
        reportAchievement(WikiQuestAchievementID.memberFounder)
    }

    func clearReward() {
        rewardEvent = nil
    }

    private func emitRewardIfAvailable(_ event: GameCenterRewardEvent) {
        guard canReportToGameCenter else { return }
        rewardEvent = event
    }

    private var canReportToGameCenter: Bool {
        #if canImport(GameKit)
        return GKLocalPlayer.local.isAuthenticated
        #else
        return false
        #endif
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
