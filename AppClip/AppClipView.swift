import SwiftUI

struct AppClipView: View {
    private let appStoreURL = URL(string: "https://apps.apple.com/app/id6766046481")
    @StateObject private var model: AppClipQuestViewModel
    @State private var session = ClipQuestSession()

    init(model: AppClipQuestViewModel) {
        _model = StateObject(wrappedValue: model)
    }

    private var quest: ClipQuest {
        model.quest
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                clueStack
                choiceStack
                resultBlock
                installBlock
            }
            .padding(20)
            .padding(.top, 10)
        }
        .background(ClipPaperBackground())
        .accessibilityIdentifier("ClipQuestRoot")
        .task {
            await model.load()
        }
        .onChange(of: quest) { _, _ in
            session.reset()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            ClipOSBar()

            VStack(alignment: .leading, spacing: 7) {
                Text(quest.kicker)
                    .font(.caption.weight(.bold).monospaced())
                    .foregroundStyle(ClipPalette.muted)
                Text(quest.title)
                    .font(.system(size: 38, weight: .black, design: .monospaced))
                    .foregroundStyle(ClipPalette.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.72)
                Text(quest.prompt)
                    .font(.callout)
                    .foregroundStyle(ClipPalette.muted)
                    .lineSpacing(3)
            }

            ClipHeroImage(url: quest.imageURL, title: quest.title)
            if let sourceURL = quest.sourceURL {
                Link("Wikipedia / Wikimedia Commons", destination: sourceURL)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(ClipPalette.muted)
            }
        }
    }

    private var clueStack: some View {
        VStack(alignment: .leading, spacing: 10) {
            ClipSectionLabel(
                title: "Clues",
                meta: "\(session.visibleClues(in: quest).count)/\(quest.clues.count)"
            )

            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(session.visibleClues(in: quest).enumerated()), id: \.offset) { index, clue in
                    ClipClueRow(index: index + 1, clue: clue)
                }
            }

            if session.canRevealMore(in: quest) {
                Button {
                    withAnimation(.spring(response: 0.24, dampingFraction: 0.88)) {
                        session.revealNext(in: quest)
                    }
                } label: {
                    Label("Reveal next clue", systemImage: "plus.circle.fill")
                        .font(.callout.weight(.bold))
                        .foregroundStyle(ClipPalette.blue)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 11)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("ClipQuestRevealClue")
            }
        }
    }

    private var choiceStack: some View {
        VStack(alignment: .leading, spacing: 10) {
            ClipSectionLabel(title: "Guess", meta: session.hasSelection ? "LOCKED" : "ONE SHOT")
            VStack(alignment: .leading, spacing: 0) {
                ForEach(quest.choices) { choice in
                    Button {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                            session.choose(choiceID: choice.id, in: quest)
                        }
                    } label: {
                        ClipChoiceRow(
                            choice: choice,
                            result: session.result(in: quest),
                            isSelected: session.selectedChoiceID == choice.id
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(session.hasSelection)
                    .accessibilityIdentifier("ClipQuestChoice-\(choice.id)")
                    .accessibilityValue(accessibilityValue(for: choice))
                }
            }
        }
    }

    private func accessibilityValue(for choice: ClipQuestChoice) -> String {
        guard session.hasSelection else { return choice.detail }
        if session.selectedChoiceID == choice.id {
            switch session.result(in: quest) {
            case .correct:
                return "Selected. Correct answer."
            case .missed:
                return "Selected. Not the hidden page."
            case nil:
                return "Selected."
            }
        }
        if choice.isCorrect {
            return "Correct answer."
        }
        return "Not selected."
    }

    @ViewBuilder
    private var resultBlock: some View {
        if let result = session.result(in: quest) {
            switch result {
            case .correct(let title, let xpPreview):
                ClipResultBanner(
                    title: "Solved",
                    detail: "\(title) was the page. Save runs like this for \(xpPreview) XP.",
                    tint: ClipPalette.green,
                    systemImage: "checkmark.seal.fill"
                )
            case .missed(_, let correctTitle):
                ClipResultBanner(
                    title: "Missed",
                    detail: "The page was \(correctTitle). Open the app to try today's Mystery.",
                    tint: ClipPalette.amber,
                    systemImage: "arrow.counterclockwise.circle.fill"
                )
            }
        }
    }

    private var installBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let appStoreURL {
                Link(destination: appStoreURL) {
                    Label("Open full app", systemImage: "arrow.down.app.fill")
                        .font(.callout.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(ClipPalette.ink)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .accessibilityIdentifier("ClipQuestOpenFullAppLabel")
                }
                .accessibilityIdentifier("ClipQuestOpenFullApp")
            }

            Text("Open the full app to save your trail.")
                .font(.caption)
                .foregroundStyle(ClipPalette.muted)
                .lineSpacing(3)
        }
        .padding(.top, 2)
    }
}

private struct ClipHeroImage: View {
    let url: URL?
    let title: String

    var body: some View {
        ZStack {
            if let url {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        fallback
                    }
                }
            } else {
                fallback
            }
            LinearGradient(colors: [.black.opacity(0.48), .clear, .black.opacity(0.54)], startPoint: .top, endPoint: .bottom)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 208)
        .background(ClipPalette.ink)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(ClipPalette.blue.opacity(0.65), lineWidth: 1)
        }
        .accessibilityLabel(title)
    }

    private var fallback: some View {
        ZStack {
            ClipPalette.ink
            GridPattern()
                .stroke(ClipPalette.blue.opacity(0.20), lineWidth: 1)
            Image("BrandGlyph")
                .resizable()
                .scaledToFit()
                .frame(width: 52, height: 52)
                .opacity(0.88)
        }
    }
}

private struct ClipOSBar: View {
    var body: some View {
        HStack(spacing: 10) {
            Image("BrandGlyph")
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: 42, height: 42)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text("WikiQuest")
                    .font(.caption.weight(.black).monospaced())
                    .foregroundStyle(ClipPalette.ink)
                Text("APP CLIP / MYSTERY")
                    .font(.caption2.weight(.bold).monospaced())
                    .foregroundStyle(ClipPalette.blue)
            }
            Spacer(minLength: 8)
            Text("CLIP")
                .font(.caption2.weight(.black).monospaced())
                .foregroundStyle(ClipPalette.green)
        }
        .padding(.vertical, 10)
        .overlay(alignment: .top) {
            Rectangle().fill(ClipPalette.ink).frame(height: 2)
        }
        .overlay(alignment: .bottom) {
            Rectangle().fill(ClipPalette.hairline).frame(height: 1)
        }
    }
}

private struct ClipSectionLabel: View {
    let title: String
    let meta: String

    init(title: String, meta: String = "") {
        self.title = title
        self.meta = meta
    }

    var body: some View {
        HStack {
            Text(title.uppercased())
                .font(.caption.weight(.bold).monospaced())
                .foregroundStyle(ClipPalette.muted)
            Spacer(minLength: 8)
            if !meta.isEmpty {
                Text(meta)
                    .font(.caption.weight(.black).monospaced())
                    .foregroundStyle(ClipPalette.blue)
            }
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(ClipPalette.hairline)
                .frame(height: 1)
                .offset(y: 6)
        }
        .padding(.bottom, 6)
    }
}

private struct ClipClueRow: View {
    let index: Int
    let clue: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(String(format: "%02d", index))
                .font(.caption.weight(.black).monospacedDigit())
                .foregroundStyle(ClipPalette.blue)
                .frame(width: 30, alignment: .leading)
            Text(clue)
                .font(.callout.weight(.semibold))
                .foregroundStyle(ClipPalette.ink)
                .lineLimit(3)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) {
            Rectangle().fill(ClipPalette.hairline).frame(height: 1)
        }
    }
}

private struct ClipChoiceRow: View {
    let choice: ClipQuestChoice
    let result: ClipQuestResult?
    let isSelected: Bool

    private var tint: Color {
        guard isSelected else { return ClipPalette.blue }
        switch result {
        case .correct:
            return ClipPalette.green
        case .missed:
            return ClipPalette.amber
        case nil:
            return ClipPalette.blue
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Capsule()
                .fill(isSelected ? tint : ClipPalette.hairline)
                .frame(width: 4, height: 32)
            VStack(alignment: .leading, spacing: 3) {
                Text(choice.title)
                    .font(.callout.weight(.bold))
                    .foregroundStyle(ClipPalette.ink)
                Text(choice.detail)
                    .font(.caption)
                    .foregroundStyle(ClipPalette.muted)
            }
            Spacer(minLength: 8)
            Image(systemName: isSelected ? "target" : "chevron.right")
                .font(.callout.weight(.bold))
                .foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
        .padding(.vertical, 7)
        .overlay(alignment: .bottom) {
            Rectangle().fill(ClipPalette.hairline).frame(height: 1)
        }
    }
}

private struct ClipResultBanner: View {
    let title: String
    let detail: String
    let tint: Color
    let systemImage: String

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: systemImage)
                .font(.title2.weight(.black))
                .foregroundStyle(tint)
                .frame(width: 38, height: 38)
            VStack(alignment: .leading, spacing: 3) {
                Text(title.uppercased())
                    .font(.caption.weight(.bold).monospaced())
                    .foregroundStyle(tint)
                    .accessibilityIdentifier("ClipQuestResultTitle")
                Text(detail)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(ClipPalette.ink)
                    .lineLimit(3)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 12)
        .overlay(alignment: .top) {
            Rectangle().fill(tint).frame(height: 3)
        }
        .transition(.scale(scale: 0.98).combined(with: .opacity))
        .accessibilityIdentifier("ClipQuestResultBanner")
    }
}

private enum ClipPalette {
    static let paper = Color(red: 0.935, green: 0.920, blue: 0.875)
    static let ink = Color(red: 0.035, green: 0.040, blue: 0.050)
    static let muted = Color(red: 0.245, green: 0.255, blue: 0.265)
    static let blue = Color(red: 0.055, green: 0.235, blue: 0.60)
    static let green = Color(red: 0.065, green: 0.38, blue: 0.245)
    static let amber = Color(red: 0.74, green: 0.47, blue: 0.075)
    static let hairline = Color.black.opacity(0.16)
}

private struct ClipPaperBackground: View {
    var body: some View {
        ClipPalette.paper
            .overlay {
                GridPattern()
                    .stroke(Color.black.opacity(0.08), lineWidth: 1)
                    .ignoresSafeArea()
            }
            .ignoresSafeArea()
    }
}

private struct GridPattern: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let step: CGFloat = 28
        var x = rect.minX
        while x <= rect.maxX {
            path.move(to: CGPoint(x: x, y: rect.minY))
            path.addLine(to: CGPoint(x: x, y: rect.maxY))
            x += step
        }
        var y = rect.minY
        while y <= rect.maxY {
            path.move(to: CGPoint(x: rect.minX, y: y))
            path.addLine(to: CGPoint(x: rect.maxX, y: y))
            y += step
        }
        return path
    }
}
