import Foundation

#if canImport(ActivityKit)
import ActivityKit
#endif

@MainActor
final class LiveActivityStore: ObservableObject {
    @Published var statusText = "Live Activities idle"

    #if canImport(ActivityKit)
    private var linkRaceActivity: Activity<LinkRaceActivityAttributes>?
    private var linkRaceState: LinkRaceActivityAttributes.ContentState?
    private var nearbyActivity: Activity<NearbyRevealActivityAttributes>?
    #endif

    func startLinkRace(start: String, target: String, startedAt: Date = Date()) {
        #if canImport(ActivityKit)
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        if let linkRaceActivity, let linkRaceState {
            Task {
                await linkRaceActivity.end(
                    ActivityContent(state: linkRaceState, staleDate: nil),
                    dismissalPolicy: .immediate
                )
            }
        }
        let attributes = LinkRaceActivityAttributes(
            runId: "link-race-\(UUID().uuidString)",
            startTitle: start,
            targetTitle: target
        )
        let state = LinkRaceActivityAttributes.ContentState(
            currentTitle: start,
            targetTitle: target,
            clicks: 0,
            startedAt: startedAt,
            endedAt: nil,
            pathTail: [start],
            completed: false
        )
        do {
            linkRaceActivity = try Activity.request(
                attributes: attributes,
                content: ActivityContent(state: state, staleDate: Date().addingTimeInterval(60 * 60 * 2)),
                pushType: nil
            )
            linkRaceState = state
            statusText = "Link Race Live Activity running"
        } catch {
            statusText = "Live Activity unavailable"
        }
        #endif
    }

    func updateLinkRace(
        current: String,
        target: String,
        clicks: Int,
        startedAt: Date,
        pathTail: [String]
    ) async {
        #if canImport(ActivityKit)
        let state = LinkRaceActivityAttributes.ContentState(
            currentTitle: current,
            targetTitle: target,
            clicks: clicks,
            startedAt: startedAt,
            endedAt: nil,
            pathTail: pathTail,
            completed: false
        )
        linkRaceState = state
        await linkRaceActivity?.update(ActivityContent(state: state, staleDate: Date().addingTimeInterval(60 * 60 * 2)))
        #endif
    }

    func endLinkRace(
        current: String,
        target: String,
        clicks: Int,
        startedAt: Date,
        endedAt: Date = Date(),
        pathTail: [String]
    ) async {
        #if canImport(ActivityKit)
        let state = LinkRaceActivityAttributes.ContentState(
            currentTitle: current,
            targetTitle: target,
            clicks: clicks,
            startedAt: startedAt,
            endedAt: endedAt,
            pathTail: pathTail,
            completed: true
        )
        await linkRaceActivity?.end(
            ActivityContent(state: state, staleDate: nil),
            dismissalPolicy: .after(Date().addingTimeInterval(20))
        )
        linkRaceActivity = nil
        linkRaceState = nil
        statusText = "Link Race Live Activity complete"
        #endif
    }

    func endLinkRaceIfNeeded() {
        #if canImport(ActivityKit)
        guard let linkRaceActivity, let linkRaceState else { return }
        Task {
            await linkRaceActivity.end(
                ActivityContent(state: linkRaceState, staleDate: nil),
                dismissalPolicy: .immediate
            )
        }
        self.linkRaceActivity = nil
        self.linkRaceState = nil
        statusText = "Link Race Live Activity ended"
        #endif
    }

    func showNearbyReveal(articleTitle: String, distanceText: String, score: Int) {
        #if canImport(ActivityKit)
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let attributes = NearbyRevealActivityAttributes(runId: "nearby-\(UUID().uuidString)")
        let state = NearbyRevealActivityAttributes.ContentState(
            articleTitle: articleTitle,
            distanceText: distanceText,
            score: score,
            revealedAt: Date()
        )
        Task {
            do {
                let activity = try Activity.request(
                    attributes: attributes,
                    content: ActivityContent(state: state, staleDate: nil),
                    pushType: nil
                )
                nearbyActivity = activity
                statusText = "Nearby reveal Live Activity shown"
                try? await Task.sleep(nanoseconds: 12_000_000_000)
                await activity.end(
                    ActivityContent(state: state, staleDate: nil),
                    dismissalPolicy: .after(Date().addingTimeInterval(20))
                )
                nearbyActivity = nil
            } catch {
                statusText = "Nearby Live Activity unavailable"
            }
        }
        #endif
    }
}
