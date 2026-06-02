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
        WikiScreen(navigationTitle: "Link Race", showsWindowHeader: false) {
            if let error = viewModel.error {
                RecoveryNotice(
                    title: "ROUTE ERROR",
                    detail: error,
                    actionTitle: "New race",
                    tint: WikiTheme.red
                ) {
                    liveActivities.endLinkRaceIfNeeded()
                    Task { await viewModel.newRace() }
                }
                .accessibilityIdentifier("RaceRecoveryNotice")
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
                    xp: viewModel.savedXP ?? 0,
                    path: viewModel.path
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
                RaceCompletionPanel(
                    target: viewModel.targets?.target ?? "Target reached",
                    score: viewModel.savedXP ?? 0,
                    clicks: viewModel.clickCount,
                    elapsed: viewModel.elapsedSeconds(now: now),
                    shareText: linkRaceShareText
                ) {
                    Task { await viewModel.newRace() }
                }
            }

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
            Haptics.success()
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

private struct RaceCompletionPanel: View {
    let target: String
    let score: Int
    let clicks: Int
    let elapsed: Int
    let shareText: String
    let newRace: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ResultBanner(
                title: "FINISH",
                detail: target,
                score: score,
                tint: WikiTheme.green,
                systemImage: "flag.checkered"
            )

            HStack(spacing: 10) {
                RaceFinishMetric(label: "Clicks", value: "\(clicks)", tint: WikiTheme.blue)
                RaceFinishMetric(label: "Time", value: "\(elapsed)s", tint: WikiTheme.violet)
                RaceFinishMetric(label: "XP", value: "\(score)", tint: WikiTheme.green)
            }

            CommandButton(title: "New race", icon: "arrow.clockwise", tint: WikiTheme.blue, action: newRace)

            ShareLink(item: shareText) {
                Label("Share route", systemImage: "square.and.arrow.up")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(WikiTheme.blue)
            }
            .buttonStyle(ArcadePressStyle())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 2)
        .overlay(alignment: .top) {
            Rectangle().fill(WikiTheme.green.opacity(0.72)).frame(height: 2)
        }
        .accessibilityIdentifier("RaceCompletionPanel")
        .motionTick(trigger: "\(target)-\(score)-\(clicks)-\(elapsed)", tint: WikiTheme.green)
    }
}

private struct RaceFinishMetric: View {
    let label: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Kicker(text: label)
            Text(value)
                .font(.system(.headline, design: .monospaced).weight(.black))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 10)
        .overlay(alignment: .top) {
            Rectangle().fill(WikiTheme.hairline).frame(height: 1)
        }
    }
}

private struct RacePhotoStage: View {
    let current: WikiArticle
    let target: WikiArticle?
    let fallbackTargetTitle: String?
    let clicks: Int
    let elapsed: Int
    let xp: Int
    let path: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .topTrailing) {
                ArticleHeroImage(media: current.media, title: current.title, height: 292, tint: WikiTheme.blue)

                GameHUDCluster(items: [
                    GameHUDItem(label: "Clicks", value: "\(clicks)", systemImage: "cursorarrow.click", tint: WikiTheme.blue),
                    GameHUDItem(label: "Time", value: "\(elapsed)s", systemImage: "timer", tint: WikiTheme.violet, flashesOnChange: false)
                ])
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
                .accessibilityIdentifier("RaceObjectiveStrip")
            RaceTrailInline(path: path)
                .accessibilityIdentifier("RaceTrailInline")
            MediaCreditRow(media: current.media)
        }
        .accessibilityIdentifier("RacePhotoStage")
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

private struct RaceTrailInline: View {
    let path: [String]
    @EnvironmentObject private var motion: MotionSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 8) {
                Kicker(text: "Trail")
                Spacer(minLength: 8)
                Text("\(max(path.count - 1, 0)) clicks")
                    .font(.caption2.weight(.black).monospaced())
                    .foregroundStyle(WikiTheme.blue)
            }

            if path.isEmpty {
                Text("Choose a blue link to start the route.")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(WikiTheme.muted)
                    .padding(.vertical, 7)
            } else {
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 0) {
                            ForEach(Array(path.enumerated()), id: \.offset) { index, title in
                                RaceTrailNode(
                                    index: index,
                                    title: title,
                                    isLatest: index == path.count - 1
                                )
                                .id(index)
                                .accessibilityIdentifier("RaceTrailNode-\(index + 1)")
                                .transition(.opacity.combined(with: .move(edge: .trailing)))

                                if index < path.count - 1 {
                                    RaceTrailConnector(isFresh: index == path.count - 2)
                                        .frame(width: 24)
                                        .transition(.opacity.combined(with: .move(edge: .trailing)))
                                }
                            }
                        }
                        .padding(.vertical, 5)
                        .revealSweep(trigger: path.count, tint: WikiTheme.blue, enabled: path.count > 1)
                    }
                    .onAppear {
                        scrollToLatest(with: proxy)
                    }
                    .onChange(of: path.count) { _, _ in
                        scrollToLatest(with: proxy)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .top) {
            Rectangle().fill(WikiTheme.hairline).frame(height: 1)
        }
        .motionTick(trigger: path.count, tint: WikiTheme.blue, enabled: !path.isEmpty)
        .animation(WikiMotion.active(WikiMotion.panel, reduceMotion: motion.reduceMotion), value: path.count)
    }

    private func scrollToLatest(with proxy: ScrollViewProxy) {
        guard let latest = path.indices.last else { return }
        if motion.reduceMotion {
            proxy.scrollTo(latest, anchor: .trailing)
        } else {
            withAnimation(WikiMotion.panel) {
                proxy.scrollTo(latest, anchor: .trailing)
            }
        }
    }
}

private struct RaceTrailNode: View {
    let index: Int
    let title: String
    let isLatest: Bool
    @EnvironmentObject private var motion: MotionSettings

    var body: some View {
        HStack(spacing: 7) {
            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(isLatest ? WikiTheme.blue : WikiTheme.surface)
                    .overlay {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .stroke(isLatest ? WikiTheme.blue : WikiTheme.hairline, lineWidth: 1)
                    }

                if isLatest {
                    Image(systemName: "location.fill")
                        .font(.caption2.weight(.black))
                        .foregroundStyle(.white)
                        .wikiBounce(enabled: !motion.reduceMotion, value: title)
                } else {
                    Text(String(format: "%02d", index + 1))
                        .font(.caption2.weight(.black).monospacedDigit())
                        .foregroundStyle(WikiTheme.blue)
                }
            }
            .frame(width: 31, height: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(isLatest ? "Current" : "Visited")
                    .font(.caption2.weight(.black).monospaced())
                    .foregroundStyle(isLatest ? WikiTheme.blue : WikiTheme.muted)
                Text(title)
                    .font(.caption.weight(.bold).monospaced())
                    .foregroundStyle(isLatest ? WikiTheme.ink : WikiTheme.blue)
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)
            }
        }
        .frame(width: 164, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(isLatest ? WikiTheme.blue.opacity(0.08) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: WikiTheme.controlRadius, style: .continuous))
        .scaleEffect(isLatest && !motion.reduceMotion ? 1.015 : 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(isLatest ? "Current" : "Visited") article \(index + 1), \(title)")
    }
}

private struct RaceTrailConnector: View {
    let isFresh: Bool

    var body: some View {
        ZStack {
            Rectangle()
                .fill(WikiTheme.hairline)
                .frame(height: 1)
            Rectangle()
                .fill(WikiTheme.blue.opacity(isFresh ? 0.58 : 0.30))
                .frame(height: isFresh ? 2 : 1)
                .padding(.horizontal, 4)
        }
        .motionTick(trigger: isFresh, tint: WikiTheme.blue, enabled: isFresh)
    }
}

private struct LinkChoiceList: View {
    let links: [WikiLink]
    let visitedTitles: Set<String>
    let loadingTitle: String?
    let mediaFor: (WikiLink) -> WikiMedia?
    let choose: (WikiLink) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Kicker(text: routeLocked ? "Route locked" : "Choose next link")
                Spacer(minLength: 8)
                Text(routeLocked ? "Opening" : "\(links.count) exits")
                    .font(.caption2.weight(.black).monospaced())
                    .foregroundStyle(WikiTheme.blue)
            }

            if let loadingTitle {
                RouteLockStrip(title: loadingTitle)
            }

            ForEach(Array(links.enumerated()), id: \.element.id) { index, link in
                let visited = visitedTitles.contains(link.title)
                let state: LinkChoiceState = loadingTitle == link.title ? .loading : (visited ? .visited : .available)
                PanelReveal(delay: Double(index) * 0.018) {
                    Button {
                        Haptics.light()
                        choose(link)
                    } label: {
                        LinkChoiceRow(
                            index: index + 1,
                            title: link.label,
                            media: mediaFor(link),
                            state: state
                        )
                    }
                    .buttonStyle(ArcadePressStyle())
                    .accessibilityIdentifier("RaceLinkChoice-\(index + 1)")
                    .disabled(loadingTitle != nil || visited)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 2)
        .overlay(alignment: .top) {
            Rectangle().fill(WikiTheme.blue.opacity(0.72)).frame(height: 2)
        }
        .accessibilityIdentifier("RaceLinkChoiceList")
        .motionTick(trigger: "\(links.count)-\(loadingTitle ?? "ready")", tint: WikiTheme.blue)
    }

    private var routeLocked: Bool {
        loadingTitle != nil
    }
}

private enum LinkChoiceState: Equatable {
    case available
    case loading
    case visited

    var tint: Color {
        switch self {
        case .available, .loading:
            return WikiTheme.blue
        case .visited:
            return WikiTheme.muted
        }
    }

    var statusText: String? {
        switch self {
        case .available:
            return nil
        case .loading:
            return "Opening route"
        case .visited:
            return "Already visited"
        }
    }

    var motionKey: String {
        switch self {
        case .available:
            return "available"
        case .loading:
            return "loading"
        case .visited:
            return "visited"
        }
    }

    var actionText: String {
        switch self {
        case .available:
            return "GO"
        case .loading:
            return "OPEN"
        case .visited:
            return "SEEN"
        }
    }
}

private struct LinkChoiceRow: View {
    let index: Int
    let title: String
    let media: WikiMedia?
    let state: LinkChoiceState
    @EnvironmentObject private var motion: MotionSettings

    var body: some View {
        HStack(spacing: 9) {
            RaceChoiceMarker(index: index, state: state)
            RaceChoiceConnector(state: state)
                .frame(width: 14)

            ArticleHeroImage(media: media, title: title, height: 48, tint: state == .visited ? WikiTheme.muted : WikiTheme.blue)
                .frame(width: 52)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(state == .visited ? WikiTheme.subtle : WikiTheme.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)
                if let statusText = state.statusText {
                    Text(statusText)
                        .font(.caption.weight(.bold).monospaced())
                        .foregroundStyle(WikiTheme.muted)
                }
            }
            .layoutPriority(1)
            Spacer(minLength: 8)
            RaceChoiceActionBadge(state: state)
        }
        .frame(maxWidth: .infinity, minHeight: 66, alignment: .leading)
        .padding(.vertical, 7)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(state == .loading ? WikiTheme.blue : .clear)
                .frame(width: 2)
        }
        .overlay(alignment: .bottom) {
            Rectangle().fill(WikiTheme.hairline).frame(height: 1)
        }
        .opacity(state == .visited ? 0.62 : 1)
        .motionTick(trigger: state.motionKey, tint: WikiTheme.blue, enabled: state == .loading)
    }
}

private struct RaceChoiceConnector: View {
    let state: LinkChoiceState
    @EnvironmentObject private var motion: MotionSettings

    var body: some View {
        ZStack {
            Rectangle()
                .fill(WikiTheme.hairline)
                .frame(height: 1)
            Rectangle()
                .fill(state.tint.opacity(state == .available ? 0.72 : 0.38))
                .frame(height: state == .loading ? 2 : 1)
                .padding(.horizontal, 2)
            if state == .loading {
                Circle()
                    .fill(WikiTheme.blue)
                    .frame(width: 5, height: 5)
                    .offset(x: motion.reduceMotion ? 0 : 7)
                    .wikiBounce(enabled: !motion.reduceMotion, value: state.motionKey)
            }
        }
    }
}

private struct RaceChoiceActionBadge: View {
    let state: LinkChoiceState
    @EnvironmentObject private var motion: MotionSettings

    var body: some View {
        HStack(spacing: 5) {
            Text(state.actionText)
                .font(.caption2.weight(.black).monospaced())
            Image(systemName: systemImage)
                .font(.caption.weight(.black))
                .rotationEffect(.degrees(state == .loading && !motion.reduceMotion ? 18 : 0))
                .wikiBounce(enabled: state == .loading && !motion.reduceMotion, value: state.motionKey)
        }
        .foregroundStyle(foreground)
        .padding(.horizontal, 7)
        .padding(.vertical, 5)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: WikiTheme.radius, style: .continuous))
        .accessibilityHidden(true)
    }

    private var systemImage: String {
        switch state {
        case .available:
            return "arrow.right"
        case .loading:
            return "arrow.triangle.2.circlepath"
        case .visited:
            return "checkmark"
        }
    }

    private var foreground: Color {
        switch state {
        case .available, .loading:
            return .white
        case .visited:
            return WikiTheme.muted
        }
    }

    private var background: Color {
        switch state {
        case .available:
            return WikiTheme.blue
        case .loading:
            return WikiTheme.blue.opacity(0.82)
        case .visited:
            return WikiTheme.surface
        }
    }
}

private struct RouteLockStrip: View {
    let title: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "link")
                .font(.caption.weight(.black))
            Text(title)
                .font(.caption.weight(.bold).monospaced())
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            Spacer(minLength: 8)
            Text("ROUTE")
                .font(.caption2.weight(.black).monospaced())
        }
        .foregroundStyle(WikiTheme.blue)
        .padding(.vertical, 8)
        .overlay(alignment: .top) {
            Rectangle().fill(WikiTheme.blue.opacity(0.28)).frame(height: 1)
        }
        .overlay(alignment: .bottom) {
            Rectangle().fill(WikiTheme.blue.opacity(0.28)).frame(height: 1)
        }
        .motionTick(trigger: title, tint: WikiTheme.blue)
    }
}

private struct RaceChoiceMarker: View {
    let index: Int
    let state: LinkChoiceState
    @EnvironmentObject private var motion: MotionSettings

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(fill)
                .overlay {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .stroke(state.tint.opacity(state == .available ? 0.42 : 0.70), lineWidth: 1)
                }

            markerContent
        }
        .frame(width: 38, height: 48)
        .motionTick(trigger: "\(index)-\(state.motionKey)", tint: state.tint, enabled: state == .loading)
    }

    @ViewBuilder
    private var markerContent: some View {
        switch state {
        case .available:
            Text(String(format: "%02d", index))
                .font(.caption.weight(.black).monospacedDigit())
                .foregroundStyle(WikiTheme.blue)
        case .loading:
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.caption.weight(.black))
                .foregroundStyle(.white)
                .rotationEffect(.degrees(motion.reduceMotion ? 0 : 18))
                .wikiBounce(enabled: !motion.reduceMotion, value: state.motionKey)
        case .visited:
            Image(systemName: "checkmark")
                .font(.caption.weight(.black))
                .foregroundStyle(WikiTheme.muted)
        }
    }

    private var fill: Color {
        switch state {
        case .available:
            return WikiTheme.blue.opacity(0.07)
        case .loading:
            return WikiTheme.blue
        case .visited:
            return WikiTheme.surface
        }
    }
}
