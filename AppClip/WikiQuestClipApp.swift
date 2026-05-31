import SwiftUI

@main
struct WikiQuestClipApp: App {
    @StateObject private var model = AppClipQuestViewModel()

    var body: some Scene {
        WindowGroup {
            AppClipView(model: model)
                .preferredColorScheme(.light)
                .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
                    Task {
                        await model.load(invocationURL: activity.webpageURL)
                    }
                }
        }
    }
}
