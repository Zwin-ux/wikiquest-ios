import SwiftUI
#if canImport(WidgetKit)
import WidgetKit
#endif

private struct ModeTile: Identifiable {
    let id: String
    let title: String
    let detail: String
    let command: String
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
    @State private var dailyState: DailyRandomState?
    @State private var now = Date()
    @State private var deckArticle: WikiArticle?
    @State private var discoveryItems: [QuestDeckItem] = []
    private let wikipedia = WikipediaClient()
    private let discoveryRailLimit = 5

    private let modes = [
        ModeTile(id: "mystery", title: "Mystery", detail: "Photo clues", command: "Decode", icon: "questionmark.circle", color: WikiTheme.amber, tab: .mystery),
        ModeTile(id: "race", title: "Race", detail: "Blue links", command: "Run", icon: "link", color: WikiTheme.blue, tab: .race),
        ModeTile(id: "nearby", title: "Map", detail: "Map pins", command: "Drop pin", icon: "mappin.and.ellipse", color: WikiTheme.green, tab: .nearby)
    ]

    var body: some View {
        WikiScreen(navigationTitle: "Deck", spacing: 16, showsWindowHeader: false) {
            QuestDeckCard(
                title: dailyDeckVisual.title,
                detail: dailyDeckVisual.detail,
                media: dailyDeckVisual.media,
                visualState: dailyDeckVisual.visualState,
                fallbackStyle: .mystery,
                stateLabel: dailyDeckVisual.stateLabel,
                stateSystemImage: dailyDeckVisual.stateSystemImage,
                hudMetrics: deckMetrics,
                commandText: dailyDeckVisual.commandText,
                commandSystemImage: dailyDeckVisual.commandSystemImage,
                tint: WikiTheme.amber
            ) {
                navigate(.mystery)
            }
            .accessibilityIdentifier("QuestDeckCard")

            MediaCreditRow(media: dailyDeckVisual.media)

            HomeModeRail(
                modes: modes,
                discoveryItems: discoveryItems,
                deckMedia: deckArticle?.media,
                navigate: navigate
            )
            .accessibilityIdentifier("HomeModeRail")

            DiscoveryPhotoRail(
                items: discoveryItems,
                title: "Wiki drift",
                detail: "Random pages",
                showsTrailMarkers: true
            )
            .accessibilityIdentifier("HomeDiscoveryRail")

            ReminderPanel(store: reminders)
        }
        .task(id: session.isSignedIn) { await refresh() }
        .refreshable { await refresh() }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { tick in
            now = tick
        }
    }

    private var deckMetrics: [WikiMetric] {
        [
            WikiMetric(label: "Reset", text: WikiDisplayFormat.resetCountdown(now: now), tint: WikiTheme.amber),
            WikiMetric(label: "Hints", text: dailyHintText, tint: WikiTheme.amber),
            WikiMetric(label: "Streak", value: profile?.currentStreak ?? 0, tint: WikiTheme.amber),
            WikiMetric(label: "XP", value: profile?.xp ?? 0, tint: WikiTheme.blue)
        ]
    }

    private var dailyDeckVisual: DailyDeckVisualState {
        DailyDeckVisualState.make(from: dailyState)
    }

    private var dailyHintText: String {
        guard let dailyState else { return "0/6" }
        return "\(dailyState.hintsRevealed)/\(dailyState.totalHints)"
    }

    @MainActor
    private func refresh() async {
        guard session.isSignedIn else {
            profile = nil
            entitlements = nil
            dailyState = nil
            WikiQuestSnapshotStore.save(snapshot: .signedOut)
            return
        }
        async let profileTask = try? api.userProfile()
        async let entitlementTask = try? api.entitlements()
        async let dailyTask = try? api.dailyMystery()
        async let discoveryTask: Void = refreshDiscovery()
        profile = await profileTask
        entitlements = await entitlementTask
        dailyState = await dailyTask
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
        async let first: WikiArticle? = try? wikipedia.randomSummary()
        async let second: WikiArticle? = try? wikipedia.randomSummary()
        async let third: WikiArticle? = try? wikipedia.randomSummary()
        async let fourth: WikiArticle? = try? wikipedia.randomSummary()
        async let fifth: WikiArticle? = try? wikipedia.randomSummary()
        async let sixth: WikiArticle? = try? wikipedia.randomSummary()
        async let seventh: WikiArticle? = try? wikipedia.randomSummary()

        let articles = uniqueArticles(await [first, second, third, fourth, fifth, sixth, seventh].compactMap { $0 })
        let selectedDeck = articles.first { $0.media != nil } ?? articles.first
        deckArticle = selectedDeck

        discoveryItems = articles
            .filter { article in
                guard let selectedDeck else { return true }
                return article.id != selectedDeck.id
            }
            .prefix(discoveryRailLimit)
            .map { article in
                QuestDeckItem(
                    id: "\(article.id)-\(article.title)",
                    title: article.title,
                    detail: article.description ?? "Wikipedia article",
                    media: article.media,
                    tintName: "blue"
                )
            }
    }

    private func uniqueArticles(_ articles: [WikiArticle]) -> [WikiArticle] {
        var seenTitles = Set<String>()
        return articles.filter { article in
            seenTitles.insert(article.title).inserted
        }
    }
}

private struct HomeModeRail: View {
    let modes: [ModeTile]
    let discoveryItems: [QuestDeckItem]
    let deckMedia: WikiMedia?
    let navigate: (AppTab) -> Void
    @State private var selectedModeID: String?
    @State private var selectionToken = 0

    private let columns = [
        GridItem(.adaptive(minimum: 104), spacing: 8)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Kicker(text: "Choose quest")
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(Array(modes.enumerated()), id: \.element.id) { index, mode in
                    PanelReveal(delay: Double(index) * 0.035) {
                        Button {
                            Haptics.light()
                            selectedModeID = mode.id
                            selectionToken &+= 1
                            navigate(mode.tab)
                        } label: {
                            ModeDeckTile(mode: mode, media: media(for: index), index: index + 1)
                        }
                        .buttonStyle(ArcadePressStyle())
                        .commandLanePulse(
                            trigger: "\(selectedModeID ?? "none")-\(selectionToken)",
                            tint: mode.color,
                            enabled: selectedModeID == mode.id
                        )
                        .motionTick(trigger: selectedModeID == mode.id ? selectedModeID : nil, tint: mode.color)
                        .accessibilityIdentifier("HomeMode-\(mode.id)")
                    }
                }
            }
        }
    }

    private func media(for index: Int) -> WikiMedia? {
        if discoveryItems.indices.contains(index) {
            return discoveryItems[index].media ?? deckMedia
        }
        return deckMedia
    }
}

private struct ModeDeckTile: View {
    let mode: ModeTile
    let media: WikiMedia?
    let index: Int

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            ArticleHeroImage(
                media: media,
                title: mode.title,
                height: 118,
                tint: mode.color,
                fallbackStyle: mode.fallbackStyle
            )

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: mode.icon)
                        .font(.callout.weight(.black))
                        .foregroundStyle(.white)
                    Spacer(minLength: 4)
                    Text(String(format: "%02d", index))
                        .font(.caption2.weight(.black).monospaced())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(mode.color.opacity(0.88))
                        .clipShape(RoundedRectangle(cornerRadius: WikiTheme.radius, style: .continuous))
                }

                Spacer(minLength: 4)

                VStack(alignment: .leading, spacing: 2) {
                    Text(mode.title)
                        .font(.callout.weight(.black))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.76)
                    Text(mode.detail)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white.opacity(0.78))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }

                HStack(spacing: 6) {
                    Text(mode.command.uppercased())
                        .font(.caption2.weight(.black).monospaced())
                        .lineLimit(1)
                        .minimumScaleFactor(0.70)
                    Image(systemName: "arrow.right")
                        .font(.caption2.weight(.black))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(mode.color.opacity(0.88))
                .clipShape(RoundedRectangle(cornerRadius: WikiTheme.radius, style: .continuous))
            }
            .padding(10)
        }
        .frame(maxWidth: .infinity, minHeight: 118, alignment: .leading)
        .overlay(alignment: .topLeading) {
            Rectangle()
                .fill(mode.color)
                .frame(width: 28, height: 3)
                .padding(9)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(mode.title), \(mode.detail), \(mode.command)")
    }
}

private extension ModeTile {
    var fallbackStyle: MediaFallbackStyle {
        switch tab {
        case .mystery:
            return .mystery
        case .nearby:
            return .map
        default:
            return .article
        }
    }
}

private struct ReminderPanel: View {
    @ObservedObject var store: ReminderStore
    @State private var tapToken = 0

    var body: some View {
        Button {
            tapToken &+= 1
            Task {
                if store.isEnabled {
                    store.disableDailyReminders()
                } else {
                    await store.enableDailyReminders()
                }
            }
        } label: {
            HStack(alignment: .center, spacing: 11) {
                ZStack {
                    RoundedRectangle(cornerRadius: WikiTheme.radius, style: .continuous)
                        .fill(tint.opacity(0.12))
                    Image(systemName: store.isEnabled ? "bell.fill" : "bell")
                        .font(.callout.weight(.black))
                        .foregroundStyle(tint)
                }
                .frame(width: 42, height: 42)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 7) {
                        Kicker(text: "Daily signal")
                        Text(store.isEnabled ? "ON" : "OFF")
                            .font(.caption2.weight(.black).monospaced())
                            .foregroundStyle(tint)
                    }
                    Text(store.isEnabled ? "Reminder armed" : "Arm daily reminder")
                        .font(.callout.weight(.black))
                        .foregroundStyle(WikiTheme.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.76)
                    Text(store.statusText)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(WikiTheme.muted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                }

                Spacer(minLength: 8)

                HStack(spacing: 5) {
                    Text(store.isEnabled ? "DISARM" : "ARM")
                        .font(.caption2.weight(.black).monospaced())
                        .lineLimit(1)
                    Image(systemName: store.isEnabled ? "xmark" : "arrow.up.forward")
                        .font(.caption2.weight(.black))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(tint)
                .clipShape(RoundedRectangle(cornerRadius: WikiTheme.radius, style: .continuous))
            }
            .frame(maxWidth: .infinity, minHeight: 66, alignment: .leading)
            .padding(.vertical, 8)
            .overlay(alignment: .top) {
                Rectangle().fill(tint.opacity(0.74)).frame(height: 2)
            }
            .overlay(alignment: .bottom) {
                Rectangle().fill(WikiTheme.hairline).frame(height: 1)
            }
        }
        .buttonStyle(ArcadePressStyle())
        .commandLanePulse(trigger: tapToken, tint: tint, enabled: tapToken > 0)
        .motionTick(trigger: "\(store.isEnabled)-\(store.statusText)", tint: tint)
        .accessibilityIdentifier("HomeReminderCommand")
        .accessibilityLabel(store.isEnabled ? "Daily reminder on" : "Turn on daily reminder")
    }

    private var tint: Color {
        store.isEnabled ? WikiTheme.green : WikiTheme.amber
    }
}
