import SwiftUI

struct LeaderboardView: View {
    let api: WikiQuestAPIClient
    @EnvironmentObject private var session: SessionStore
    @StateObject private var viewModel: LeaderboardViewModel
    @StateObject private var entitlements = EntitlementStore()

    init(api: WikiQuestAPIClient) {
        self.api = api
        _viewModel = StateObject(wrappedValue: LeaderboardViewModel(api: api))
    }

    var body: some View {
        WikiScreen(navigationTitle: "Leaderboard") {
            ScreenHeader(
                kicker: "RANKS",
                title: viewModel.tab == 0 ? "Member XP" : "Daily Board",
                detail: "Ticker ranks stay dense and readable for repeat checks."
            )

            LeaderboardBoardSwitch(selection: $viewModel.tab)

            if let error = viewModel.error {
                RecoveryNotice(
                    title: "RANKS OFFLINE",
                    detail: error,
                    actionTitle: "Retry ranks",
                    icon: "list.number",
                    tint: WikiTheme.red
                ) {
                    Task { await load() }
                }
                .accessibilityIdentifier("LeaderboardRecoveryNotice")
            }
            if let error = entitlements.error {
                RecoveryNotice(
                    title: "MEMBER CHECK",
                    detail: error,
                    actionTitle: "Retry member state",
                    icon: "person.crop.circle.badge.exclamationmark",
                    tint: WikiTheme.amber
                ) {
                    Task { await load() }
                }
                .accessibilityIdentifier("LeaderboardEntitlementRecoveryNotice")
            }

            if viewModel.isLoading || entitlements.isLoading {
                WikiLoadingGlyph(title: "SYNCING", detail: "Updating current ranks.", tint: WikiTheme.blue)
                    .accessibilityIdentifier("LeaderboardLoadingGlyph")
            }

            if viewModel.tab == 0 && entitlements.summary != nil && !entitlements.isMember {
                InlineNotice(title: "MEMBER", detail: "The XP leaderboard is a Member surface. Daily ranks stay visible.", tint: WikiTheme.amber)
            } else if viewModel.tab == 0 {
                RankList(rows: xpRows, isLoading: viewModel.isLoading || entitlements.isLoading, hasError: hasRecoveryError, refresh: load)
            } else {
                RankList(rows: dailyRows, isLoading: viewModel.isLoading || entitlements.isLoading, hasError: hasRecoveryError, refresh: load)
            }
        }
        .task(id: session.isSignedIn) { await load() }
        .refreshable { await load() }
    }

    private var xpRows: [RankDisplayRow] {
        viewModel.xpRows.enumerated().map { index, row in
            RankDisplayRow(rank: index + 1, title: row.displayName, detail: "Level \(row.level) / \(row.currentStreak)d streak", score: row.xp)
        }
    }

    private var dailyRows: [RankDisplayRow] {
        viewModel.dailyRows.map { row in
            RankDisplayRow(rank: row.rank, title: row.displayName, detail: "\(row.hintsRevealed) hints / \(WikiDisplayFormat.time(milliseconds: row.timeMs))", score: row.score)
        }
    }

    private var hasRecoveryError: Bool {
        viewModel.error != nil || entitlements.error != nil
    }

    private func load() async {
        async let board: Void = viewModel.load()
        async let entitlement: Void = entitlements.refresh(api: api, signedIn: session.isSignedIn)
        _ = await (board, entitlement)
    }

}

private struct LeaderboardBoardSwitch: View {
    @Binding var selection: Int

    private let boards = [
        (id: 0, title: "sys:member-xp", detail: "Member XP"),
        (id: 1, title: "sys:daily-board", detail: "Daily")
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(boards.enumerated()), id: \.element.id) { index, board in
                Button {
                    Haptics.light()
                    withAnimation(WikiMotion.quick) {
                        selection = board.id
                    }
                } label: {
                    VStack(spacing: 3) {
                        Text(board.title.uppercased())
                            .font(.caption2.weight(.black).monospaced())
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                        Text(board.detail)
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                    }
                    .foregroundStyle(selection == board.id ? WikiTheme.surfaceStrong : WikiTheme.ink)
                    .frame(maxWidth: .infinity)
                    .frame(height: 42)
                    .background(selection == board.id ? WikiTheme.ink : Color.clear)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if index < boards.count - 1 {
                    Rectangle()
                        .fill(WikiTheme.hairline)
                        .frame(width: 1, height: 26)
                }
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: WikiTheme.radius, style: .continuous)
                .stroke(WikiTheme.rule.opacity(0.72), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: WikiTheme.radius, style: .continuous))
        .accessibilityElement(children: .contain)
    }
}

private struct RankDisplayRow: Identifiable {
    let id = UUID()
    let rank: Int
    let title: String
    let detail: String
    let score: Int
}

private struct RankList: View {
    let rows: [RankDisplayRow]
    let isLoading: Bool
    let hasError: Bool
    let refresh: () async -> Void

    var body: some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            if rows.isEmpty && !isLoading && !hasError {
                RecoveryNotice(
                    title: "NO RUNS YET",
                    detail: "Fresh scores appear here after completed quests.",
                    actionTitle: "Refresh ranks",
                    icon: "arrow.clockwise",
                    tint: WikiTheme.blue
                ) {
                    Task { await refresh() }
                }
                .padding(.vertical, 2)
                .accessibilityIdentifier("LeaderboardEmptyRecoveryNotice")
            }
            ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                PanelReveal(delay: Double(index) * 0.025) {
                    RankRow(row: row)
                }
            }
        }
    }
}

private struct RankRow: View {
    let row: RankDisplayRow

    var body: some View {
        HStack(spacing: 12) {
            Text("#\(row.rank)")
                .font(.headline.monospaced())
                .foregroundStyle(row.rank <= 3 ? WikiTheme.amber : WikiTheme.blue)
                .frame(width: 48, alignment: .leading)
            VStack(alignment: .leading, spacing: 3) {
                Text(row.title)
                    .font(.headline)
                    .foregroundStyle(WikiTheme.ink)
                    .lineLimit(1)
                Text(row.detail)
                    .font(.caption)
                    .foregroundStyle(WikiTheme.muted)
                    .lineLimit(1)
            }
            Spacer()
            TickerNumberText(value: row.score)
                .foregroundStyle(WikiTheme.green)
        }
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) {
            Rectangle().fill(WikiTheme.rule.opacity(0.42)).frame(height: 1)
        }
    }
}
