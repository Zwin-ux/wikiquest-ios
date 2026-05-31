import SwiftUI

@main
struct WikiQuestApp: App {
    @StateObject private var session = SessionStore()
    @StateObject private var motion = MotionSettings()
    @StateObject private var gameCenter = GameCenterStore()
    @StateObject private var reminders = ReminderStore()
    @StateObject private var liveActivities = LiveActivityStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            let api = WikiQuestAPIClient(tokenProvider: { await session.bearerToken() })
            AppShell(api: api)
                .environmentObject(session)
                .environmentObject(motion)
                .environmentObject(gameCenter)
                .environmentObject(reminders)
                .environmentObject(liveActivities)
                .preferredColorScheme(.light)
                .task {
                    gameCenter.authenticate()
                    await session.validateAppleCredentialState()
                }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        gameCenter.authenticate()
                    }
                }
        }
    }
}
