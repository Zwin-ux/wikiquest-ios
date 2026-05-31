import SwiftUI

struct LinkRaceView: View {
    let api: WikiQuestAPIClient
    @EnvironmentObject private var session: SessionStore
    @EnvironmentObject private var gameCenter: GameCenterStore
    @EnvironmentObject private var liveActivities: LiveActivityStore
    @StateObject private var viewModel: LinkRaceViewModel
    @State private var now = Date()

    init(api: WikiQuestAPIClient) {
        self.api = api
        _viewModel = StateObject(wrappedValue: LinkRaceViewModel(api: api))
    }

    var body: some View {
        WikiScreen(navigationTitle: "Link Race") {
            ScreenHeader(
                kicker: "SPECIAL:LINKRACE",
                title: routeTitle,
                detail: "Start on one Wikipedia page and reach the target through blue links."
            )

            if let error = viewModel.error {
                InlineNotice(title: "ERROR", detail: error, tint: WikiTheme.red)
            }

            if let loadingTitle = viewModel.loadingTitle {
                WikiLoadingGlyph(title: "LOADING", detail: loadingTitle, tint: WikiTheme.blue)
            }

            if let current = viewModel.current {
                RacePhotoStage(
                    current: current.article,
                    target: viewModel.targetArticle,
                    fallbackTargetTitle: viewModel.targets?.target,
                    clicks: viewModel.clickCount,
                    elapsed: viewModel.elapsedSeconds(now: now),
                    xp: viewModel.savedXP ?? 0
                )
                    .id(current.article.title)
                    .transition(.move(edge: .trailing).combined(with: .opacity))

                if !viewModel.completed {
                    LinkChoiceList(
                        links: current.links,
                        visitedTitles: viewModel.visitedTitles,
                        loadingTitle: viewModel.loadingTitle,
                        mediaFor: viewModel.media(for:)
                    ) { link in
                        Task { await viewModel.move(to: link.title, session: session) }
                    }
                }
            }

            if viewModel.completed {
                ResultPanel(
                    isCorrect: true,
                    score: viewModel.savedXP ?? 0,
                    answer: viewModel.targets?.target,
                    shareText: linkRaceShareText
                )
                CommandButton(title: "New race", icon: "arrow.clockwise", tint: WikiTheme.blue) {
                    Task { await viewModel.newRace() }
                }
            }

            VisualBreadcrumb(path: viewModel.path, tint: WikiTheme.blue)

            if viewModel.current == nil && viewModel.error == nil {
                WikiLoadingGlyph(title: "READY", detail: "Picking a start and target.", tint: WikiTheme.blue)
            }
        }
        .task { await viewModel.newRace() }
        .refreshable {
            liveActivities.endLinkRaceIfNeeded()
            await viewModel.newRace()
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { tick in
            now = tick
        }
        .onChange(of: viewModel.targets) { _, targets in
            if let targets, let startedAt = viewModel.startedAt {
                liveActivities.startLinkRace(start: targets.start, target: targets.target, startedAt: startedAt)
            } else {
                liveActivities.endLinkRaceIfNeeded()
            }
        }
        .onChange(of: viewModel.current?.article.title) { _, _ in
            Task { await syncLinkRaceActivity() }
        }
        .onChange(of: viewModel.path) { _, _ in
            Task { await syncLinkRaceActivity() }
        }
        .onChange(of: viewModel.completed) { _, completed in
            guard
                completed,
                let current = viewModel.current?.article.title,
                let target = viewModel.targets?.target,
                let startedAt = viewModel.startedAt
            else { return }
            let elapsed = viewModel.elapsedSeconds(now: now)
            gameCenter.reportLinkRaceCompletion(elapsedSeconds: elapsed)
            Task {
                await liveActivities.endLinkRace(
                    current: current,
                    target: target,
                    clicks: viewModel.clickCount,
                    startedAt: startedAt,
                    endedAt: viewModel.completedAt ?? now,
                    pathTail: pathTail
                )
            }
        }
    }

    private var routeTitle: String {
        guard let targets = viewModel.targets else { return "Picking a route" }
        return "\(targets.start) to \(targets.target)"
    }

    private var linkRaceShareText: String {
        guard let targets = viewModel.targets else {
            return "Played WikiQuest Link Race."
        }
        return "Finished WikiQuest Link Race: \(targets.start) -> \(targets.target) in \(viewModel.clickCount) clicks and \(viewModel.elapsedSeconds(now: now))s."
    }

    private var pathTail: [String] {
        Array(viewModel.path.suffix(4))
    }

    private func syncLinkRaceActivity() async {
        guard
            let current = viewModel.current?.article.title,
            let target = viewModel.targets?.target,
            let startedAt = viewModel.startedAt,
            !viewModel.completed
        else { return }
        await liveActivities.updateLinkRace(
            current: current,
            target: target,
            clicks: viewModel.clickCount,
            startedAt: startedAt,
            pathTail: pathTail
        )
    }
}

private struct RacePhotoStage: View {
    let current: WikiArticle
    let target: WikiArticle?
    let fallbackTargetTitle: String?
    let clicks: Int
    let elapsed: Int
    let xp: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .topTrailing) {
                ArticleHeroImage(media: current.media, title: current.title, height: 292, tint: WikiTheme.blue)

                VStack(alignment: .trailing, spacing: 7) {
                    GameHUDPill(label: "Clicks", value: "\(clicks)", systemImage: "cursorarrow.click", tint: WikiTheme.blue)
                    GameHUDPill(label: "Time", value: "\(elapsed)s", systemImage: "timer", tint: WikiTheme.violet)
                }
                .padding(14)

                VStack(alignment: .leading, spacing: 7) {
                    Spacer(minLength: 44)
                    Text(current.title)
                        .font(.system(.title, design: .serif).weight(.black))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.70)
                    Text(current.description ?? "Choose the next blue link.")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.84))
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
            }

            RaceObjectiveStrip(target: target, fallbackTargetTitle: fallbackTargetTitle, xp: xp)
            MediaCreditRow(media: current.media)
        }
    }
}

private struct RaceObjectiveStrip: View {
    let target: WikiArticle?
    let fallbackTargetTitle: String?
    let xp: Int

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            ArticleHeroImage(media: target?.media, title: targetTitle, height: 68, tint: WikiTheme.amber)
                .frame(width: 88)
            VStack(alignment: .leading, spacing: 3) {
                Kicker(text: "Target")
                Text(targetTitle)
                    .font(.callout.weight(.black))
                    .foregroundStyle(WikiTheme.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.78)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 3) {
                Kicker(text: "XP")
                TickerNumberText(value: xp, font: .system(.headline, design: .monospaced).weight(.black))
                    .foregroundStyle(WikiTheme.green)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 86, alignment: .leading)
        .padding(.vertical, 8)
        .overlay(alignment: .top) {
            Rectangle().fill(WikiTheme.hairline).frame(height: 1)
        }
        .overlay(alignment: .bottom) {
            Rectangle().fill(WikiTheme.hairline).frame(height: 1)
        }
    }

    private var targetTitle: String {
        target?.title ?? fallbackTargetTitle ?? "Target"
    }
}

private struct RaceRouteHeader: View {
    let current: WikiArticle?
    let target: WikiArticle?
    let fallbackTargetTitle: String?

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            RaceMiniArticle(label: "Current", title: current?.title ?? "Picking start", media: current?.media, tint: WikiTheme.blue)
            VStack(spacing: 7) {
                Image(systemName: "arrow.right")
                    .font(.caption.weight(.black))
                    .foregroundStyle(WikiTheme.muted)
                Rectangle()
                    .fill(WikiTheme.hairline)
                    .frame(width: 1, height: 92)
            }
            RaceMiniArticle(label: "Target", title: target?.title ?? fallbackTargetTitle ?? "Target", media: target?.media, tint: WikiTheme.amber)
        }
    }
}

private struct RaceMiniArticle: View {
    let label: String
    let title: String
    let media: WikiMedia?
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            ArticleHeroImage(media: media, title: title, height: 124, tint: tint)
            Kicker(text: label)
            Text(title)
                .font(.caption.weight(.black))
                .foregroundStyle(WikiTheme.ink)
                .lineLimit(2)
                .minimumScaleFactor(0.76)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct LinkChoiceList: View {
    let links: [WikiLink]
    let visitedTitles: Set<String>
    let loadingTitle: String?
    let mediaFor: (WikiLink) -> WikiMedia?
    let choose: (WikiLink) -> Void

    var body: some View {
        FlatSection(title: "Choose the next blue link") {
            ForEach(links) { link in
                let visited = visitedTitles.contains(link.title)
                Button {
                    choose(link)
                } label: {
                    LinkChoiceRow(
                        title: link.label,
                        media: mediaFor(link),
                        visited: visited,
                        loading: loadingTitle == link.title
                    )
                }
                .buttonStyle(ArcadePressStyle())
                .disabled(loadingTitle != nil || visited)
            }
        }
    }
}

private struct LinkChoiceRow: View {
    let title: String
    let media: WikiMedia?
    let visited: Bool
    let loading: Bool

    var body: some View {
        HStack(spacing: 12) {
            ArticleHeroImage(media: media, title: title, height: 48, tint: visited ? WikiTheme.muted : WikiTheme.blue)
                .frame(width: 58)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(visited ? WikiTheme.subtle : WikiTheme.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)
                if visited || loading {
                    Text(loading ? "Loading" : "Already visited")
                        .font(.caption.weight(.bold).monospaced())
                        .foregroundStyle(WikiTheme.muted)
                }
            }
            Spacer(minLength: 8)
            Image(systemName: visited ? "checkmark" : "chevron.right")
                .font(.callout.weight(.bold))
                .foregroundStyle(visited ? WikiTheme.muted : WikiTheme.blue)
        }
        .frame(maxWidth: .infinity, minHeight: 66, alignment: .leading)
        .padding(.vertical, 7)
        .overlay(alignment: .bottom) {
            Rectangle().fill(WikiTheme.hairline).frame(height: 1)
        }
        .opacity(visited ? 0.62 : 1)
    }
}
