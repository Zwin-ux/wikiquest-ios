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
        ModeTile(id: "mystery", title: "Mystery", detail: "Decode", icon: "questionmark.circle", color: WikiTheme.amber, tab: .mystery),
        ModeTile(id: "race", title: "Race", detail: "Link fast", icon: "link", color: WikiTheme.blue, tab: .race),
        ModeTile(id: "nearby", title: "Map", detail: "Pin it", icon: "mappin.and.ellipse", color: WikiTheme.green, tab: .nearby)
    ]

    var body: some View {
        WikiScreen(navigationTitle: "Deck", spacing: 16, showsWindowHeader: false) {
            QuestDeckCard(
                title: "Daily Mystery",
                detail: "Decode today's hidden page, then keep the trail alive.",
                media: deckArticle?.media,
                primaryMetric: WikiMetric(label: "Reset", text: WikiDisplayFormat.resetCountdown(now: now), tint: WikiTheme.amber),
                tint: WikiTheme.amber
            ) {
                navigate(.mystery)
            }

            MediaCreditRow(media: deckArticle?.media)
            HomeStats(profile: profile, entitlements: entitlements, signedIn: session.isSignedIn)

            HomeModeRail(modes: modes, navigate: navigate)

            DiscoveryPhotoRail(items: discoveryItems)

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

private struct HomeModeRail: View {
    let modes: [ModeTile]
    let navigate: (AppTab) -> Void
    @State private var selectedModeID: String?

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Kicker(text: "Play")
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(Array(modes.enumerated()), id: \.element.id) { index, mode in
                    PanelReveal(delay: Double(index) * 0.035) {
                        Button {
                            Haptics.light()
                            selectedModeID = mode.id
                            navigate(mode.tab)
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: mode.icon)
                                        .font(.headline.weight(.black))
                                        .foregroundStyle(mode.color)
                                    Spacer(minLength: 4)
                                    Circle()
                                        .fill(mode.color)
                                        .frame(width: 6, height: 6)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(mode.title)
                                        .font(.callout.weight(.black))
                                        .foregroundStyle(WikiTheme.ink)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.78)
                                    Text(mode.detail)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(WikiTheme.muted)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.74)
                                }
                            }
                            .frame(maxWidth: .infinity, minHeight: 86, alignment: .leading)
                            .padding(10)
                            .background(WikiTheme.surfaceStrong.opacity(0.62))
                            .overlay(alignment: .top) {
                                Rectangle().fill(mode.color).frame(height: 2)
                            }
                            .overlay {
                                RoundedRectangle(cornerRadius: WikiTheme.radius, style: .continuous)
                                    .stroke(WikiTheme.hairline, lineWidth: 1)
                            }
                            .clipShape(RoundedRectangle(cornerRadius: WikiTheme.radius, style: .continuous))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(ArcadePressStyle())
                        .motionTick(trigger: selectedModeID == mode.id ? selectedModeID : nil, tint: mode.color)
                    }
                }
            }
        }
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
