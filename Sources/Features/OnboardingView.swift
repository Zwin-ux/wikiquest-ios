import AuthenticationServices
import SwiftUI

enum OnboardingGatePolicy {
    static func shouldShowOnboarding(isSignedIn: Bool) -> Bool {
        !isSignedIn
    }
}

enum OnboardingBootupPolicy {
    static let storageKey = "wikiquest.hasCompletedBootup"

    static func shouldShowBootup(isSignedIn: Bool, hasCompletedBootup: Bool) -> Bool {
        !isSignedIn && !hasCompletedBootup
    }

    static var shouldResetForUITests: Bool {
        ProcessInfo.processInfo.environment["WIKIQUEST_RESET_BOOTUP"] == "1"
    }

    static var shouldSkipForUITests: Bool {
        ProcessInfo.processInfo.environment["WIKIQUEST_SKIP_BOOTUP"] == "1"
    }

    static var usesFastBootup: Bool {
        ProcessInfo.processInfo.environment["WIKIQUEST_FAST_BOOTUP"] == "1"
    }
}

struct OnboardingGate: View {
    let api: WikiQuestAPIClient
    @EnvironmentObject private var session: SessionStore
    @AppStorage("wikiquest.hasCompletedBootup") private var hasCompletedBootup = false
    @State private var didApplyLaunchConfiguration = false
    @State private var previewSession = PreviewQuestSession()

    private let modes = [
        OnboardingMode(title: "Mystery", detail: "Decode photo clues", assetName: "ModeMysteryMark", tint: WikiTheme.amber),
        OnboardingMode(title: "Race", detail: "Take blue links", assetName: "ModeRaceMark", tint: WikiTheme.blue),
        OnboardingMode(title: "Map", detail: "Drop the pin", assetName: "ModeNearbyMark", tint: WikiTheme.green)
    ]

    var body: some View {
        Group {
            if OnboardingBootupPolicy.shouldShowBootup(
                isSignedIn: session.isSignedIn,
                hasCompletedBootup: hasCompletedBootup
            ) {
                BootupIntroView {
                    withAnimation(WikiMotion.page) {
                        hasCompletedBootup = true
                    }
                }
            } else {
                onboardingContent
            }
        }
        .task {
            applyLaunchConfigurationIfNeeded()
        }
    }

    private var onboardingContent: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    onboardingHeader

                    PreviewQuestPanel(session: $previewSession, quest: .firstRun)

                    OnboardingModeStrip(modes: modes)

                    OnboardingLegalLinks()
                }
                .padding(WikiTheme.screenPadding)
                .padding(.top, max(8, proxy.safeAreaInsets.top + 4))
                .padding(.bottom, max(132, proxy.safeAreaInsets.bottom + 112))
                .frame(minHeight: proxy.size.height, alignment: .topLeading)
                .accessibilityIdentifier("OnboardingContainer")
            }
            .scrollIndicators(.hidden)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                appleSignInCommandBar
            }
            .accessibilityIdentifier("OnboardingContainer")
        }
        .background(WikiPaperBackground())
    }

    private func applyLaunchConfigurationIfNeeded() {
        guard !didApplyLaunchConfiguration else { return }
        didApplyLaunchConfiguration = true
        if OnboardingBootupPolicy.shouldResetForUITests {
            hasCompletedBootup = false
        }
        if OnboardingBootupPolicy.shouldSkipForUITests {
            hasCompletedBootup = true
        }
    }

    private var onboardingHeader: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(alignment: .center, spacing: 12) {
                OnboardingLogoMark(size: 58)
                VStack(alignment: .leading, spacing: 4) {
                    Text("WikiQuest")
                        .font(.system(size: 38, weight: .black, design: .serif))
                        .foregroundStyle(WikiTheme.ink)
                        .minimumScaleFactor(0.70)
                        .lineLimit(1)
                        .accessibilityIdentifier("OnboardingTitle")
                    Text("First round")
                        .font(.caption.weight(.black).monospaced())
                        .foregroundStyle(WikiTheme.blue)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                OnboardingBootBadge()
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("One photo. One answer. Then save the run.")
                    .font(.callout)
                    .foregroundStyle(WikiTheme.muted)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.bottom, 4)
        .overlay(alignment: .bottom) {
            Rectangle().fill(WikiTheme.rule.opacity(0.42)).frame(height: 1)
        }
    }

    private var appleSignInCommandBar: some View {
        VStack(alignment: .leading, spacing: 12) {
            SignInWithAppleButton(.signIn) { request in
                session.prepareAppleRequest(request)
            } onCompletion: { result in
                session.handleAppleCompletion(result, api: api)
            }
            .signInWithAppleButtonStyle(.black)
            .frame(height: 54)
            .clipShape(RoundedRectangle(cornerRadius: WikiTheme.controlRadius, style: .continuous))
            .disabled(session.isSigningIn)
            .opacity(session.isSigningIn ? 0.72 : 1)
            .accessibilityIdentifier("OnboardingContinueWithApple")

            OnboardingSignInStatus(
                isSigningIn: session.isSigningIn,
                error: session.lastAuthError,
                hasPlayedPreview: previewSession.hasSelection
            )
        }
        .padding(.horizontal, WikiTheme.screenPadding)
        .padding(.top, 10)
        .padding(.bottom, 10)
        .background(WikiTheme.paper.opacity(0.985))
        .overlay(alignment: .top) {
            Rectangle().fill(WikiTheme.ink.opacity(0.24)).frame(height: 1)
        }
        .accessibilityIdentifier("OnboardingAppleCommandBar")
    }
}

private struct OnboardingBootBadge: View {
    @EnvironmentObject private var motion: MotionSettings
    @State private var activeIndex = 0
    @State private var didStart = false

    var body: some View {
        VStack(alignment: .trailing, spacing: 5) {
            Text("READY")
                .font(.caption2.weight(.black).monospaced())
                .foregroundStyle(WikiTheme.subtle)
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(index == activeIndex ? WikiTheme.blue : WikiTheme.ink.opacity(0.22))
                        .frame(width: index == activeIndex && !motion.reduceMotion ? 16 : 10, height: 4)
                        .animation(WikiMotion.active(WikiMotion.tick, reduceMotion: motion.reduceMotion), value: activeIndex)
                }
            }
        }
        .task { await runTicker() }
        .accessibilityHidden(true)
    }

    @MainActor
    private func runTicker() async {
        guard !didStart else { return }
        didStart = true
        guard !motion.reduceMotion else {
            activeIndex = 0
            return
        }

        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 520_000_000)
            withAnimation(WikiMotion.tick) {
                activeIndex = (activeIndex + 1) % 3
            }
        }
    }
}

private struct OnboardingSignInStatus: View {
    let isSigningIn: Bool
    let error: String?
    let hasPlayedPreview: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Circle()
                .fill(tint)
                .frame(width: 6, height: 6)
            Text(label)
                .font(.caption.weight(.black).monospaced())
                .foregroundStyle(tint)
                .lineLimit(1)
            Text(detail)
                .font(.caption.weight(.semibold))
                .foregroundStyle(WikiTheme.subtle)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    private var label: String {
        if isSigningIn {
            return "APPLE"
        }
        if error != nil {
            return "RETRY"
        }
        return hasPlayedPreview ? "SAVE" : "READY"
    }

    private var detail: String {
        if isSigningIn {
            return "Waiting for Apple."
        }
        if let error {
            return error
        }
        if hasPlayedPreview {
            return "Keep XP, streaks, routes, and pins."
        }
        return "Play the preview first, then keep progress."
    }

    private var tint: Color {
        if error != nil {
            return WikiTheme.red
        }
        return isSigningIn ? WikiTheme.ink : WikiTheme.blue
    }
}

private struct PreviewQuestPanel: View {
    @Binding var session: PreviewQuestSession
    let quest: PreviewQuest
    @EnvironmentObject private var motion: MotionSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PhotoClueCard(
                kicker: stageKicker,
                title: title,
                detail: detail,
                media: quest.media,
                visualState: visualState,
                tint: resultTint,
                fallbackStyle: .mystery,
                stateLabel: stageStateLabel,
                stateSystemImage: stageStateIcon
            )
            .accessibilityIdentifier("PreviewPhotoStage")

            PreviewQuestHUD(session: session, quest: quest, tint: resultTint)

            MediaCreditRow(media: session.hasSelection ? quest.media : nil)

            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(session.visibleClues(in: quest).enumerated()), id: \.offset) { index, clue in
                    PanelReveal(delay: Double(index) * 0.035) {
                        PreviewClueRow(index: index + 1, clue: clue)
                    }
                }
            }

            if session.canRevealMore(in: quest) {
                Button {
                    Haptics.light()
                    withAnimation(WikiMotion.active(WikiMotion.panel, reduceMotion: motion.reduceMotion)) {
                        session.revealNext(in: quest)
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "eye.fill")
                            .font(.callout.weight(.black))
                            .foregroundStyle(.white)
                            .frame(width: 34, height: 34)
                            .background(WikiTheme.blue)
                            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Reveal clue")
                                .font(.callout.weight(.black))
                                .foregroundStyle(WikiTheme.ink)
                            Text("CLUE \(String(format: "%02d", session.visibleClues(in: quest).count + 1))/\(String(format: "%02d", quest.clues.count))")
                                .font(.caption2.weight(.black).monospacedDigit())
                                .foregroundStyle(WikiTheme.blue)
                        }
                        Spacer(minLength: 8)
                        Image(systemName: "chevron.down")
                            .font(.caption.weight(.black))
                            .foregroundStyle(WikiTheme.blue)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 10)
                    .overlay(alignment: .top) {
                        Rectangle().fill(WikiTheme.hairline).frame(height: 1)
                    }
                }
                .buttonStyle(ArcadePressStyle())
                .accessibilityLabel("Reveal clue")
            }

            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(quest.choices.enumerated()), id: \.element.id) { index, choice in
                    Button {
                        if choice.isCorrect {
                            Haptics.success()
                        } else {
                            Haptics.error()
                        }
                        withAnimation(WikiMotion.active(WikiMotion.result, reduceMotion: motion.reduceMotion)) {
                            session.choose(choiceID: choice.id, in: quest)
                        }
                    } label: {
                        PreviewChoiceRow(
                            index: index + 1,
                            choice: choice,
                            result: session.result(in: quest),
                            isSelected: session.selectedChoiceID == choice.id
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("PreviewChoice-\(index + 1)")
                    .disabled(session.hasSelection)
                }
            }

            if let result = session.result(in: quest) {
                PreviewResultBanner(result: result) {
                    Haptics.light()
                    withAnimation(WikiMotion.active(WikiMotion.panel, reduceMotion: motion.reduceMotion)) {
                        session = PreviewQuestSession()
                    }
                }
            }
        }
        .accessibilityIdentifier("PlayablePreviewQuest")
    }

    private var visualState: ArticleVisualState {
        session.hasSelection ? .revealed : .clue
    }

    private var stageKicker: String {
        session.hasSelection ? "ARTICLE REVEALED" : quest.kicker
    }

    private var stageStateLabel: String {
        if session.hasSelection {
            return "Revealed"
        }
        return "Clue \(session.visibleClues(in: quest).count)/\(quest.clues.count)"
    }

    private var stageStateIcon: String {
        session.hasSelection ? "checkmark.seal.fill" : "eye.fill"
    }

    private var resultTint: Color {
        switch session.result(in: quest) {
        case .correct:
            return WikiTheme.green
        case .missed:
            return WikiTheme.amber
        case nil:
            return WikiTheme.blue
        }
    }

    private var title: String {
        switch session.result(in: quest) {
        case .correct(let title):
            return title
        case .missed(_, let correctTitle):
            return correctTitle
        case nil:
            return quest.title
        }
    }

    private var detail: String {
        if session.hasSelection {
            return "Article revealed. Keep the run after sign-in."
        }
        return quest.prompt
    }
}

private struct PreviewQuestHUD: View {
    let session: PreviewQuestSession
    let quest: PreviewQuest
    let tint: Color

    var body: some View {
        GameHUDCluster(items: [
            GameHUDItem(label: "Clues", value: "\(session.visibleClues(in: quest).count)/\(quest.clues.count)", systemImage: "eye", tint: WikiTheme.blue),
            GameHUDItem(label: "Photo", value: photoText, systemImage: "photo", tint: tint),
            GameHUDItem(label: "XP", value: session.result(in: quest) == nil ? "120" : xpText, systemImage: "star.fill", tint: tint)
        ], alignment: .leading)
        .padding(.vertical, 1)
        .accessibilityIdentifier("PreviewQuestHUD")
        .motionTick(trigger: "\(session.visibleClues(in: quest).count)-\(session.selectedChoiceID ?? "open")", tint: tint)
    }

    private var xpText: String {
        switch session.result(in: quest) {
        case .correct:
            return "+120"
        case .missed:
            return "0"
        case nil:
            return "120"
        }
    }

    private var photoText: String {
        session.hasSelection ? "OPEN" : "CLUE"
    }
}

private struct PreviewClueRow: View {
    let index: Int
    let clue: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(String(format: "%02d", index))
                .font(.caption.weight(.black).monospacedDigit())
                .foregroundStyle(WikiTheme.blue)
                .frame(width: 30, alignment: .leading)
            Text(clue)
                .font(.callout.weight(.semibold))
                .foregroundStyle(WikiTheme.ink)
                .lineLimit(3)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 9)
        .overlay(alignment: .bottom) {
            Rectangle().fill(WikiTheme.hairline).frame(height: 1)
        }
    }
}

private struct PreviewChoiceRow: View {
    let index: Int
    let choice: PreviewQuestChoice
    let result: PreviewQuestResult?
    let isSelected: Bool

    var body: some View {
        ZStack(alignment: .leading) {
            PreviewChoiceLane(tint: tint, isLocked: isLocked, isSelected: isSelected, isCorrect: isCorrectAfterResult)

            HStack(spacing: 10) {
                PreviewChoiceMarker(index: index, tint: tint, isSelected: isSelected, choiceIsCorrect: choice.isCorrect, result: result)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text("ANSWER \(String(format: "%02d", index))")
                            .font(.caption2.weight(.black).monospacedDigit())
                            .foregroundStyle(tint)
                        Rectangle()
                            .fill(tint.opacity(isLocked && !isSelected && !isCorrectAfterResult ? 0.22 : 0.48))
                            .frame(width: 18, height: 1)
                    }

                    Text(choice.title)
                        .font(.callout.weight(.black))
                        .foregroundStyle(titleColor)
                        .lineLimit(2)
                        .minimumScaleFactor(0.78)
                    Text(choice.detail)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(WikiTheme.muted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.76)
                }
                .layoutPriority(1)

                Spacer(minLength: 8)

                PreviewChoiceCommandBadge(
                    text: commandText,
                    iconName: iconName,
                    tint: tint,
                    isSubdued: isLocked && !isSelected && !isCorrectAfterResult
                )
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
        }
        .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
        .contentShape(Rectangle())
        .commandLanePulse(
            trigger: "\(isSelected)-\(isCorrectAfterResult)-\(result != nil)",
            tint: tint,
            enabled: isSelected || isCorrectAfterResult
        )
        .motionTick(trigger: "\(choice.id)-\(isSelected)-\(result != nil)", tint: tint, enabled: isSelected)
    }

    private var isLocked: Bool {
        result != nil
    }

    private var isCorrectAfterResult: Bool {
        isLocked && choice.isCorrect
    }

    private var tint: Color {
        if isCorrectAfterResult {
            return WikiTheme.green
        }
        if isSelected {
            switch result {
            case .correct:
                return WikiTheme.green
            case .missed:
                return WikiTheme.amber
            case nil:
                return WikiTheme.blue
            }
        }
        if isLocked {
            return WikiTheme.muted
        }
        return WikiTheme.blue
    }

    private var titleColor: Color {
        isLocked && !isSelected && !isCorrectAfterResult ? WikiTheme.subtle : WikiTheme.ink
    }

    private var commandText: String {
        guard isLocked else {
            return "PICK"
        }
        if isCorrectAfterResult {
            return "HIT"
        }
        return isSelected ? "MISS" : "LOCKED"
    }

    private var iconName: String {
        guard isLocked else {
            return "scope"
        }
        if isCorrectAfterResult {
            return "checkmark.seal.fill"
        }
        return isSelected ? "xmark.octagon.fill" : "lock.fill"
    }
}

private struct PreviewChoiceLane: View {
    let tint: Color
    let isLocked: Bool
    let isSelected: Bool
    let isCorrect: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: WikiTheme.controlRadius, style: .continuous)
            .fill(fill)
            .overlay {
                RoundedRectangle(cornerRadius: WikiTheme.controlRadius, style: .continuous)
                    .stroke(stroke, lineWidth: isSelected || isCorrect ? 1.35 : 1)
            }
            .overlay(alignment: .topLeading) {
                Rectangle()
                    .fill(tint.opacity(isLocked && !isSelected && !isCorrect ? 0.18 : 0.70))
                    .frame(width: 48, height: 2)
            }
    }

    private var fill: Color {
        if isSelected || isCorrect {
            return tint.opacity(0.10)
        }
        if isLocked {
            return WikiTheme.surface.opacity(0.56)
        }
        return WikiTheme.blue.opacity(0.045)
    }

    private var stroke: Color {
        if isSelected || isCorrect {
            return tint.opacity(0.68)
        }
        if isLocked {
            return WikiTheme.hairline
        }
        return WikiTheme.blue.opacity(0.28)
    }
}

private struct PreviewChoiceCommandBadge: View {
    let text: String
    let iconName: String
    let tint: Color
    let isSubdued: Bool

    var body: some View {
        HStack(spacing: 5) {
            Text(text)
                .font(.caption2.weight(.black).monospaced())
                .lineLimit(1)
                .minimumScaleFactor(0.70)
            Image(systemName: iconName)
                .font(.caption2.weight(.black))
        }
        .foregroundStyle(foreground)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        .accessibilityHidden(true)
    }

    private var foreground: Color {
        if isSubdued {
            return WikiTheme.muted
        }
        return .white
    }

    private var background: Color {
        if isSubdued {
            return WikiTheme.surface
        }
        return tint
    }
}

private struct PreviewChoiceMarker: View {
    let index: Int
    let tint: Color
    let isSelected: Bool
    let choiceIsCorrect: Bool
    let result: PreviewQuestResult?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(fill)
                .overlay {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .stroke(stroke, lineWidth: 1)
                }

            markerContent
        }
        .frame(width: 38, height: 44)
        .opacity(!isSelected && result != nil && !choiceIsCorrect ? 0.54 : 1)
    }

    @ViewBuilder
    private var markerContent: some View {
        if result != nil && choiceIsCorrect {
            Image(systemName: "checkmark.seal.fill")
                .font(.caption.weight(.black))
                .foregroundStyle(.white)
        } else if result != nil && isSelected {
            Image(systemName: "xmark.octagon.fill")
                .font(.caption.weight(.black))
                .foregroundStyle(.white)
        } else if isSelected {
            Image(systemName: "scope")
                .font(.caption.weight(.black))
                .foregroundStyle(.white)
        } else {
            Text(String(format: "%02d", index))
                .font(.caption.weight(.black).monospacedDigit())
                .foregroundStyle(result == nil ? WikiTheme.blue : WikiTheme.muted)
        }
    }

    private var fill: Color {
        if result != nil && choiceIsCorrect {
            return WikiTheme.green
        }
        if isSelected {
            return tint
        }
        if result != nil {
            return WikiTheme.surface
        }
        return WikiTheme.blue.opacity(0.07)
    }

    private var stroke: Color {
        if result != nil && choiceIsCorrect {
            return WikiTheme.green.opacity(0.80)
        }
        if isSelected {
            return tint
        }
        if result != nil {
            return WikiTheme.hairline
        }
        return WikiTheme.blue.opacity(0.35)
    }
}

private struct PreviewResultBanner: View {
    let result: PreviewQuestResult
    let reset: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            switch result {
            case .correct(let title):
                ResultBanner(title: "SOLVED", detail: title, score: 120, tint: WikiTheme.green, systemImage: "checkmark.seal.fill")
            case .missed(_, let correctTitle):
                ResultBanner(title: "REVEALED", detail: correctTitle, score: 0, tint: WikiTheme.amber, systemImage: "eye.fill")
            }
            PreviewReplayButton(reset: reset)
        }
        .transition(.scale(scale: 0.98).combined(with: .opacity))
    }
}

private struct PreviewReplayButton: View {
    let reset: () -> Void
    @State private var tapToken = 0

    var body: some View {
        Button {
            Haptics.light()
            tapToken &+= 1
            reset()
        } label: {
            Image(systemName: "arrow.clockwise")
                .font(.callout.weight(.black))
                .foregroundStyle(WikiTheme.blue)
                .frame(width: 46, height: 46)
                .overlay {
                    RoundedRectangle(cornerRadius: WikiTheme.radius, style: .continuous)
                        .stroke(WikiTheme.blue.opacity(0.82), lineWidth: 1)
                }
        }
        .buttonStyle(ArcadePressStyle())
        .accessibilityLabel("Replay preview")
        .accessibilityIdentifier("PreviewReplayButton")
        .motionTick(trigger: tapToken, tint: WikiTheme.blue)
    }
}

private struct BootupIntroView: View {
    let complete: () -> Void
    @EnvironmentObject private var motion: MotionSettings
    @State private var visibleStepCount = 0
    @State private var didStart = false

    private let steps = [
        BootupStep(code: "MYSTERY", detail: "Photo clue armed", systemImage: "questionmark.circle.fill", tint: WikiTheme.amber),
        BootupStep(code: "RACE", detail: "Blue links routed", systemImage: "link", tint: WikiTheme.blue),
        BootupStep(code: "MAP", detail: "Pins online", systemImage: "mappin.and.ellipse", tint: WikiTheme.green)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Spacer(minLength: 20)

            OnboardingLogoMark(size: 84)

            VStack(alignment: .leading, spacing: 10) {
                Text("WikiQuest")
                    .font(.system(size: 48, weight: .black, design: .serif))
                    .foregroundStyle(WikiTheme.ink)
                    .minimumScaleFactor(0.72)
                    .accessibilityIdentifier("BootupTitle")

                VStack(alignment: .leading, spacing: 7) {
                    ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                        if index < visibleStepCount {
                            BootupStepRow(index: index + 1, step: step)
                                .transition(.opacity.combined(with: .move(edge: .bottom)))
                                .accessibilityIdentifier("BootupStep-\(step.code)")
                        }
                    }
                }
                .frame(minHeight: 112, alignment: .topLeading)
                .accessibilityIdentifier("BootupLines")
            }

            Spacer(minLength: 24)

            BootupContinueCommand(complete: complete)
            .accessibilityIdentifier("BootupContinue")
        }
        .padding(WikiTheme.screenPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(WikiPaperBackground())
        .task { await runBootup() }
        .accessibilityIdentifier("BootupIntro")
    }

    @MainActor
    private func runBootup() async {
        guard !didStart else { return }
        didStart = true

        if motion.reduceMotion {
            visibleStepCount = steps.count
            return
        }

        let delay: UInt64 = OnboardingBootupPolicy.usesFastBootup ? 120_000_000 : 760_000_000
        for stepIndex in 1...steps.count {
            try? await Task.sleep(nanoseconds: delay)
            await MainActor.run {
                withAnimation(WikiMotion.panel) {
                    visibleStepCount = stepIndex
                }
            }
        }

        try? await Task.sleep(nanoseconds: OnboardingBootupPolicy.usesFastBootup ? 120_000_000 : 700_000_000)
        await MainActor.run {
            complete()
        }
    }
}

private struct BootupContinueCommand: View {
    let complete: () -> Void
    @EnvironmentObject private var motion: MotionSettings
    @State private var tapToken = 0
    @State private var activeIndex = 0

    var body: some View {
        Button {
            Haptics.light()
            tapToken &+= 1
            complete()
        } label: {
            HStack(alignment: .center, spacing: 11) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 7) {
                        Kicker(text: "Boot ready")
                        Text("PLAY")
                            .font(.caption2.weight(.black).monospaced())
                            .foregroundStyle(WikiTheme.blue)
                    }
                    Text("Start preview")
                        .font(.callout.weight(.black))
                        .foregroundStyle(WikiTheme.ink)
                }
                .layoutPriority(1)

                Spacer(minLength: 8)

                BootupCommandRail(activeIndex: currentIndex)

                Image(systemName: "arrow.right")
                    .font(.callout.weight(.black))
                    .foregroundStyle(WikiTheme.blue)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 12)
            .overlay(alignment: .top) {
                Rectangle().fill(WikiTheme.hairline).frame(height: 1)
            }
            .overlay(alignment: .bottom) {
                Rectangle().fill(WikiTheme.blue.opacity(0.42)).frame(height: 1)
            }
        }
        .buttonStyle(.plain)
        .task { await runTicker() }
        .motionTick(trigger: tapToken, tint: WikiTheme.blue)
        .accessibilityLabel("Start preview")
    }

    private var currentIndex: Int {
        motion.reduceMotion ? 0 : activeIndex
    }

    @MainActor
    private func runTicker() async {
        if motion.reduceMotion {
            activeIndex = 0
            return
        }
        while !Task.isCancelled {
            withAnimation(WikiMotion.tick) {
                activeIndex = (activeIndex + 1) % 3
            }
            try? await Task.sleep(nanoseconds: 520_000_000)
        }
    }
}

private struct BootupCommandRail: View {
    let activeIndex: Int

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(index == activeIndex ? WikiTheme.blue : WikiTheme.ink.opacity(0.22))
                    .frame(width: index == activeIndex ? 16 : 9, height: 4)
            }
        }
        .accessibilityHidden(true)
    }
}

private struct BootupStep {
    let code: String
    let detail: String
    let systemImage: String
    let tint: Color
}

private struct BootupStepRow: View {
    let index: Int
    let step: BootupStep

    var body: some View {
        HStack(spacing: 10) {
            Text(String(format: "%02d", index))
                .font(.caption.weight(.black).monospacedDigit())
                .foregroundStyle(step.tint)
                .frame(width: 28, alignment: .leading)

            Image(systemName: step.systemImage)
                .font(.caption.weight(.black))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(step.tint)
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(step.code)
                    .font(.caption.weight(.black).monospaced())
                    .foregroundStyle(WikiTheme.ink)
                    .lineLimit(1)
                Text(step.detail)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(WikiTheme.muted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)
            }

            Spacer(minLength: 8)

            Text("READY")
                .font(.caption2.weight(.black).monospaced())
                .foregroundStyle(step.tint)
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .background(step.tint.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .padding(.vertical, 7)
        .overlay(alignment: .bottom) {
            Rectangle().fill(WikiTheme.hairline).frame(height: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(step.code), \(step.detail), ready")
    }
}

private struct OnboardingLogoMark: View {
    let size: CGFloat
    @EnvironmentObject private var motion: MotionSettings
    @State private var appeared = false

    var body: some View {
        BrandMarkView(variant: .mark, size: size, animated: !motion.reduceMotion)
            .scaleEffect(appeared || motion.reduceMotion ? 1 : 0.96)
            .opacity(appeared || motion.reduceMotion ? 1 : 0.82)
            .overlay(alignment: .bottomTrailing) {
                Circle()
                    .fill(WikiTheme.blue)
                    .frame(width: max(8, size * 0.12), height: max(8, size * 0.12))
                    .scaleEffect(appeared || motion.reduceMotion ? 1 : 0.2)
                    .opacity(appeared || motion.reduceMotion ? 1 : 0)
                    .offset(x: -size * 0.08, y: -size * 0.08)
            }
            .onAppear {
                guard !motion.reduceMotion else {
                    appeared = true
                    return
                }
                withAnimation(.spring(response: 0.36, dampingFraction: 0.78)) {
                    appeared = true
                }
            }
            .accessibilityHidden(true)
    }
}

private struct OnboardingMode: Identifiable {
    let title: String
    let detail: String
    let assetName: String
    let tint: Color

    var id: String { title }
}

private struct OnboardingModeRow: View {
    let mode: OnboardingMode

    var body: some View {
        HStack(spacing: 12) {
            Image(mode.assetName)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: 34, height: 34)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(mode.title)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(WikiTheme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                Text(mode.detail)
                    .font(.caption)
                    .foregroundStyle(WikiTheme.muted)
                    .lineLimit(2)
            }
            Spacer(minLength: 8)
            Capsule()
                .fill(mode.tint)
                .frame(width: 4, height: 32)
        }
        .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
        .padding(.vertical, 7)
        .overlay(alignment: .bottom) {
            Rectangle().fill(WikiTheme.hairline).frame(height: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(accessibilityIdentifier)
    }

    private var accessibilityIdentifier: String {
        switch mode.title {
        case "Mystery":
            return "OnboardingMode-DailyMystery"
        case "Race":
            return "OnboardingMode-LinkRace"
        case "Map":
            return "OnboardingMode-Nearby"
        default:
            return "OnboardingMode-\(mode.title.replacingOccurrences(of: " ", with: ""))"
        }
    }
}

private struct OnboardingModeStrip: View {
    let modes: [OnboardingMode]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Kicker(text: "Modes")
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(modes.enumerated()), id: \.element.id) { index, mode in
                    PanelReveal(delay: Double(index) * 0.035) {
                        OnboardingModeRow(mode: mode)
                    }
                }
            }
        }
    }
}

private struct OnboardingLegalLinks: View {
    var body: some View {
        HStack(spacing: 12) {
            Link("Privacy", destination: WikiQuestConfig.apiBaseURL.appending(path: "privacy"))
                .accessibilityIdentifier("OnboardingPrivacyLink")
            Text("/")
                .foregroundStyle(WikiTheme.subtle)
            Link("Terms", destination: WikiQuestConfig.apiBaseURL.appending(path: "terms"))
                .accessibilityIdentifier("OnboardingTermsLink")
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(WikiTheme.blue)
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.top, 2)
    }
}
