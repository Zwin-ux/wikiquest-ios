import AuthenticationServices
import SwiftUI
import UIKit

enum WikiTheme {
    static let paper = Color(red: 0.935, green: 0.920, blue: 0.875)
    static let surface = Color(red: 0.985, green: 0.975, blue: 0.940)
    static let surfaceStrong = Color(red: 0.998, green: 0.994, blue: 0.975)
    static let ink = Color(red: 0.035, green: 0.040, blue: 0.050)
    static let muted = Color(red: 0.245, green: 0.255, blue: 0.265)
    static let subtle = Color(red: 0.405, green: 0.425, blue: 0.455)
    static let faint = Color(red: 0.785, green: 0.755, blue: 0.675)
    static let rule = Color(red: 0.495, green: 0.465, blue: 0.385)
    static let hairline = Color.black.opacity(0.16)
    static let blue = Color(red: 0.055, green: 0.235, blue: 0.60)
    static let green = Color(red: 0.065, green: 0.38, blue: 0.245)
    static let red = Color(red: 0.63, green: 0.12, blue: 0.12)
    static let amber = Color(red: 0.74, green: 0.47, blue: 0.075)
    static let violet = Color(red: 0.33, green: 0.23, blue: 0.54)
    static let tile = surfaceStrong.opacity(0.82)
    static let dockBackground = ink.opacity(0.985)
    static let mapOverlay = Color(red: 0.08, green: 0.09, blue: 0.10).opacity(0.92)

    static let radius: CGFloat = 7
    static let controlRadius: CGFloat = 10
    static let screenPadding: CGFloat = 18
    static let rowHeight: CGFloat = 58
    static let osBarHeight: CGFloat = 42
    static let dockHeight: CGFloat = 74
    static let mapHeight: CGFloat = 360
}

struct Kicker: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(.caption.weight(.semibold).monospaced())
            .foregroundStyle(WikiTheme.muted)
    }
}

struct CommandButton: View {
    let title: String
    var icon: String = "return"
    var tint: Color = WikiTheme.blue
    var isDisabled = false
    var playsHaptic = true
    var action: () -> Void
    @State private var tapToken = 0

    var body: some View {
        Button(action: {
            if playsHaptic {
                Haptics.light()
            }
            tapToken &+= 1
            action()
        }) {
            Label(title, systemImage: icon)
                .font(.callout.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .foregroundStyle(.white)
                .background(tint)
                .clipShape(RoundedRectangle(cornerRadius: WikiTheme.radius, style: .continuous))
        }
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.45 : 1)
        .buttonStyle(ArcadePressStyle())
        .motionTick(trigger: tapToken, tint: tint, enabled: !isDisabled)
    }
}

struct WikiScreen<Content: View>: View {
    let navigationTitle: String
    var spacing: CGFloat = 18
    var showsWindowHeader = true
    @ViewBuilder var content: Content

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: spacing) {
                    if showsWindowHeader {
                        WikiOSWindowHeader(title: navigationTitle)
                    }
                    content
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(WikiTheme.screenPadding)
                .padding(.bottom, 10)
                .foregroundStyle(WikiTheme.ink)
            }
            .scrollIndicators(.hidden)
            .background(WikiPaperBackground())
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

struct WikiOSWindowHeader: View {
    let title: String

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            HStack(spacing: 5) {
                Circle().fill(WikiTheme.red).frame(width: 7, height: 7)
                Circle().fill(WikiTheme.amber).frame(width: 7, height: 7)
                Circle().fill(WikiTheme.green).frame(width: 7, height: 7)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("WIKIQUEST")
                    .font(.caption2.weight(.black).monospaced())
                    .foregroundStyle(WikiTheme.subtle)
                Text(routeLabel)
                    .font(.caption.weight(.bold).monospaced())
                    .foregroundStyle(WikiTheme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.74)
            }
            Spacer(minLength: 8)
            Text("READY")
                .font(.caption2.weight(.black).monospaced())
                .foregroundStyle(WikiTheme.green)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(WikiTheme.surfaceStrong.opacity(0.74))
        .overlay(alignment: .top) {
            Rectangle().fill(WikiTheme.ink.opacity(0.82)).frame(height: 2)
        }
        .overlay(alignment: .bottom) {
            Rectangle().fill(WikiTheme.hairline).frame(height: 1)
        }
        .accessibilityElement(children: .combine)
    }

    private var routeLabel: String {
        switch title.lowercased() {
        case "home":
            return "wikiquest://index"
        case "mystery":
            return "special:mystery"
        case "link race":
            return "special:link-race"
        case "nearby":
            return "geo:nearby"
        case "leaderboard":
            return "sys:ranks"
        case "profile":
            return "user:profile"
        default:
            return title.lowercased().replacingOccurrences(of: " ", with: ":")
        }
    }
}

struct WikiPaperBackground: View {
    var body: some View {
        WikiTheme.paper
            .overlay {
                GridPattern()
                    .stroke(WikiTheme.rule.opacity(0.12), lineWidth: 1)
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

struct CommandField: View {
    let placeholder: String
    @Binding var text: String
    var submit: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            TextField(placeholder, text: $text)
                .textInputAutocapitalization(.words)
                .submitLabel(.go)
                .onSubmit(submit)
                .foregroundStyle(WikiTheme.ink)
                .tint(WikiTheme.blue)
            Button(action: submit) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundStyle(WikiTheme.blue)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 10)
        .overlay(alignment: .bottom) {
            Rectangle().fill(WikiTheme.rule).frame(height: 1)
        }
        .accessibilityElement(children: .contain)
    }
}

struct ArcadePressStyle: ButtonStyle {
    @EnvironmentObject private var motion: MotionSettings

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(motion.reduceMotion ? 1 : (configuration.isPressed ? 0.985 : 1))
            .offset(y: motion.reduceMotion ? 0 : (configuration.isPressed ? 1 : 0))
            .animation(WikiMotion.active(WikiMotion.quick, reduceMotion: motion.reduceMotion), value: configuration.isPressed)
    }
}

struct ScreenHeader: View {
    let kicker: String
    let title: String
    var detail: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Kicker(text: kicker)
                Spacer(minLength: 8)
                Text("WIKI")
                    .font(.caption2.weight(.black).monospaced())
                    .foregroundStyle(WikiTheme.subtle)
            }
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.system(.title2, design: .monospaced).weight(.black))
                    .foregroundStyle(WikiTheme.ink)
                    .lineLimit(3)
                    .minimumScaleFactor(0.72)
                if let detail {
                    Text(detail)
                        .font(.callout)
                        .foregroundStyle(WikiTheme.muted)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(.vertical, 4)
        .overlay(alignment: .bottom) {
            Rectangle().fill(WikiTheme.rule.opacity(0.42)).frame(height: 1)
        }
    }
}

struct WikiOSPanel<Content: View>: View {
    let title: String
    var status: String = "READY"
    var tint: Color = WikiTheme.ink
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Kicker(text: title)
                Spacer(minLength: 8)
                Text(status.uppercased())
                    .font(.caption2.weight(.black).monospaced())
                    .foregroundStyle(tint)
            }
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 12)
        .overlay(alignment: .top) {
            Rectangle().fill(tint.opacity(0.72)).frame(height: 2)
        }
        .overlay(alignment: .bottom) {
            Rectangle().fill(WikiTheme.hairline).frame(height: 1)
        }
    }
}

struct WikiOSBootLine: View {
    let command: String
    let detail: String
    var tint: Color = WikiTheme.green

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(">")
                .font(.caption.weight(.black).monospaced())
                .foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(command.uppercased())
                    .font(.caption.weight(.black).monospaced())
                    .foregroundStyle(WikiTheme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(WikiTheme.muted)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 7)
        .overlay(alignment: .bottom) {
            Rectangle().fill(WikiTheme.hairline).frame(height: 1)
        }
    }
}

enum BrandMarkVariant {
    case mark
    case glyph

    var assetName: String {
        switch self {
        case .mark:
            return "BrandMark"
        case .glyph:
            return "BrandGlyph"
        }
    }

    var cornerRadiusRatio: CGFloat {
        switch self {
        case .mark:
            return 0.18
        case .glyph:
            return 0.08
        }
    }
}

struct BrandMarkView: View {
    var variant: BrandMarkVariant = .mark
    var size: CGFloat = 56
    var animated = false
    @EnvironmentObject private var motion: MotionSettings
    @State private var scanOffset: CGFloat = -1

    var body: some View {
        Image(variant.assetName)
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .frame(width: size, height: size)
            .overlay {
                if animated && !motion.reduceMotion {
                    GeometryReader { proxy in
                        LinearGradient(
                            colors: [.clear, Color.white.opacity(0.55), .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(width: proxy.size.width * 0.42, height: proxy.size.height * 1.4)
                        .rotationEffect(.degrees(-18))
                        .offset(x: scanOffset * proxy.size.width * 1.7)
                        .blendMode(.screen)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: size * variant.cornerRadiusRatio, style: .continuous))
                    .allowsHitTesting(false)
                }
            }
            .onAppear {
                guard animated, !motion.reduceMotion else { return }
                scanOffset = -0.75
                withAnimation(.linear(duration: 1.45).repeatForever(autoreverses: false)) {
                    scanOffset = 0.95
                }
            }
            .accessibilityHidden(true)
    }
}

struct BrandHeader: View {
    let kicker: String
    let title: String
    var detail: String?
    var accent: Color = WikiTheme.ink
    var animatedMark = false
    var markSize: CGFloat = 62

    var body: some View {
        HStack(alignment: .top, spacing: 13) {
            BrandMarkView(variant: .mark, size: markSize, animated: animatedMark)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 6) {
                Kicker(text: kicker)
                Text(title)
                    .font(.system(.largeTitle, design: .serif).weight(.bold))
                    .foregroundStyle(WikiTheme.ink)
                    .lineLimit(3)
                    .minimumScaleFactor(0.72)
                    .fixedSize(horizontal: false, vertical: true)
                if let detail {
                    Text(detail)
                        .font(.callout)
                        .foregroundStyle(WikiTheme.muted)
                        .lineSpacing(3)
                }
            }
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(accent.opacity(0.52))
                .frame(height: 2)
                .offset(y: 12)
        }
        .padding(.bottom, 12)
    }
}

struct WikiLoadingGlyph: View {
    let title: String
    let detail: String
    var tint: Color = WikiTheme.blue
    @EnvironmentObject private var motion: MotionSettings
    @State private var pulse = false

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                BrandMarkView(variant: .glyph, size: 34, animated: false)
                    .opacity(0.92)
                Circle()
                    .trim(from: 0.12, to: 0.72)
                    .stroke(tint, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .rotationEffect(.degrees(pulse ? 360 : 0))
                    .frame(width: 48, height: 48)
                    .opacity(motion.reduceMotion ? 0 : 1)
            }
            VStack(alignment: .leading, spacing: 4) {
                Kicker(text: title)
                Text(detail)
                    .font(.callout)
                    .foregroundStyle(WikiTheme.muted)
                    .lineSpacing(3)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 12)
        .overlay(alignment: .top) {
            Rectangle().fill(tint.opacity(0.65)).frame(height: 2)
        }
        .onAppear {
            guard !motion.reduceMotion else { return }
            withAnimation(.linear(duration: 0.9).repeatForever(autoreverses: false)) {
                pulse = true
            }
        }
    }
}

struct ResultStamp: View {
    let systemImage: String
    let tint: Color
    var value: Int = 0
    @EnvironmentObject private var motion: MotionSettings

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: WikiTheme.radius, style: .continuous)
                .fill(tint.opacity(0.13))
                .overlay {
                    RoundedRectangle(cornerRadius: WikiTheme.radius, style: .continuous)
                        .stroke(tint.opacity(0.7), lineWidth: 1)
                }
            Image(systemName: systemImage)
                .font(.title2.weight(.black))
                .foregroundStyle(tint)
                .wikiBounce(enabled: !motion.reduceMotion, value: value)
        }
        .frame(width: 44, height: 44)
    }
}

struct StatusMetric: View {
    let label: String
    var value: Int?
    var text: String?
    var tint: Color = WikiTheme.ink

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Kicker(text: label)
            if let value {
                TickerNumberText(value: value)
                    .foregroundStyle(tint)
            } else {
                Text(text ?? "-")
                    .font(.system(.title3, design: .monospaced).weight(.bold))
                    .foregroundStyle(tint)
                    .contentTransition(.numericText())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
        .overlay(alignment: .top) {
            Rectangle().fill(WikiTheme.rule.opacity(0.42)).frame(height: 1)
        }
        .motionTick(trigger: "\(value ?? -999_999)-\(text ?? "")", tint: tint)
    }
}

struct StatusStrip: View {
    let items: [WikiMetric]

    var body: some View {
        HStack(spacing: 14) {
            ForEach(items) { item in
                MetricTicker(metric: item)
            }
        }
        .padding(.vertical, 2)
    }
}

struct GameHUDPill: View {
    let label: String
    let value: String
    var systemImage: String?
    var tint: Color = WikiTheme.blue
    var flashesOnChange = true

    var body: some View {
        HStack(spacing: 7) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.caption.weight(.black))
                    .foregroundStyle(tint)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(label.uppercased())
                    .font(.caption2.weight(.black).monospaced())
                    .foregroundStyle(.white.opacity(0.64))
                Text(value)
                    .font(.caption.weight(.black).monospaced())
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .contentTransition(.numericText())
                    .animation(WikiMotion.ticker, value: value)
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background(.black.opacity(0.56))
        .overlay(alignment: .leading) {
            Rectangle().fill(tint).frame(width: 2)
        }
        .clipShape(RoundedRectangle(cornerRadius: WikiTheme.radius, style: .continuous))
        .motionTick(trigger: value, tint: tint, enabled: flashesOnChange)
    }
}

struct WikiMetric: Identifiable {
    let label: String
    var id: String { label }
    var value: Int?
    var text: String?
    var tint: Color = WikiTheme.ink

    init(label: String, value: Int? = nil, text: String? = nil, tint: Color = WikiTheme.ink) {
        self.label = label
        self.value = value
        self.text = text
        self.tint = tint
    }

    init(label: String, value: Int? = nil, text: String? = nil, color: Color) {
        self.init(label: label, value: value, text: text, tint: color)
    }
}

typealias StatusMetricItem = WikiMetric

struct MetricTicker: View {
    let metric: WikiMetric

    var body: some View {
        StatusMetric(label: metric.label, value: metric.value, text: metric.text, tint: metric.tint)
    }
}

struct FlatSection<Content: View>: View {
    let title: String
    var footer: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Kicker(text: title)
            VStack(alignment: .leading, spacing: 0) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .top) {
                Rectangle().fill(WikiTheme.hairline).frame(height: 1)
            }
            .overlay(alignment: .bottom) {
                Rectangle().fill(WikiTheme.hairline).frame(height: 1)
            }
            if let footer {
                Text(footer)
                    .font(.caption)
                    .foregroundStyle(WikiTheme.subtle)
            }
        }
    }
}

struct CommandRow: View {
    let title: String
    var detail: String?
    var meta: String?
    var systemImage: String = "chevron.right"
    var tint: Color = WikiTheme.blue
    var isDisabled = false
    var playsHaptic = true
    var action: () -> Void
    @State private var tapToken = 0

    var body: some View {
        Button(action: {
            if playsHaptic {
                Haptics.light()
            }
            tapToken &+= 1
            action()
        }) {
            HStack(spacing: 12) {
                Capsule()
                    .fill(tint)
                    .frame(width: 4, height: 30)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(isDisabled ? WikiTheme.subtle : WikiTheme.ink)
                        .lineLimit(2)
                    if let detail {
                        Text(detail)
                            .font(.caption)
                            .foregroundStyle(WikiTheme.muted)
                            .lineLimit(2)
                    }
                }
                Spacer(minLength: 8)
                if let meta {
                    Text(meta)
                        .font(.caption.weight(.bold).monospaced())
                        .foregroundStyle(WikiTheme.muted)
                        .lineLimit(1)
                }
                Image(systemName: systemImage)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(isDisabled ? WikiTheme.subtle : tint)
            }
            .frame(maxWidth: .infinity, minHeight: WikiTheme.rowHeight, alignment: .leading)
            .padding(.vertical, 8)
            .overlay(alignment: .bottom) {
                Rectangle().fill(WikiTheme.hairline).frame(height: 1)
            }
        }
        .buttonStyle(ArcadePressStyle())
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.52 : 1)
        .motionTick(trigger: tapToken, tint: tint, enabled: !isDisabled)
    }
}

struct ModeRow: View {
    let title: String
    let detail: String
    let systemImage: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        CommandRow(title: title, detail: detail, systemImage: systemImage, tint: tint, action: action)
    }
}

struct InlineNotice: View {
    let title: String
    let detail: String
    var tint: Color = WikiTheme.blue

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Kicker(text: title)
            Text(detail)
                .font(.callout)
                .foregroundStyle(WikiTheme.muted)
                .lineSpacing(3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 12)
        .overlay(alignment: .top) {
            Rectangle().fill(tint.opacity(0.65)).frame(height: 2)
        }
    }
}

struct ModeTileButton: View {
    let title: String
    let detail: String
    let icon: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        ModeRow(title: title, detail: detail, systemImage: icon, tint: tint, action: action)
    }
}

struct AppleSignInPrompt: View {
    @EnvironmentObject private var session: SessionStore
    let api: WikiQuestAPIClient
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                BrandMarkView(variant: .glyph, size: 40, animated: false)
                InlineNotice(title: "APPLE ID", detail: detail, tint: WikiTheme.ink)
            }
            SignInWithAppleButton(.signIn) { request in
                session.prepareAppleRequest(request)
            } onCompletion: { result in
                session.handleAppleCompletion(result, api: api)
            }
            .signInWithAppleButtonStyle(.black)
            .frame(height: 48)
            .clipShape(RoundedRectangle(cornerRadius: WikiTheme.controlRadius, style: .continuous))
            .disabled(session.isSigningIn)
            .accessibilityIdentifier("ContinueWithApple")
        }
        .padding(.top, 4)
    }
}

struct ResultBanner: View {
    let title: String
    let detail: String
    var score: Int?
    var tint: Color
    var systemImage: String
    @EnvironmentObject private var motion: MotionSettings

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            ResultStamp(systemImage: systemImage, tint: tint, value: score ?? 0)
            VStack(alignment: .leading, spacing: 3) {
                Kicker(text: title)
                Text(detail)
                    .font(.headline)
                    .foregroundStyle(WikiTheme.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)
            }
            Spacer(minLength: 8)
            if let score {
                TickerNumberText(value: score, suffix: " XP", font: .system(.title3, design: .monospaced).weight(.black))
                    .foregroundStyle(tint)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 14)
        .overlay(alignment: .top) {
            Rectangle().fill(tint).frame(height: 3)
        }
        .transition(.scale(scale: motion.reduceMotion ? 1 : 0.98).combined(with: .opacity))
        .resultPop(trigger: "\(title)-\(detail)-\(score ?? -1)", tint: tint)
    }
}

struct QuestDeckItem: Identifiable, Equatable {
    let id: String
    let title: String
    let detail: String
    let media: WikiMedia?
    let tintName: String

    init(id: String, title: String, detail: String, media: WikiMedia? = nil, tintName: String = "blue") {
        self.id = id
        self.title = title
        self.detail = detail
        self.media = media
        self.tintName = tintName
    }

    var tint: Color {
        switch tintName {
        case "amber":
            return WikiTheme.amber
        case "green":
            return WikiTheme.green
        case "red":
            return WikiTheme.red
        case "violet":
            return WikiTheme.violet
        case "ink":
            return WikiTheme.ink
        default:
            return WikiTheme.blue
        }
    }
}

struct ArticleHeroImage: View {
    let media: WikiMedia?
    let title: String
    var visualState: ArticleVisualState = .revealed
    var height: CGFloat = 220
    var tint: Color = WikiTheme.blue
    @EnvironmentObject private var motion: MotionSettings

    var body: some View {
        ZStack {
            imageLayer
                .frame(maxWidth: .infinity)
                .frame(height: height)
                .clipped()
                .blur(radius: blurRadius)
                .scaleEffect(visualState == .locked && !motion.reduceMotion ? 1.035 : 1)

            LinearGradient(
                colors: [.black.opacity(0.50), .clear, .black.opacity(0.56)],
                startPoint: .top,
                endPoint: .bottom
            )

            if visualState == .locked {
                lockedOverlay
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .background(WikiTheme.ink)
        .clipShape(RoundedRectangle(cornerRadius: WikiTheme.controlRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: WikiTheme.controlRadius, style: .continuous)
                .stroke(tint.opacity(0.60), lineWidth: 1)
        }
        .animation(WikiMotion.active(WikiMotion.panel, reduceMotion: motion.reduceMotion), value: visualState)
        .revealSweep(trigger: visualState, tint: tint, enabled: visualState != .locked)
        .accessibilityLabel(title)
    }

    @ViewBuilder
    private var imageLayer: some View {
        if let url = media?.bestURL {
            AsyncImage(url: url, transaction: Transaction(animation: WikiMotion.panel)) { phase in
                switch phase {
                case .empty:
                    fallback
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure:
                    fallback
                @unknown default:
                    fallback
                }
            }
        } else {
            fallback
        }
    }

    private var fallback: some View {
        ZStack {
            WikiTheme.ink
            GridPattern()
                .stroke(tint.opacity(0.22), lineWidth: 1)
            VStack(spacing: 10) {
                BrandMarkView(variant: .glyph, size: 46, animated: false)
                    .opacity(0.85)
                Text(title)
                    .font(.caption.weight(.bold).monospaced())
                    .foregroundStyle(WikiTheme.surfaceStrong.opacity(0.82))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 18)
            }
        }
    }

    private var lockedOverlay: some View {
        VStack(spacing: 8) {
            Image(systemName: "eye.slash.fill")
                .font(.title2.weight(.black))
            Text("IMAGE LOCKED")
                .font(.caption.weight(.black).monospaced())
            Text("Reveal the photo clue.")
                .font(.caption.weight(.semibold))
                .opacity(0.82)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(.black.opacity(0.54))
        .clipShape(RoundedRectangle(cornerRadius: WikiTheme.radius, style: .continuous))
    }

    private var blurRadius: CGFloat {
        switch visualState {
        case .locked:
            return 13
        case .clue:
            return 4
        case .revealed:
            return 0
        }
    }
}

struct PhotoClueCard: View {
    let kicker: String
    let title: String
    let detail: String
    let media: WikiMedia?
    var visualState: ArticleVisualState = .revealed
    var tint: Color = WikiTheme.blue

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            ArticleHeroImage(media: media, title: title, visualState: visualState, height: 248, tint: tint)
            VStack(alignment: .leading, spacing: 5) {
                Text(kicker.uppercased())
                    .font(.caption.weight(.black).monospaced())
                    .foregroundStyle(.white.opacity(0.76))
                Text(title)
                    .font(.system(.title2, design: .serif).weight(.black))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.78)
                Text(detail)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.84))
                    .lineLimit(2)
            }
            .padding(14)
        }
        .overlay(alignment: .topLeading) {
            Rectangle()
                .fill(tint)
                .frame(width: 54, height: 4)
                .padding(12)
        }
    }
}

struct MediaCreditRow: View {
    let media: WikiMedia?

    var body: some View {
        if let media {
            HStack(spacing: 8) {
                Image(systemName: "camera.aperture")
                    .font(.caption.weight(.bold))
                if let sourceURL = media.sourceURL {
                    Link(media.credit ?? "Wikipedia", destination: sourceURL)
                } else {
                    Text(media.credit ?? "Wikipedia")
                }
                Text("/")
                    .foregroundStyle(WikiTheme.subtle)
                Text(media.license)
                Spacer(minLength: 0)
            }
            .font(.caption2.weight(.semibold))
            .foregroundStyle(WikiTheme.subtle)
            .lineLimit(1)
            .minimumScaleFactor(0.78)
            .accessibilityElement(children: .combine)
        }
    }
}

struct QuestDeckCard: View {
    let title: String
    let detail: String
    let media: WikiMedia?
    let primaryMetric: WikiMetric
    var tint: Color = WikiTheme.blue
    let action: () -> Void
    @State private var tapToken = 0

    var body: some View {
        Button(action: {
            Haptics.light()
            tapToken &+= 1
            action()
        }) {
            ZStack(alignment: .bottomLeading) {
                ArticleHeroImage(media: media, title: title, visualState: .revealed, height: 322, tint: tint)

                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("TODAY'S DECK")
                                .font(.caption.weight(.black).monospaced())
                                .foregroundStyle(.white.opacity(0.76))
                            Text("Wikipedia run")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.82))
                        }
                        Spacer(minLength: 12)
                        metricBadge
                    }

                    Spacer(minLength: 36)

                    VStack(alignment: .leading, spacing: 8) {
                        Text(title)
                            .font(.system(.largeTitle, design: .serif).weight(.black))
                            .foregroundStyle(.white)
                            .lineLimit(2)
                            .minimumScaleFactor(0.68)
                        Text(detail)
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.84))
                            .lineLimit(2)

                        HStack(spacing: 10) {
                            Label("Start quest", systemImage: "play.fill")
                                .font(.callout.weight(.black))
                                .foregroundStyle(.white)
                            Rectangle()
                                .fill(.white.opacity(0.30))
                                .frame(height: 1)
                            Image(systemName: "arrow.right")
                                .font(.callout.weight(.black))
                                .foregroundStyle(.white)
                        }
                        .padding(.top, 5)
                    }
                }
                .padding(16)
            }
            .overlay(alignment: .topLeading) {
                Rectangle()
                    .fill(tint)
                    .frame(width: 64, height: 4)
                    .padding(14)
            }
        }
        .buttonStyle(ArcadePressStyle())
        .motionTick(trigger: tapToken, tint: tint)
    }

    private var metricBadge: some View {
        VStack(alignment: .trailing, spacing: 3) {
            Text(primaryMetric.label.uppercased())
                .font(.caption2.weight(.black).monospaced())
                .foregroundStyle(.white.opacity(0.66))
            if let value = primaryMetric.value {
                TickerNumberText(value: value, font: .system(.callout, design: .monospaced).weight(.black))
                    .foregroundStyle(.white)
            } else {
                Text(primaryMetric.text ?? "-")
                    .font(.system(.callout, design: .monospaced).weight(.black))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.black.opacity(0.54))
        .clipShape(RoundedRectangle(cornerRadius: WikiTheme.radius, style: .continuous))
    }
}

struct VisualBreadcrumb: View {
    let path: [String]
    var tint: Color = WikiTheme.blue

    var body: some View {
        FlatSection(title: "Trail") {
            if path.isEmpty {
                Text("No clicks yet.")
                    .font(.callout)
                    .foregroundStyle(WikiTheme.muted)
                    .padding(.vertical, 12)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(path.enumerated()), id: \.offset) { index, title in
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(index == path.count - 1 ? tint : WikiTheme.hairline)
                                    .frame(width: 8, height: 8)
                                Text(title)
                                    .font(.caption.weight(.bold).monospaced())
                                    .foregroundStyle(index == path.count - 1 ? WikiTheme.ink : WikiTheme.blue)
                                    .lineLimit(1)
                            }
                            .padding(.vertical, 8)
                            if index < path.count - 1 {
                                Rectangle()
                                    .fill(WikiTheme.hairline)
                                    .frame(width: 18, height: 1)
                            }
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
        }
    }
}

struct DiscoveryPhotoRail: View {
    let items: [QuestDeckItem]

    var body: some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Kicker(text: "Discovered")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(items) { item in
                            VStack(alignment: .leading, spacing: 7) {
                                ArticleHeroImage(media: item.media, title: item.title, height: 112, tint: item.tint)
                                Text(item.title)
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(WikiTheme.ink)
                                    .lineLimit(2)
                                Text(item.detail)
                                    .font(.caption2)
                                    .foregroundStyle(WikiTheme.muted)
                                    .lineLimit(1)
                            }
                            .frame(width: 156, alignment: .leading)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }
}

struct ArticlePreview: View {
    let article: WikiArticle
    var tint: Color = WikiTheme.blue

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ArticleHeroImage(media: article.media, title: article.title, height: 202, tint: tint)
            Kicker(text: "Article")
            Text(article.title)
                .font(.title2.weight(.bold))
                .foregroundStyle(WikiTheme.ink)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            if let description = article.description, !description.isEmpty {
                Text(description)
                    .font(.callout)
                    .foregroundStyle(WikiTheme.muted)
                    .lineLimit(2)
            }
            if let extract = article.extract, !extract.isEmpty {
                Text(extract)
                    .font(.body)
                    .lineLimit(6)
                .lineSpacing(3)
                .foregroundStyle(WikiTheme.ink)
            }
            MediaCreditRow(media: article.media)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 12)
        .overlay(alignment: .top) {
            Rectangle().fill(tint).frame(height: 2)
        }
    }
}

struct LinkTrailStrip: View {
    let path: [String]

    var body: some View {
        FlatSection(title: "Trail") {
            if path.isEmpty {
                Text("No clicks yet.")
                    .font(.callout)
                    .foregroundStyle(WikiTheme.muted)
                    .padding(.vertical, 12)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 7) {
                        ForEach(Array(path.enumerated()), id: \.offset) { index, title in
                            Text(title)
                                .font(.caption.weight(.semibold).monospaced())
                                .foregroundStyle(index == path.count - 1 ? WikiTheme.ink : WikiTheme.blue)
                                .lineLimit(1)
                                .padding(.vertical, 8)
                            if index < path.count - 1 {
                                Image(systemName: "chevron.right")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(WikiTheme.subtle)
                            }
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
        }
    }
}

struct MapCommandOverlay: View {
    let title: String
    let detail: String
    var tint: Color = WikiTheme.blue

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Kicker(text: title)
                .foregroundStyle(Color.white.opacity(0.72))
            Text(detail)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(2)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(WikiTheme.mapOverlay)
        .overlay(alignment: .leading) {
            Rectangle().fill(tint).frame(width: 3)
        }
        .clipShape(RoundedRectangle(cornerRadius: WikiTheme.controlRadius, style: .continuous))
    }
}

enum Haptics {
    static func light() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func error() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }
}

extension View {
    @ViewBuilder
    func wikiBounce<Value: Equatable>(enabled: Bool, value: Value) -> some View {
        if enabled {
            self.symbolEffect(.bounce, value: value)
        } else {
            self
        }
    }
}
