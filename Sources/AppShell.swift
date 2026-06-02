import SwiftUI

enum AppTab: Hashable, CaseIterable {
    case home
    case mystery
    case race
    case nearby
    case leaderboard
    case profile
}

struct AppShell: View {
    let api: WikiQuestAPIClient
    @EnvironmentObject private var session: SessionStore
    @EnvironmentObject private var gameCenter: GameCenterStore
    @State private var selectedTab: AppTab = .home
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if OnboardingGatePolicy.shouldShowOnboarding(isSignedIn: session.isSignedIn) {
                OnboardingGate(api: api)
            } else {
                tabShell
            }
        }
        .onAppear {
            openPendingRoute()
        }
        .onOpenURL { url in
            handle(url: url)
        }
        .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
            if let url = activity.webpageURL {
                handle(url: url)
            }
        }
        .onChange(of: session.isSignedIn) { _, signedIn in
            if signedIn {
                openPendingRoute()
            } else {
                selectedTab = .home
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                openPendingRoute()
                Task { await session.validateAppleCredentialState() }
            }
        }
    }

    private var tabShell: some View {
        TabView(selection: $selectedTab) {
            HomeView(api: api) { tab in
                select(tab)
            }
                .tag(AppTab.home)
            DailyMysteryView(api: api)
                .tag(AppTab.mystery)
            LinkRaceView(api: api)
                .tag(AppTab.race)
            NearbyView(api: api)
                .tag(AppTab.nearby)
            LeaderboardView(api: api)
                .tag(AppTab.leaderboard)
            ProfileView(api: api)
                .tag(AppTab.profile)
        }
        .tint(WikiTheme.blue)
        .toolbar(.hidden, for: .tabBar)
        .background(WikiPaperBackground())
        .safeAreaInset(edge: .top, spacing: 0) {
            WikiOSStatusBar(item: DockItem.item(for: selectedTab))
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            WikiDock(selection: $selectedTab, select: select)
        }
        .overlay(alignment: .top) {
            GameCenterRewardRibbon(event: gameCenter.rewardEvent)
                .padding(.horizontal, WikiTheme.screenPadding)
                .padding(.top, WikiTheme.osBarHeight + 8)
        }
        .onChange(of: gameCenter.rewardEvent?.id) { _, eventID in
            scheduleRewardDismissal(for: eventID)
        }
    }

    private func select(_ tab: AppTab) {
        guard selectedTab != tab else {
            Haptics.light()
            return
        }
        Haptics.light()
        withAnimation(WikiMotion.dock) {
            selectedTab = tab
        }
    }

    private func scheduleRewardDismissal(for eventID: UUID?) {
        guard let eventID else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.2) {
            guard gameCenter.rewardEvent?.id == eventID else { return }
            withAnimation(WikiMotion.panel) {
                gameCenter.clearReward()
            }
        }
    }

    private func openPendingRoute() {
        guard session.isSignedIn else { return }
        if let route = WikiQuestSnapshotStore.takePendingRoute() {
            select(route.tab)
        }
    }

    private func handle(url: URL) {
        guard let route = AppRoute(url: url) else { return }
        if session.isSignedIn {
            select(route.tab)
        } else {
            WikiQuestSnapshotStore.setPendingRoute(route)
        }
    }
}

private extension AppRoute {
    var tab: AppTab {
        switch self {
        case .home:
            return .home
        case .daily:
            return .mystery
        case .race:
            return .race
        case .nearby:
            return .nearby
        case .leaderboard:
            return .leaderboard
        case .profile:
            return .profile
        }
    }
}

struct DockItem: Identifiable {
    let tab: AppTab
    let title: String
    let accessibilityTitle: String
    let command: String
    let systemImage: String
    let accent: Color

    var id: AppTab { tab }
}

private extension DockItem {
    static let all: [DockItem] = [
        DockItem(tab: .home, title: "Today", accessibilityTitle: "Today", command: "today", systemImage: "square.grid.2x2", accent: WikiTheme.ink),
        DockItem(tab: .mystery, title: "Mystery", accessibilityTitle: "Mystery", command: "special:mystery", systemImage: "questionmark.circle", accent: WikiTheme.amber),
        DockItem(tab: .race, title: "Race", accessibilityTitle: "Race", command: "special:link-race", systemImage: "link", accent: WikiTheme.blue),
        DockItem(tab: .nearby, title: "Map", accessibilityTitle: "Nearby", command: "geo:nearby", systemImage: "mappin.and.ellipse", accent: WikiTheme.green),
        DockItem(tab: .leaderboard, title: "Ranks", accessibilityTitle: "Ranks", command: "sys:ranks", systemImage: "list.number", accent: WikiTheme.violet),
        DockItem(tab: .profile, title: "Me", accessibilityTitle: "Profile", command: "user:profile", systemImage: "person.crop.circle", accent: WikiTheme.red)
    ]

    static func item(for tab: AppTab) -> DockItem {
        all.first { $0.tab == tab } ?? all[0]
    }
}

private struct WikiOSStatusBar: View {
    let item: DockItem
    @EnvironmentObject private var session: SessionStore

    var body: some View {
        HStack(spacing: 10) {
            BrandMarkView(variant: .glyph, size: 23, animated: false)
            Text("WikiQuest")
                .font(.caption.weight(.black).monospaced())
                .foregroundStyle(WikiTheme.ink)
                .lineLimit(1)

            Rectangle()
                .fill(WikiTheme.hairline)
                .frame(width: 1, height: 20)

            HStack(spacing: 6) {
                Circle()
                    .fill(item.accent)
                    .frame(width: 6, height: 6)
                Text(item.command.uppercased())
                    .font(.caption2.weight(.bold).monospaced())
                    .foregroundStyle(WikiTheme.muted)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Text(session.isSignedIn ? "Saved" : "Sign in")
                .font(.caption2.weight(.bold).monospaced())
                .foregroundStyle(session.isSignedIn ? WikiTheme.green : WikiTheme.muted)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .padding(.horizontal, WikiTheme.screenPadding)
        .frame(height: WikiTheme.osBarHeight)
        .background(WikiTheme.surfaceStrong.opacity(0.96))
        .overlay(alignment: .bottom) {
            Rectangle().fill(WikiTheme.hairline).frame(height: 1)
        }
        .accessibilityIdentifier("WikiOSStatusBar")
    }
}

struct WikiDock: View {
    @Binding var selection: AppTab
    let select: (AppTab) -> Void
    @EnvironmentObject private var motion: MotionSettings

    var body: some View {
        HStack(spacing: 6) {
            HStack(spacing: 6) {
                BrandMarkView(variant: .glyph, size: 28, animated: false)
            }
            .frame(width: 52, height: 48)
            .overlay {
                RoundedRectangle(cornerRadius: WikiTheme.radius, style: .continuous)
                    .stroke(WikiTheme.surfaceStrong.opacity(0.18), lineWidth: 1)
            }
            .accessibilityHidden(true)

            ForEach(DockItem.all) { item in
                Button {
                    select(item.tab)
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: item.systemImage)
                            .font(.system(size: 16, weight: .bold))
                            .frame(width: 24, height: 22)
                            .foregroundStyle(selection == item.tab ? WikiTheme.surfaceStrong : WikiTheme.surfaceStrong.opacity(0.62))
                        Text(item.title)
                            .font(.system(size: 9, weight: selection == item.tab ? .black : .semibold, design: .monospaced))
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                            .foregroundStyle(selection == item.tab ? WikiTheme.surfaceStrong : WikiTheme.surfaceStrong.opacity(0.62))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .contentShape(Rectangle())
                    .background(selection == item.tab ? item.accent.opacity(0.22) : Color.clear)
                    .overlay(alignment: .top) {
                        if selection == item.tab {
                            Rectangle()
                                .fill(item.accent)
                                .frame(height: 3)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: WikiTheme.radius, style: .continuous))
                }
                .buttonStyle(ArcadePressStyle())
                .accessibilityLabel(item.accessibilityTitle)
                .accessibilityAddTraits(selection == item.tab ? .isSelected : [])
                .accessibilityIdentifier(item.dockIdentifier)
                .commandLanePulse(trigger: selection, tint: item.accent, enabled: selection == item.tab)
            }
        }
        .padding(.horizontal, 10)
        .padding(.top, 9)
        .padding(.bottom, 10)
        .frame(height: WikiTheme.dockHeight)
        .background(WikiTheme.dockBackground)
        .overlay(alignment: .top) {
            Rectangle().fill(WikiTheme.surfaceStrong.opacity(0.20)).frame(height: 1)
        }
        .accessibilityIdentifier("WikiDock")
        .animation(WikiMotion.active(WikiMotion.dock, reduceMotion: motion.reduceMotion), value: selection)
    }
}

private extension DockItem {
    var dockIdentifier: String {
        switch tab {
        case .home:
            return "WikiDock-today"
        case .mystery:
            return "WikiDock-mystery"
        case .race:
            return "WikiDock-race"
        case .nearby:
            return "WikiDock-map"
        case .leaderboard:
            return "WikiDock-ranks"
        case .profile:
            return "WikiDock-profile"
        }
    }
}
