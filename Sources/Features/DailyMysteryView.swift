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
        WikiScreen(navigationTitle: "Mystery", showsWindowHeader: false) {
            MysteryPhotoStage(viewModel: viewModel, detail: photoDetail)
                .accessibilityIdentifier("MysteryPhotoStage")

            MysteryCommandDeck(
                viewModel: viewModel,
                isSignedIn: session.isSignedIn,
                error: viewModel.error,
                shareText: mysteryShareText
            )
            .accessibilityIdentifier("MysteryCommandDeck")

            MysteryClueStack(
                hints: viewModel.currentHints,
                totalHints: viewModel.totalHints,
                guesses: viewModel.guessHistory
            )
            .accessibilityIdentifier("MysteryClueStack")
        }
        .task(id: session.isSignedIn) { await viewModel.load(signedIn: session.isSignedIn) }
        .onChange(of: viewModel.mode) { _, _ in
            Task { await viewModel.load(signedIn: session.isSignedIn) }
        }
        .onChange(of: viewModel.isComplete) { _, complete in
            if complete {
                if viewModel.isCorrect {
                    Haptics.success()
                } else {
                    Haptics.error()
                }
                guard viewModel.mode == .daily else { return }
                let score = viewModel.score
                let solved = viewModel.isCorrect
                Task { @MainActor in
                    let profile = try? await api.userProfile()
                    gameCenter.reportDailyMystery(
                        score: score,
                        solved: solved,
                        streak: profile?.currentStreak ?? 0
                    )
                    if let xp = profile?.xp {
                        gameCenter.reportWeeklyXP(xp)
                    }
                }
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

private struct MysteryCommandDeck: View {
    @ObservedObject var viewModel: DailyMysteryViewModel
    let isSignedIn: Bool
    let error: String?
    let shareText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            MysteryModeSwitch(selection: $viewModel.mode)
                .accessibilityIdentifier("MysteryModeSwitch")

            if let error {
                RecoveryNotice(
                    title: "ERROR",
                    detail: error,
                    actionTitle: "Retry puzzle",
                    tint: WikiTheme.red
                ) {
                    Task { await viewModel.load(signedIn: isSignedIn) }
                }
                .accessibilityIdentifier("MysteryRecoveryNotice")
            }

            if viewModel.isLoading {
                WikiLoadingGlyph(title: "LOADING", detail: "Pulling the current puzzle.", tint: WikiTheme.blue)
            }

            if viewModel.isComplete {
                ResultPanel(
                    isCorrect: viewModel.isCorrect,
                    score: viewModel.score,
                    answer: viewModel.answerTitle,
                    shareText: shareText
                )
            } else {
                CommandField(placeholder: "Type an article title", text: $viewModel.guess) {
                    Task { await viewModel.submitGuess(signedIn: isSignedIn) }
                }
                .accessibilityIdentifier("MysteryGuessField")
                .onChange(of: viewModel.guess) { _, _ in
                    Task { await viewModel.refreshSuggestions() }
                }

                HStack(spacing: 10) {
                    CommandButton(
                        title: "Reveal hint",
                        icon: "eye",
                        tint: WikiTheme.amber,
                        isDisabled: viewModel.isSubmitting
                    ) {
                        Task { await viewModel.revealHint(signedIn: isSignedIn) }
                    }
                    .accessibilityIdentifier("MysteryRevealHintButton")
                    MysteryRefreshButton(
                        isDisabled: viewModel.isLoading
                    ) {
                        Task { await viewModel.load(signedIn: isSignedIn) }
                    }
                }

                if !viewModel.suggestions.isEmpty {
                    SuggestionRail(suggestions: viewModel.suggestions) { suggestion in
                        Task { await viewModel.submitGuess(signedIn: isSignedIn, forcedGuess: suggestion) }
                    }
                    .accessibilityIdentifier("MysterySuggestionRail")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 2)
        .overlay(alignment: .top) {
            Rectangle().fill(WikiTheme.amber.opacity(0.72)).frame(height: 2)
        }
        .motionTick(trigger: "\(viewModel.mode.id)-\(viewModel.score)-\(viewModel.currentHints.count)-\(viewModel.isComplete)", tint: WikiTheme.amber)
    }
}

private struct MysteryRefreshButton: View {
    let isDisabled: Bool
    let action: () -> Void
    @State private var tapToken = 0

    var body: some View {
        Button {
            Haptics.light()
            tapToken &+= 1
            action()
        } label: {
            Image(systemName: "arrow.clockwise")
                .font(.callout.weight(.black))
                .foregroundStyle(WikiTheme.ink)
                .frame(width: 46, height: 46)
                .overlay {
                    RoundedRectangle(cornerRadius: WikiTheme.radius, style: .continuous)
                        .stroke(WikiTheme.rule.opacity(0.82), lineWidth: 1)
                }
        }
        .buttonStyle(ArcadePressStyle())
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.52 : 1)
        .accessibilityLabel("Refresh puzzle")
        .accessibilityIdentifier("MysteryRefreshButton")
        .motionTick(trigger: tapToken, tint: WikiTheme.ink, enabled: !isDisabled)
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
                    tint: WikiTheme.amber,
                    fallbackStyle: .mystery
                )

                GameHUDCluster(items: [
                    GameHUDItem(label: "Hints", value: "\(viewModel.hintsRevealed)/\(viewModel.totalHints)", systemImage: "eye", tint: WikiTheme.amber),
                    GameHUDItem(label: "Score", value: "\(viewModel.score)", systemImage: "star.fill", tint: WikiTheme.green),
                    GameHUDItem(label: "Time", value: WikiDisplayFormat.time(milliseconds: viewModel.timeMs), systemImage: "timer", tint: WikiTheme.violet, flashesOnChange: false)
                ])
                .padding(14)

                if viewModel.isComplete {
                    MysteryStageStamp(isCorrect: viewModel.isCorrect, score: viewModel.score)
                        .padding(14)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                        .transition(.scale(scale: 0.92).combined(with: .opacity))
                }
            }

            MysteryStageRail(
                modeTitle: viewModel.mode == .daily ? "Daily" : "Practice",
                puzzleTitle: viewModel.title,
                hints: viewModel.currentHints,
                hintsRevealed: viewModel.hintsRevealed,
                totalHints: viewModel.totalHints,
                guessesRemaining: viewModel.guessesRemaining,
                isComplete: viewModel.isComplete,
                isCorrect: viewModel.isCorrect
            )

            MediaCreditRow(media: viewModel.isComplete ? viewModel.mysteryMedia : viewModel.clueMedia)
        }
    }
}

private struct MysteryStageStamp: View {
    let isCorrect: Bool
    let score: Int

    var body: some View {
        HStack(spacing: 8) {
            ResultStamp(
                systemImage: isCorrect ? "checkmark.seal.fill" : "xmark.octagon.fill",
                tint: tint,
                value: score
            )
            Text(isCorrect ? "SOLVED" : "REVEALED")
                .font(.caption.weight(.black).monospaced())
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.black.opacity(0.58))
        .clipShape(RoundedRectangle(cornerRadius: WikiTheme.radius, style: .continuous))
        .resultPop(trigger: "\(isCorrect)-\(score)", tint: tint)
    }

    private var tint: Color {
        isCorrect ? WikiTheme.green : WikiTheme.red
    }
}

private struct MysteryStageRail: View {
    let modeTitle: String
    let puzzleTitle: String
    let hints: [WikiHint]
    let hintsRevealed: Int
    let totalHints: Int
    let guessesRemaining: Int
    let isComplete: Bool
    let isCorrect: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .center, spacing: 10) {
                Kicker(text: modeTitle)
                Text(puzzleTitle)
                    .font(.caption.weight(.black).monospaced())
                    .foregroundStyle(WikiTheme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.74)
                Spacer(minLength: 8)
                Text(statusText)
                    .font(.caption.weight(.black).monospaced())
                    .foregroundStyle(statusTint)
                    .lineLimit(1)
            }

            HStack(spacing: 7) {
                ForEach(clueSlots) { slot in
                    MysteryCluePip(
                        slot: slot,
                        isComplete: isComplete,
                        tint: statusTint
                    )
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(hintsRevealed) of \(totalHints) clues revealed")
        }
        .padding(.vertical, 10)
        .overlay(alignment: .top) {
            Rectangle().fill(WikiTheme.hairline).frame(height: 1)
        }
        .overlay(alignment: .bottom) {
            Rectangle().fill(WikiTheme.hairline).frame(height: 1)
        }
        .motionTick(trigger: "\(hintsRevealed)-\(guessesRemaining)-\(isComplete)", tint: statusTint)
    }

    private var pipCount: Int {
        max(totalHints, 1)
    }

    private var clueSlots: [MysteryClueSlot] {
        let openedHints = hints
            .sorted { $0.index < $1.index }
            .map { MysteryClueSlot(index: $0.index, type: $0.type, isOpen: true) }
        let openIndices = Set(openedHints.map(\.index))
        let lockedSlots = (1...pipCount)
            .filter { !openIndices.contains($0) }
            .map { MysteryClueSlot(index: $0, type: nil, isOpen: false) }
        return (openedHints + lockedSlots).sorted { $0.index < $1.index }
    }

    private var statusText: String {
        if isComplete {
            return isCorrect ? "solved" : "revealed"
        }
        return "\(guessesRemaining) guesses"
    }

    private var statusTint: Color {
        if isComplete {
            return isCorrect ? WikiTheme.green : WikiTheme.red
        }
        return WikiTheme.amber
    }
}

private struct MysteryClueSlot: Identifiable, Equatable {
    let index: Int
    let type: String?
    let isOpen: Bool

    var id: Int { index }

    var systemImage: String {
        guard let type else { return "lock.fill" }
        switch type.lowercased() {
        case "thumbnail":
            return "camera.aperture"
        case "categories":
            return "tag.fill"
        case "fingerprint":
            return "waveform.path.ecg"
        case "description":
            return "text.alignleft"
        case "redacted":
            return "eye.slash.fill"
        default:
            return "questionmark"
        }
    }

    var accessibilityLabel: String {
        guard isOpen else { return "Clue \(index) locked" }
        let name: String
        switch type?.lowercased() {
        case "thumbnail":
            name = "photo clue"
        case "categories":
            name = "category trail"
        case "fingerprint":
            name = "article shape"
        case "description":
            name = "description"
        case "redacted":
            name = "redacted clue"
        default:
            name = "clue"
        }
        return "Clue \(index), \(name), open"
    }
}

private struct MysteryCluePip: View {
    let slot: MysteryClueSlot
    let isComplete: Bool
    let tint: Color
    @EnvironmentObject private var motion: MotionSettings

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(slot.isOpen ? tint : WikiTheme.surfaceStrong.opacity(0.88))
            Image(systemName: slot.systemImage)
                .font(.caption2.weight(.black))
                .foregroundStyle(slot.isOpen ? Color.white : WikiTheme.subtle)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 24)
        .overlay {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .stroke(slot.isOpen ? tint.opacity(0.0) : WikiTheme.hairline, lineWidth: 1)
        }
        .overlay(alignment: .bottomTrailing) {
            Text("\(slot.index)")
                .font(.system(size: 7, weight: .black, design: .monospaced))
                .foregroundStyle(slot.isOpen ? Color.white.opacity(0.78) : WikiTheme.subtle.opacity(0.72))
                .padding(3)
        }
        .scaleEffect(slot.isOpen && !isComplete && !motion.reduceMotion ? 1.02 : 1)
        .animation(WikiMotion.active(WikiMotion.tick, reduceMotion: motion.reduceMotion), value: slot.isOpen)
        .accessibilityLabel(slot.accessibilityLabel)
    }
}

private struct MysteryClueStack: View {
    let hints: [WikiHint]
    let totalHints: Int
    let guesses: [GuessRecord]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Kicker(text: "Clue timeline")
                Spacer(minLength: 8)
                Text("\(hints.count)/\(totalHints) open")
                    .font(.caption2.weight(.black).monospaced())
                    .foregroundStyle(WikiTheme.amber)
            }

            if hints.isEmpty {
                EmptyMysteryState()
            } else {
                ForEach(Array(hints.enumerated()), id: \.element.id) { index, hint in
                    PanelReveal(delay: Double(index) * 0.035) {
                        HintRow(hint: hint, position: index + 1, total: totalHints)
                    }
                }
            }

            GuessHistory(guesses: guesses)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .top) {
            Rectangle().fill(WikiTheme.hairline).frame(height: 1)
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
    let position: Int
    let total: Int

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 6) {
                ZStack {
                    Circle().fill(accent)
                    Text("\(position)")
                        .font(.caption.weight(.black).monospacedDigit())
                        .foregroundStyle(.white)
                }
                .frame(width: 30, height: 30)

                Rectangle()
                    .fill(position < total ? WikiTheme.hairline : Color.clear)
                    .frame(width: 2)
                    .frame(height: 42)
            }
            .frame(width: 32)

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Kicker(text: hintLabel)
                    Spacer(minLength: 8)
                    Text("\(position)/\(total)")
                        .font(.caption2.weight(.black).monospaced())
                        .foregroundStyle(accent)
                }

                if let media = hintMedia {
                    ArticleHeroImage(
                        media: media,
                        title: "Photo clue",
                        visualState: .clue,
                        height: 150,
                        tint: WikiTheme.amber,
                        fallbackStyle: .mystery
                    )
                    MediaCreditRow(media: media)
                } else {
                    Text(rendered)
                        .foregroundStyle(WikiTheme.ink)
                        .font(.body)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 10)
        .overlay(alignment: .bottom) {
            Rectangle().fill(WikiTheme.rule.opacity(0.6)).frame(height: 1)
        }
        .motionTick(trigger: "\(hint.id)-\(hint.type)", tint: accent)
    }

    private var hintLabel: String {
        switch hint.type.lowercased() {
        case "thumbnail":
            return "Photo clue"
        case "categories":
            return "Category trail"
        case "fingerprint":
            return "Article shape"
        case "description":
            return "Description"
        case "redacted":
            return "Redacted clue"
        default:
            return hint.type
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
            ForEach(Array(suggestions.enumerated()), id: \.element) { index, suggestion in
                PanelReveal(delay: Double(index) * 0.025) {
                    CommandRow(title: suggestion, systemImage: "arrow.up.forward", tint: WikiTheme.blue, playsHaptic: false) {
                        choose(suggestion)
                    }
                }
            }
        }
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}

private struct GuessHistory: View {
    let guesses: [GuessRecord]
    @EnvironmentObject private var motion: MotionSettings

    var body: some View {
        if !guesses.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Kicker(text: "Guesses")
                ForEach(Array(guesses.enumerated()), id: \.element.id) { index, guess in
                    PanelReveal(delay: Double(index) * 0.02) {
                        HStack {
                            Text(guess.text)
                                .font(.callout.monospaced())
                            Spacer()
                            Image(systemName: guess.correct ? "checkmark.circle.fill" : "xmark.circle")
                                .foregroundStyle(guess.correct ? WikiTheme.green : WikiTheme.red)
                                .wikiBounce(enabled: !motion.reduceMotion, value: guess.correct)
                        }
                        .padding(.vertical, 5)
                        .motionTick(trigger: guess.correct, tint: guess.correct ? WikiTheme.green : WikiTheme.red)
                    }
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
                title: isCorrect ? "SOLVED" : "REVEALED",
                detail: answer ?? "Answer hidden",
                score: score,
                tint: isCorrect ? WikiTheme.green : WikiTheme.red,
                systemImage: isCorrect ? "checkmark.seal.fill" : "xmark.octagon.fill"
            )
            if let shareText {
                MysteryShareButton(shareText: shareText)
            }
        }
        .animation(WikiMotion.result, value: isCorrect)
    }
}

private struct MysteryShareButton: View {
    let shareText: String
    @State private var tapToken = 0

    var body: some View {
        ShareLink(item: shareText) {
            Image(systemName: "square.and.arrow.up")
                .font(.callout.weight(.black))
                .foregroundStyle(WikiTheme.blue)
                .frame(width: 46, height: 46)
                .overlay {
                    RoundedRectangle(cornerRadius: WikiTheme.radius, style: .continuous)
                        .stroke(WikiTheme.blue.opacity(0.82), lineWidth: 1)
                }
        }
        .buttonStyle(ArcadePressStyle())
        .simultaneousGesture(TapGesture().onEnded {
            Haptics.light()
            tapToken &+= 1
        })
        .accessibilityLabel("Share result")
        .accessibilityIdentifier("MysteryShareResultButton")
        .motionTick(trigger: tapToken, tint: WikiTheme.blue)
    }
}
