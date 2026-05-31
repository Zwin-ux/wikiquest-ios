import SwiftUI

struct DailyMysteryView: View {
    let api: WikiQuestAPIClient
    @EnvironmentObject private var session: SessionStore
    @EnvironmentObject private var gameCenter: GameCenterStore
    @StateObject private var viewModel: DailyMysteryViewModel

    init(api: WikiQuestAPIClient) {
        self.api = api
        _viewModel = StateObject(wrappedValue: DailyMysteryViewModel(api: api))
    }

    var body: some View {
        WikiScreen(navigationTitle: "Mystery") {
            MysteryPhotoStage(viewModel: viewModel, detail: photoDetail)

            MysteryModeSwitch(selection: $viewModel.mode)

            if let error = viewModel.error {
                InlineNotice(title: "ERROR", detail: error, tint: WikiTheme.red)
            }

            if viewModel.isLoading {
                WikiLoadingGlyph(title: "LOADING", detail: "Pulling the current puzzle.", tint: WikiTheme.blue)
            }

            FlatSection(title: "Hints") {
                if viewModel.currentHints.isEmpty {
                    EmptyMysteryState()
                } else {
                    ForEach(Array(viewModel.currentHints.enumerated()), id: \.element.id) { index, hint in
                        PanelReveal(delay: Double(index) * 0.035) {
                            HintRow(hint: hint)
                        }
                    }
                }
            }

            GuessHistory(guesses: viewModel.guessHistory)

            if !viewModel.isComplete {
                CommandField(placeholder: "Type an article title", text: $viewModel.guess) {
                    Task { await viewModel.submitGuess(signedIn: session.isSignedIn) }
                }
                .onChange(of: viewModel.guess) { _, _ in
                    Task { await viewModel.refreshSuggestions() }
                }

                if !viewModel.suggestions.isEmpty {
                    SuggestionRail(suggestions: viewModel.suggestions) { suggestion in
                        Task { await viewModel.submitGuess(signedIn: session.isSignedIn, forcedGuess: suggestion) }
                    }
                }

                HStack(spacing: 10) {
                    CommandButton(
                        title: "Reveal hint",
                        icon: "eye",
                        tint: WikiTheme.amber,
                        isDisabled: viewModel.isSubmitting,
                        playsHaptic: false
                    ) {
                        Task { await viewModel.revealHint(signedIn: session.isSignedIn) }
                    }
                    CommandButton(
                        title: "Refresh",
                        icon: "arrow.clockwise",
                        tint: WikiTheme.ink,
                        isDisabled: viewModel.isLoading
                    ) {
                        Task { await viewModel.load(signedIn: session.isSignedIn) }
                    }
                }
            } else {
                ResultPanel(
                    isCorrect: viewModel.isCorrect,
                    score: viewModel.score,
                    answer: viewModel.answerTitle,
                    shareText: mysteryShareText
                )
            }
        }
        .task(id: session.isSignedIn) { await viewModel.load(signedIn: session.isSignedIn) }
        .onChange(of: viewModel.mode) { _, _ in
            Task { await viewModel.load(signedIn: session.isSignedIn) }
        }
        .onChange(of: viewModel.isComplete) { _, complete in
            if complete {
                gameCenter.reportDailyMystery(
                    score: viewModel.score,
                    solved: viewModel.isCorrect,
                    streak: 0
                )
            }
        }
        .refreshable { await viewModel.load(signedIn: session.isSignedIn) }
    }

    private var mysteryShareText: String {
        if viewModel.isCorrect {
            return "Solved WikiQuest \(viewModel.title): \(viewModel.answerTitle ?? "the article") for \(viewModel.score) XP."
        }
        return "Played WikiQuest \(viewModel.title). The answer was \(viewModel.answerTitle ?? "hidden")."
    }

    private var photoDetail: String {
        if viewModel.isComplete {
            return viewModel.isCorrect ? "Solved and revealed." : "The answer is revealed."
        }
        if viewModel.clueMedia != nil {
            return "The image is partly open. Use it carefully."
        }
        return "Reveal clues until the image unlocks."
    }
}

private struct MysteryPhotoStage: View {
    @ObservedObject var viewModel: DailyMysteryViewModel
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .topTrailing) {
                PhotoClueCard(
                    kicker: viewModel.mode == .daily ? "Daily Mystery" : "Practice Mystery",
                    title: viewModel.photoTitle,
                    detail: detail,
                    media: viewModel.mysteryMedia,
                    visualState: viewModel.photoVisualState,
                    tint: WikiTheme.amber
                )

                VStack(alignment: .trailing, spacing: 7) {
                    GameHUDPill(label: "Hints", value: "\(viewModel.hintsRevealed)/\(viewModel.totalHints)", systemImage: "eye", tint: WikiTheme.amber)
                    GameHUDPill(label: "Score", value: "\(viewModel.score)", systemImage: "star.fill", tint: WikiTheme.green)
                    GameHUDPill(label: "Time", value: WikiDisplayFormat.time(milliseconds: viewModel.timeMs), systemImage: "timer", tint: WikiTheme.violet)
                }
                .padding(14)
            }

            HStack(alignment: .center, spacing: 10) {
                Kicker(text: viewModel.mode == .daily ? "Daily" : "Practice")
                Text(viewModel.title)
                    .font(.caption.weight(.black).monospaced())
                    .foregroundStyle(WikiTheme.ink)
                Spacer(minLength: 8)
                Text("\(viewModel.guessesRemaining) guesses")
                    .font(.caption.weight(.black).monospaced())
                    .foregroundStyle(WikiTheme.violet)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle().fill(WikiTheme.rule.opacity(0.38)).frame(height: 3)
                    Rectangle()
                        .fill(WikiTheme.amber)
                        .frame(width: geo.size.width * viewModel.progress, height: 3)
                        .animation(WikiMotion.ticker, value: viewModel.progress)
                }
            }
            .frame(height: 3)

            MediaCreditRow(media: viewModel.isComplete ? viewModel.mysteryMedia : viewModel.clueMedia)
        }
    }
}

private struct MysteryModeSwitch: View {
    @Binding var selection: MysteryMode

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(MysteryMode.allCases.enumerated()), id: \.element.id) { index, mode in
                Button {
                    Haptics.light()
                    withAnimation(WikiMotion.quick) {
                        selection = mode
                    }
                } label: {
                    Text(mode.rawValue)
                        .font(.caption.weight(.bold).monospaced())
                        .frame(maxWidth: .infinity)
                        .frame(height: 38)
                        .foregroundStyle(selection == mode ? WikiTheme.surfaceStrong : WikiTheme.ink)
                        .background(selection == mode ? activeTint(for: mode) : Color.clear)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if index < MysteryMode.allCases.count - 1 {
                    Rectangle()
                        .fill(WikiTheme.hairline)
                        .frame(width: 1, height: 22)
                }
            }
        }
        .background(WikiTheme.surfaceStrong)
        .overlay {
            RoundedRectangle(cornerRadius: WikiTheme.controlRadius, style: .continuous)
                .stroke(WikiTheme.rule.opacity(0.72), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: WikiTheme.controlRadius, style: .continuous))
        .accessibilityElement(children: .contain)
    }

    private func activeTint(for mode: MysteryMode) -> Color {
        mode == .daily ? WikiTheme.ink : WikiTheme.amber
    }
}

private struct HintRow: View {
    let hint: WikiHint

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Kicker(text: "Hint \(hint.index) / \(hint.type)")
            if let media = hintMedia {
                ArticleHeroImage(media: media, title: "Photo clue", visualState: .clue, height: 150, tint: WikiTheme.amber)
                MediaCreditRow(media: media)
            } else {
                Text(rendered)
                    .foregroundStyle(WikiTheme.ink)
                    .font(.body)
                    .lineSpacing(3)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 12)
        .overlay(alignment: .leading) {
            Rectangle().fill(accent).frame(width: 3)
        }
        .overlay(alignment: .bottom) {
            Rectangle().fill(WikiTheme.rule.opacity(0.6)).frame(height: 1)
        }
    }

    private var accent: Color {
        switch hint.type.lowercased() {
        case "categories":
            return WikiTheme.blue
        case "fingerprint":
            return WikiTheme.violet
        case "description":
            return WikiTheme.green
        case "redacted":
            return WikiTheme.red
        case "thumbnail":
            return WikiTheme.amber
        default:
            return WikiTheme.ink
        }
    }

    private var hintMedia: WikiMedia? {
        guard hint.type.lowercased() == "thumbnail" else { return nil }
        guard case .string(let value) = hint.value else { return nil }
        return WikiMedia.from(thumbnail: value, image: value, source: nil, fallbackStyle: .mystery)
    }

    private var rendered: String {
        switch hint.value {
        case .string(let value):
            return value
        case .strings(let values):
            return values.joined(separator: " / ")
        case .fingerprint(let value):
            return "Words \(value.extractWords ?? 0), links \(value.incomingLinks ?? 0), length \(value.lengthBand ?? "unknown")"
        case .null:
            return "No public clue yet."
        }
    }
}

private struct EmptyMysteryState: View {
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            BrandMarkView(variant: .glyph, size: 34, animated: false)
            InlineNotice(title: "READY", detail: "Reveal a hint or take the first shot.", tint: WikiTheme.amber)
        }
    }
}

private struct SuggestionRail: View {
    let suggestions: [String]
    let choose: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Kicker(text: "Suggestions")
            ForEach(suggestions, id: \.self) { suggestion in
                CommandRow(title: suggestion, systemImage: "arrow.up.forward", tint: WikiTheme.blue, playsHaptic: false) {
                    choose(suggestion)
                }
            }
        }
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}

private struct GuessHistory: View {
    let guesses: [GuessRecord]

    var body: some View {
        if !guesses.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Kicker(text: "Guesses")
                ForEach(guesses) { guess in
                    HStack {
                        Text(guess.text)
                            .font(.callout.monospaced())
                        Spacer()
                        Image(systemName: guess.correct ? "checkmark.circle.fill" : "xmark.circle")
                            .foregroundStyle(guess.correct ? WikiTheme.green : WikiTheme.red)
                    }
                    .padding(.vertical, 5)
                }
            }
            .transition(.opacity)
        }
    }
}

struct ResultPanel: View {
    let isCorrect: Bool
    let score: Int
    let answer: String?
    var shareText: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ResultBanner(
                title: isCorrect ? "SOLVED" : "FAILED",
                detail: answer ?? "Answer hidden",
                score: score,
                tint: isCorrect ? WikiTheme.green : WikiTheme.red,
                systemImage: isCorrect ? "checkmark.seal.fill" : "xmark.octagon.fill"
            )
            if let shareText {
                ShareLink(item: shareText) {
                    Label("Share result", systemImage: "square.and.arrow.up")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(WikiTheme.blue)
                }
                .buttonStyle(ArcadePressStyle())
            }
        }
        .animation(WikiMotion.result, value: isCorrect)
    }
}
