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
        OnboardingMode(title: "Mystery", detail: "Solve a hidden article", assetName: "ModeMysteryMark", tint: WikiTheme.amber),
        OnboardingMode(title: "Race", detail: "Follow blue links fast", assetName: "ModeRaceMark", tint: WikiTheme.blue),
        OnboardingMode(title: "Map", detail: "Place the pin", assetName: "ModeNearbyMark", tint: WikiTheme.green)
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

                    appleSignInBlock

                    OnboardingModeStrip(modes: modes)

                    OnboardingLegalLinks()
                }
                .padding(WikiTheme.screenPadding)
                .padding(.top, max(8, proxy.safeAreaInsets.top + 4))
                .padding(.bottom, max(18, proxy.safeAreaInsets.bottom + 18))
                .frame(minHeight: proxy.size.height, alignment: .topLeading)
                .accessibilityIdentifier("OnboardingContainer")
            }
            .scrollIndicators(.hidden)
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
        VStack(alignment: .leading, spacing: 12) {
            OnboardingLogoMark(size: 62)
            VStack(alignment: .leading, spacing: 8) {
                Text("WikiQuest")
                    .font(.system(size: 46, weight: .black, design: .serif))
                    .foregroundStyle(WikiTheme.ink)
                    .minimumScaleFactor(0.70)
                    .accessibilityIdentifier("OnboardingTitle")
                Text("Play the preview. Sign in to keep your streak.")
                    .font(.callout)
                    .foregroundStyle(WikiTheme.muted)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var appleSignInBlock: some View {
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

            if session.isSigningIn {
                WikiLoadingGlyph(title: "Apple ID", detail: "Waiting for Apple.", tint: WikiTheme.ink)
            } else if let error = session.lastAuthError {
                InlineNotice(title: "SIGN IN", detail: error, tint: WikiTheme.red)
            } else if previewSession.hasSelection {
                Text("Save your solves, streak, Race paths, Map pins, and purchases.")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(WikiTheme.subtle)
                    .lineLimit(2)
            } else {
                Text("Try the preview first, then sign in when the game clicks.")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(WikiTheme.subtle)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
        .overlay(alignment: .top) {
            Rectangle().fill(WikiTheme.hairline).frame(height: 1)
        }
    }
}

private struct PreviewQuestPanel: View {
    @Binding var session: PreviewQuestSession
    let quest: PreviewQuest
    @EnvironmentObject private var motion: MotionSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PhotoClueCard(
                kicker: quest.kicker,
                title: title,
                detail: detail,
                media: quest.media,
                visualState: visualState,
                tint: resultTint,
                fallbackStyle: .mystery
            )

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
                    Label("Reveal clue", systemImage: "plus.circle.fill")
                        .font(.callout.weight(.black))
                        .foregroundStyle(WikiTheme.blue)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 10)
                        .overlay(alignment: .top) {
                            Rectangle().fill(WikiTheme.hairline).frame(height: 1)
                        }
                }
                .buttonStyle(ArcadePressStyle())
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
            return "Now keep the run, streak, and score."
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
            GameHUDItem(label: "Choices", value: "\(quest.choices.count)", systemImage: "list.number", tint: WikiTheme.amber, flashesOnChange: false),
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
        HStack(spacing: 12) {
            PreviewChoiceMarker(index: index, tint: tint, isSelected: isSelected, isLocked: result != nil)

            VStack(alignment: .leading, spacing: 3) {
                Text(choice.title)
                    .font(.callout.weight(.bold))
                    .foregroundStyle(WikiTheme.ink)
                    .lineLimit(2)
                Text(choice.detail)
                    .font(.caption)
                    .foregroundStyle(WikiTheme.muted)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            Image(systemName: iconName)
                .font(.callout.weight(.bold))
                .foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
        .padding(.vertical, 6)
        .overlay(alignment: .bottom) {
            Rectangle().fill(WikiTheme.hairline).frame(height: 1)
        }
        .contentShape(Rectangle())
        .motionTick(trigger: "\(choice.id)-\(isSelected)-\(result != nil)", tint: tint, enabled: isSelected)
    }

    private var tint: Color {
        guard isSelected else { return WikiTheme.blue }
        switch result {
        case .correct:
            return WikiTheme.green
        case .missed:
            return WikiTheme.amber
        case nil:
            return WikiTheme.blue
        }
    }

    private var iconName: String {
        guard isSelected else { return "chevron.right" }
        switch result {
        case .correct:
            return "checkmark.seal.fill"
        case .missed:
            return "xmark.octagon.fill"
        case nil:
            return "target"
        }
    }
}

private struct PreviewChoiceMarker: View {
    let index: Int
    let tint: Color
    let isSelected: Bool
    let isLocked: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(isSelected ? tint : WikiTheme.blue.opacity(0.07))
                .overlay {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .stroke(isSelected ? tint : WikiTheme.blue.opacity(0.35), lineWidth: 1)
                }

            markerContent
        }
        .frame(width: 38, height: 44)
        .opacity(!isSelected && isLocked ? 0.46 : 1)
    }

    @ViewBuilder
    private var markerContent: some View {
        if isSelected {
            Image(systemName: "scope")
                .font(.caption.weight(.black))
                .foregroundStyle(.white)
        } else {
            Text(String(format: "%02d", index))
                .font(.caption.weight(.black).monospacedDigit())
                .foregroundStyle(WikiTheme.blue)
        }
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
            Button("Try preview again", action: reset)
                .font(.caption.weight(.bold))
                .foregroundStyle(WikiTheme.blue)
                .buttonStyle(ArcadePressStyle())
        }
        .transition(.scale(scale: 0.98).combined(with: .opacity))
    }
}

private struct BootupIntroView: View {
    let complete: () -> Void
    @EnvironmentObject private var motion: MotionSettings
    @State private var visibleLineCount = 0
    @State private var didStart = false

    private let lines = [
        "Loading today's article",
        "Preparing link race",
        "Opening the map"
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

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                        if index < visibleLineCount {
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(WikiTheme.blue)
                                    .frame(width: 6, height: 6)
                                Text(line)
                                    .font(.callout.weight(.semibold))
                                    .foregroundStyle(WikiTheme.muted)
                            }
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                        }
                    }
                }
                .frame(minHeight: 86, alignment: .topLeading)
                .accessibilityIdentifier("BootupLines")
            }

            Spacer(minLength: 24)

            Button {
                complete()
            } label: {
                Text("Continue")
                    .font(.callout.weight(.bold))
                    .foregroundStyle(WikiTheme.blue)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 12)
                    .overlay(alignment: .top) {
                        Rectangle().fill(WikiTheme.hairline).frame(height: 1)
                    }
            }
            .buttonStyle(.plain)
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
            visibleLineCount = lines.count
            return
        }

        let delay: UInt64 = OnboardingBootupPolicy.usesFastBootup ? 120_000_000 : 760_000_000
        for lineIndex in 1...lines.count {
            try? await Task.sleep(nanoseconds: delay)
            await MainActor.run {
                withAnimation(WikiMotion.panel) {
                    visibleLineCount = lineIndex
                }
            }
        }

        try? await Task.sleep(nanoseconds: OnboardingBootupPolicy.usesFastBootup ? 120_000_000 : 700_000_000)
        await MainActor.run {
            complete()
        }
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
