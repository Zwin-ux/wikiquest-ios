import SwiftUI
#if canImport(WidgetKit)
import WidgetKit
#endif

private struct ModeTile: Identifiable {
    let id: String
    let title: String
    let detail: String
    let icon: String
    let color: Color
    let tab: AppTab
}

struct HomeView: View {
    let api: WikiQuestAPIClient
    let navigate: (AppTab) -> Void
    @EnvironmentObject private var session: SessionStore
    @EnvironmentObject private var reminders: ReminderStore
    @State private var profile: UserProfile?
    @State private var entitlements: EntitlementSummary?
    @State private var now = Date()
    @State private var deckArticle: WikiArticle?
    @State private var discoveryItems: [QuestDeckItem] = []
    private let wikipedia = WikipediaClient()

    private let modes = [
        ModeTile(id: "mystery", title: "Mystery", detail: "Decode the hidden page.", icon: "questionmark.circle", color: WikiTheme.amber, tab: .mystery),
        ModeTile(id: "race", title: "Race", detail: "Move through blue links.", icon: "link", color: WikiTheme.blue, tab: .race),
        ModeTile(id: "nearby", title: "Map", detail: "Guess where the page lives.", icon: "mappin.and.ellipse", color: WikiTheme.green, tab: .nearby)
    ]

    var body: some View {
        WikiScreen(navigationTitle: "Today", spacing: 20) {
            HomeOSHeader(displayName: session.displayName, now: now)
            HomeStats(profile: profile, entitlements: entitlements, signedIn: session.isSignedIn)

            QuestDeckCard(
                title: "Today's Quest",
                detail: "Start with Mystery. Keep going into Race or Map.",
                media: deckArticle?.media,
                primaryMetric: WikiMetric(label: "Reset", text: WikiDisplayFormat.resetCountdown(now: now), tint: WikiTheme.amber),
                tint: WikiTheme.ink
            ) {
                navigate(.mystery)
            }

            DiscoveryPhotoRail(items: discoveryItems)

            FlatSection(title: "Modes") {
                ForEach(Array(modes.enumerated()), id: \.element.id) { index, mode in
                    PanelReveal(delay: Double(index) * 0.035) {
                        ModeRow(title: mode.title, detail: mode.detail, systemImage: mode.icon, tint: mode.color) {
                            navigate(mode.tab)
                        }
                    }
                }
            }

            ReminderPanel(store: reminders)
        }
        .task(id: session.isSignedIn) { await refresh() }
        .refreshable { await refresh() }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { tick in
            now = tick
        }
    }

    @MainActor
    private func refresh() async {
        guard session.isSignedIn else {
            profile = nil
            entitlements = nil
            WikiQuestSnapshotStore.save(snapshot: .signedOut)
            return
        }
        async let profileTask = try? api.userProfile()
        async let entitlementTask = try? api.entitlements()
        async let discoveryTask: Void = refreshDiscovery()
        profile = await profileTask
        entitlements = await entitlementTask
        _ = await discoveryTask
        WikiQuestSnapshotStore.save(
            snapshot: WikiQuestWidgetSnapshot(
                displayName: profile?.customDisplayName ?? profile?.displayName ?? session.displayName,
                streak: profile?.currentStreak ?? 0,
                xp: profile?.xp ?? 0,
                isMember: entitlements?.isMember == true,
                dailyTitle: "Daily Mystery",
                updatedAt: Date()
            )
        )
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }

    @MainActor
    private func refreshDiscovery() async {
        var articles: [WikiArticle] = []
        for _ in 0..<4 {
            if let article = try? await wikipedia.randomSummary() {
                articles.append(article)
            }
        }
        deckArticle = articles.first { $0.media != nil } ?? articles.first
        discoveryItems = articles.dropFirst().prefix(3).map { article in
            QuestDeckItem(
                id: "\(article.id)-\(article.title)",
                title: article.title,
                detail: article.description ?? "Wikipedia article",
                media: article.media,
                tintName: "blue"
            )
        }
    }
}

private struct HomeOSHeader: View {
    let displayName: String
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                BrandMarkView(variant: .glyph, size: 38, animated: true)
                VStack(alignment: .leading, spacing: 3) {
                    Kicker(text: WikiDisplayFormat.todayLabel(now: now))
                    Text("Ready, \(displayName).")
                        .font(.system(.title3, design: .serif).weight(.black))
                        .foregroundStyle(WikiTheme.ink)
                        .lineLimit(2)
                        .minimumScaleFactor(0.78)
                }
                Spacer(minLength: 8)
                Text("DECK")
                    .font(.caption.weight(.black).monospaced())
                    .foregroundStyle(WikiTheme.green)
            }
            Text("One Wikipedia trail for the day: solve, race, place the pin.")
                .font(.callout)
                .foregroundStyle(WikiTheme.muted)
                .lineSpacing(3)
        }
        .overlay(alignment: .top) {
            Rectangle().fill(WikiTheme.ink).frame(height: 2)
        }
        .overlay(alignment: .bottom) {
            Rectangle().fill(WikiTheme.hairline).frame(height: 1)
        }
    }
}

private struct HomeStats: View {
    let profile: UserProfile?
    let entitlements: EntitlementSummary?
    let signedIn: Bool

    var body: some View {
        StatusStrip(items: [
            WikiMetric(label: "Streak", value: signedIn ? profile?.currentStreak ?? 0 : 0, tint: WikiTheme.amber),
            WikiMetric(label: "XP", value: signedIn ? profile?.xp ?? 0 : 0, tint: WikiTheme.blue),
            WikiMetric(label: "Member", text: entitlements?.isMember == true ? "ON" : "OFF", tint: entitlements?.isMember == true ? WikiTheme.green : WikiTheme.muted)
        ])
    }
}

private struct ReminderPanel: View {
    @ObservedObject var store: ReminderStore

    var body: some View {
        FlatSection(title: "Reminder") {
            CommandRow(
                title: store.isEnabled ? "Daily reminder on" : "Turn on daily reminder",
                detail: store.statusText,
                systemImage: store.isEnabled ? "bell.fill" : "bell",
                tint: store.isEnabled ? WikiTheme.green : WikiTheme.amber
            ) {
                Task {
                    if store.isEnabled {
                        store.disableDailyReminders()
                    } else {
                        await store.enableDailyReminders()
                    }
                }
            }
        }
    }
}
