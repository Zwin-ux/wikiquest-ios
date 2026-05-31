import AppIntents
import Foundation

protocol WikiQuestRouteIntent: AppIntent {}

extension WikiQuestRouteIntent {
    static var openAppWhenRun: Bool { true }

    func open(_ route: AppRoute) -> some IntentResult {
        WikiQuestSnapshotStore.setPendingRoute(route)
        return .result()
    }
}
struct OpenDailyMysteryIntent: WikiQuestRouteIntent {
    static var title: LocalizedStringResource = "Open Daily Mystery"
    static var description = IntentDescription("Open today’s WikiQuest mystery.")

    func perform() async throws -> some IntentResult {
        open(.daily)
    }
}

struct StartLinkRaceIntent: WikiQuestRouteIntent {
    static var title: LocalizedStringResource = "Start Link Race"
    static var description = IntentDescription("Open WikiQuest Link Race.")

    func perform() async throws -> some IntentResult {
        open(.race)
    }
}

struct OpenNearbyQuestIntent: WikiQuestRouteIntent {
    static var title: LocalizedStringResource = "Open Nearby"
    static var description = IntentDescription("Open the nearby Wikipedia map quest.")

    func perform() async throws -> some IntentResult {
        open(.nearby)
    }
}

struct OpenWikiQuestProfileIntent: WikiQuestRouteIntent {
    static var title: LocalizedStringResource = "Open Profile"
    static var description = IntentDescription("Open your WikiQuest profile.")

    func perform() async throws -> some IntentResult {
        open(.profile)
    }
}

struct WikiQuestShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: OpenDailyMysteryIntent(),
            phrases: [
                "Open \(.applicationName) Daily Mystery",
                "Play \(.applicationName)"
            ],
            shortTitle: "Daily Mystery",
            systemImageName: "questionmark.circle"
        )
        AppShortcut(
            intent: StartLinkRaceIntent(),
            phrases: [
                "Start \(.applicationName) Link Race",
                "Race in \(.applicationName)"
            ],
            shortTitle: "Link Race",
            systemImageName: "link"
        )
        AppShortcut(
            intent: OpenNearbyQuestIntent(),
            phrases: [
                "Open \(.applicationName) Nearby",
                "Find nearby articles in \(.applicationName)"
            ],
            shortTitle: "Nearby",
            systemImageName: "mappin.and.ellipse"
        )
        AppShortcut(
            intent: OpenWikiQuestProfileIntent(),
            phrases: [
                "Open \(.applicationName) Profile"
            ],
            shortTitle: "Profile",
            systemImageName: "person.crop.circle"
        )
    }
}
