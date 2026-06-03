import SwiftUI
#if canImport(WidgetKit)
import WidgetKit
#endif

struct ProfileView: View {
    let api: WikiQuestAPIClient
    @EnvironmentObject private var session: SessionStore
    @EnvironmentObject private var gameCenter: GameCenterStore
    @StateObject private var viewModel: ProfileViewModel
    @StateObject private var purchases = PurchaseStore()
    @State private var showDeleteConfirmation = false
    @State private var showRevenueCatPaywall = false
    @State private var showCustomerCenter = false
    @State private var isDeletingAccount = false
    @State private var deleteMessage: String?

    init(api: WikiQuestAPIClient) {
        self.api = api
        _viewModel = StateObject(wrappedValue: ProfileViewModel(api: api))
    }

    var body: some View {
        WikiScreen(navigationTitle: "Profile") {
            ProfileOSHeader(
                displayName: session.isSignedIn ? viewModel.displayName : "Signed out",
                statusText: session.statusText,
                isSignedIn: session.isSignedIn
            )
            .accessibilityIdentifier("ProfileOSHeader")

            if viewModel.isLoading {
                WikiLoadingGlyph(title: "SYNCING", detail: "Refreshing account, XP, and discoveries.", tint: WikiTheme.blue)
                    .accessibilityIdentifier("ProfileLoadingGlyph")
            }
            if let error = viewModel.error {
                RecoveryNotice(
                    title: "PROFILE OFFLINE",
                    detail: error,
                    actionTitle: "Retry profile",
                    icon: "person.crop.circle.badge.exclamationmark",
                    tint: WikiTheme.red
                ) {
                    Task { await viewModel.load(signedIn: session.isSignedIn) }
                }
                .accessibilityIdentifier("ProfileRecoveryNotice")
            }
            if let error = session.lastAuthError {
                RecoveryNotice(
                    title: "APPLE ID",
                    detail: error,
                    actionTitle: "Check account",
                    icon: "apple.logo",
                    tint: WikiTheme.red
                ) {
                    Task { await session.validateAppleCredentialState() }
                }
                .accessibilityIdentifier("ProfileAuthRecoveryNotice")
            }

            ProfileStats(profile: viewModel.profile, entitlements: viewModel.entitlements)
            DiscoveryPhotoRail(items: viewModel.discoveredItems)
            ProfileEditor(viewModel: viewModel)
            MemberPanel(
                purchases: purchases,
                entitlements: viewModel.entitlements,
                openPaywall: { showRevenueCatPaywall = true },
                openCustomerCenter: { showCustomerCenter = true },
                refresh: refreshMembershipState
            )
            GameCenterPanel(store: gameCenter)
            MysteryProfileStats(stats: viewModel.mysteryStats, daily: viewModel.dailyLeaderboard)
            BarnstarsPanel(barnstars: viewModel.profile?.barnstars ?? [])
            ContributionLogPanel(entries: viewModel.contributionLog)
            CommandButton(title: "Sign out", icon: "rectangle.portrait.and.arrow.right", tint: WikiTheme.red) {
                session.signOut()
            }
            CommandButton(
                title: isDeletingAccount ? "Deleting account" : "Delete account",
                icon: "trash",
                tint: WikiTheme.red,
                isDisabled: isDeletingAccount
            ) {
                showDeleteConfirmation = true
            }

            if let message = purchases.message {
                InlineNotice(title: "STORE", detail: message, tint: purchases.storeEntitlementActive ? WikiTheme.green : WikiTheme.muted)
            }
            if let deleteMessage {
                InlineNotice(title: "ACCOUNT", detail: deleteMessage, tint: WikiTheme.red)
            }

            LegalLinks()
        }
        .task(id: session.isSignedIn) {
            await purchases.prepareForUser(session.accountUserId)
            await viewModel.load(signedIn: session.isSignedIn)
        }
        .refreshable { await viewModel.load(signedIn: session.isSignedIn) }
        .sheet(isPresented: $showRevenueCatPaywall, onDismiss: {
            Task { await refreshMembershipState() }
        }) {
            RevenueCatPaywallSheet(purchases: purchases)
        }
        .sheet(isPresented: $showCustomerCenter, onDismiss: {
            Task { await refreshMembershipState() }
        }) {
            RevenueCatCustomerCenterSheet(purchases: purchases)
        }
        .alert("Delete WikiQuest account?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task { await deleteAccount() }
            }
        } message: {
            Text("This removes saved profile, XP, leaderboard identity, and contribution log from WikiQuest. App Store purchase history stays with Apple.")
        }
    }

    private func refreshMembershipState() async {
        await purchases.refreshCustomerInfo()
        await viewModel.load(signedIn: session.isSignedIn)
        if viewModel.entitlements?.isMember == true || purchases.storeEntitlementActive {
            gameCenter.reportMemberFounder()
        }
    }

    private func deleteAccount() async {
        guard !isDeletingAccount else { return }
        isDeletingAccount = true
        defer { isDeletingAccount = false }
        do {
            let response = try await api.deleteAccount()
            if response.deleted {
                deleteMessage = nil
                session.signOut()
                WikiQuestSnapshotStore.save(snapshot: .signedOut)
                #if canImport(WidgetKit)
                WidgetCenter.shared.reloadAllTimelines()
                #endif
                Haptics.success()
            }
        } catch {
            deleteMessage = error.localizedDescription
            Haptics.error()
        }
    }
}

private struct ProfileOSHeader: View {
    let displayName: String
    let statusText: String
    let isSignedIn: Bool

    var body: some View {
        WikiOSPanel(title: "Account", status: isSignedIn ? "Signed in" : "Offline", tint: isSignedIn ? WikiTheme.green : WikiTheme.red) {
            HStack(alignment: .top, spacing: 12) {
                BrandMarkView(variant: .glyph, size: 42, animated: false)
                VStack(alignment: .leading, spacing: 5) {
                    Text(displayName)
                        .font(.system(.title3, design: .monospaced).weight(.black))
                        .foregroundStyle(WikiTheme.ink)
                        .lineLimit(2)
                        .minimumScaleFactor(0.74)
                    Text(statusText)
                        .font(.callout)
                        .foregroundStyle(WikiTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

private struct ProfileStats: View {
    let profile: UserProfile?
    let entitlements: EntitlementSummary?

    var body: some View {
        StatusStrip(items: [
            StatusMetricItem(label: "XP", value: profile?.xp ?? 0, color: WikiTheme.blue),
            StatusMetricItem(label: "Streak", value: profile?.currentStreak ?? 0, color: WikiTheme.amber),
            StatusMetricItem(label: "Member", text: entitlements?.isMember == true ? "ON" : "OFF", color: entitlements?.isMember == true ? WikiTheme.green : WikiTheme.muted)
        ])
    }
}

private struct ProfileEditor: View {
    @ObservedObject var viewModel: ProfileViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Kicker(text: "Profile")
                Spacer()
                Button(viewModel.isEditing ? "Cancel" : (viewModel.isMember ? "Edit" : "Edit (Member)")) {
                    if viewModel.isEditing {
                        viewModel.isEditing = false
                    } else {
                        viewModel.openEditor()
                    }
                }
                .font(.caption.weight(.bold))
                .foregroundStyle(WikiTheme.blue)
                .buttonStyle(ArcadePressStyle())
            }

            if viewModel.isEditing {
                TextField("Display name", text: $viewModel.nameInput)
                    .textInputAutocapitalization(.words)
                    .padding(.vertical, 8)
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(WikiTheme.rule).frame(height: 1)
                    }
                TextEditor(text: $viewModel.bioInput)
                    .frame(minHeight: 78)
                    .scrollContentBackground(.hidden)
                    .background(WikiTheme.paper)
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(WikiTheme.rule).frame(height: 1)
                    }
                HStack {
                    Text("\(viewModel.bioInput.count)/280")
                        .font(.caption.monospaced())
                        .foregroundStyle(WikiTheme.muted)
                    Spacer()
                    Button("Save") {
                        Task { await viewModel.saveEditor() }
                    }
                    .font(.callout.weight(.bold))
                    .foregroundStyle(WikiTheme.blue)
                    .buttonStyle(ArcadePressStyle())
                }
            } else if let bio = viewModel.profile?.bio, !bio.isEmpty {
                Text(bio)
                    .font(.callout)
                    .foregroundStyle(WikiTheme.ink)
                    .lineSpacing(3)
            } else {
                Text(viewModel.isMember ? "Tap edit to add a short profile note." : "Members can add a short profile note.")
                    .font(.callout)
                    .foregroundStyle(WikiTheme.muted)
            }

            if let saveError = viewModel.saveError {
                InlineNotice(title: "PROFILE", detail: saveError, tint: WikiTheme.red)
            }
        }
        .padding(.vertical, 10)
        .overlay(alignment: .top) {
            Rectangle().fill(WikiTheme.rule.opacity(0.45)).frame(height: 1)
        }
    }
}

private struct MemberPanel: View {
    @ObservedObject var purchases: PurchaseStore
    let entitlements: EntitlementSummary?
    let openPaywall: () -> Void
    let openCustomerCenter: () -> Void
    let refresh: () async -> Void

    private var isMember: Bool {
        entitlements?.isMember == true || purchases.subscription.isMember || purchases.storeEntitlementActive
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            InlineNotice(
                title: "MEMBER",
                detail: isMember ? purchases.subscription.statusText : "Monthly and annual plans are handled by the App Store.",
                tint: isMember ? WikiTheme.green : WikiTheme.blue
            )
            CommandButton(title: "View Member plans", icon: "rectangle.stack.badge.person.crop", tint: WikiTheme.blue, isDisabled: purchases.isLoading) {
                openPaywall()
            }
            ForEach(purchases.packages) { package in
                CommandButton(
                    title: "\(package.title) / \(package.price)",
                    icon: package.isAnnual ? "sparkles" : "calendar",
                    tint: package.isAnnual ? WikiTheme.green : WikiTheme.blue,
                    isDisabled: purchases.isLoading
                ) {
                    Task {
                        await purchases.purchase(productId: package.id)
                        await refresh()
                    }
                }
            }
            if purchases.hasLoadedOfferings && purchases.packages.isEmpty {
                InlineNotice(
                    title: "OFFERING",
                    detail: "No Member packages are in the current RevenueCat Offering yet.",
                    tint: WikiTheme.amber
                )
            }
            CommandButton(title: "Restore purchases", icon: "arrow.clockwise", tint: WikiTheme.ink, isDisabled: purchases.isLoading) {
                Task {
                    await purchases.restore()
                    await refresh()
                }
            }
            CommandButton(title: "Purchase settings", icon: "person.crop.circle.badge.questionmark", tint: WikiTheme.violet, isDisabled: purchases.isLoading) {
                openCustomerCenter()
            }
        }
    }
}

private struct GameCenterPanel: View {
    @ObservedObject var store: GameCenterStore

    var body: some View {
        FlatSection(title: "Game Center") {
            CommandRow(
                title: store.isAuthenticated ? "Game Center connected" : "Connect Game Center",
                detail: store.statusText,
                systemImage: "gamecontroller",
                tint: store.isAuthenticated ? WikiTheme.green : WikiTheme.violet
            ) {
                store.authenticate()
            }
            if let error = store.lastError {
                RecoveryNotice(
                    title: "GAME CENTER",
                    detail: error,
                    actionTitle: "Try again",
                    icon: "gamecontroller",
                    tint: WikiTheme.violet
                ) {
                    store.authenticate()
                }
                .accessibilityIdentifier("GameCenterRecoveryNotice")
            }
        }
    }
}

private struct MysteryProfileStats: View {
    let stats: MysteryStats?
    let daily: DailyLeaderboard?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Kicker(text: "Mystery")
            StatusStrip(items: [
                StatusMetricItem(label: "Solved", value: stats?.totalSolved ?? 0, color: WikiTheme.green),
                StatusMetricItem(label: "Best", value: stats?.bestScore ?? 0, color: WikiTheme.blue),
                StatusMetricItem(label: "Rank", value: daily?.viewer?.rank ?? 0, color: WikiTheme.amber)
            ])
        }
    }
}

private struct BarnstarsPanel: View {
    let barnstars: [Barnstar]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Kicker(text: "Barnstars")
            if barnstars.isEmpty {
                Text("Complete runs to earn Barnstars.")
                    .foregroundStyle(WikiTheme.muted)
            } else {
                ForEach(barnstars) { star in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "star.fill")
                            .foregroundStyle(WikiTheme.amber)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(star.name).font(.headline)
                            Text(star.description)
                                .font(.caption)
                                .foregroundStyle(WikiTheme.muted)
                        }
                    }
                    .padding(.vertical, 8)
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(WikiTheme.rule.opacity(0.34)).frame(height: 1)
                    }
                }
            }
        }
    }
}

private struct ContributionLogPanel: View {
    let entries: [ContributionLogEntry]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Kicker(text: "Contribution log")
            if entries.isEmpty {
                Text("No saved runs yet.")
                    .foregroundStyle(WikiTheme.muted)
            } else {
                ForEach(entries.prefix(20)) { entry in
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.articleTitle)
                                .font(.callout.weight(.semibold))
                                .foregroundStyle(WikiTheme.ink)
                                .lineLimit(1)
                            Text("\(entry.mode) / \(entry.completedAt.prefix(10))")
                                .font(.caption)
                                .foregroundStyle(WikiTheme.muted)
                        }
                        Spacer()
                        TickerNumberText(value: entry.xpEarned, suffix: " XP")
                            .foregroundStyle(WikiTheme.green)
                    }
                    .padding(.vertical, 8)
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(WikiTheme.rule.opacity(0.34)).frame(height: 1)
                    }
                }
            }
        }
    }
}

private enum LegalPage: String, Identifiable {
    case privacy = "Privacy"
    case terms = "Terms"

    var id: String { rawValue }

    var externalURL: URL {
        switch self {
        case .privacy:
            return WikiQuestConfig.apiBaseURL.appending(path: "privacy")
        case .terms:
            return WikiQuestConfig.apiBaseURL.appending(path: "terms")
        }
    }

    var bodyText: String {
        switch self {
        case .privacy:
            return "WikiQuest uses your account to save gameplay progress, purchases, XP, streaks, and leaderboard records. Nearby mode asks for location permission only to find local Wikipedia articles and place map guesses."
        case .terms:
            return "WikiQuest is an alpha TestFlight build. Gameplay uses Wikipedia content and the existing WikiQuest API. Native Member purchases use the App Store purchase flow and can be restored from this device."
        }
    }
}

private struct LegalLinks: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Kicker(text: "Legal")
            ForEach([LegalPage.privacy, LegalPage.terms]) { page in
                NavigationLink {
                    LegalView(page: page)
                } label: {
                    HStack {
                        Text(page.rawValue)
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(WikiTheme.blue)
                    .padding(.vertical, 8)
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(WikiTheme.rule.opacity(0.34)).frame(height: 1)
                    }
                }
                .buttonStyle(ArcadePressStyle())
            }
        }
    }
}

private struct LegalView: View {
    let page: LegalPage

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ScreenHeader(kicker: "LEGAL", title: page.rawValue, detail: page.bodyText)
                Link("Open current web policy", destination: page.externalURL)
                    .font(.callout.weight(.bold))
                    .foregroundStyle(WikiTheme.blue)
            }
            .padding(WikiTheme.screenPadding)
        }
        .background(WikiTheme.paper.ignoresSafeArea())
        .navigationTitle(page.rawValue)
        .toolbar(.visible, for: .navigationBar)
    }
}
