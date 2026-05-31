import SwiftUI
import UIKit

@MainActor
final class MotionSettings: ObservableObject {
    @Published var reduceMotion = UIAccessibility.isReduceMotionEnabled

    private var observer: NSObjectProtocol?

    init() {
        observer = NotificationCenter.default.addObserver(
            forName: UIAccessibility.reduceMotionStatusDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.reduceMotion = UIAccessibility.isReduceMotionEnabled
            }
        }
    }

    deinit {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}

enum WikiMotion {
    static let quick = Animation.easeOut(duration: 0.16)
    static let page = Animation.easeOut(duration: 0.22)
    static let panel = Animation.spring(response: 0.32, dampingFraction: 0.86)
    static let ticker = Animation.interpolatingSpring(stiffness: 220, damping: 28)
    static let result = Animation.spring(response: 0.38, dampingFraction: 0.72)
    static let dock = Animation.spring(response: 0.24, dampingFraction: 0.82)
    static let tick = Animation.spring(response: 0.18, dampingFraction: 0.70)
    static let reveal = Animation.spring(response: 0.42, dampingFraction: 0.82)
    static let lineDraw = Animation.easeOut(duration: 0.34)

    static func active(_ animation: Animation, reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : animation
    }
}

struct TickerNumberText: View {
    let value: Int
    var suffix = ""
    var font: Font = .system(.title3, design: .monospaced).weight(.bold)
    @EnvironmentObject private var motion: MotionSettings

    var body: some View {
        Text("\(value)\(suffix)")
            .font(font)
            .contentTransition(.numericText(value: Double(value)))
            .animation(WikiMotion.active(WikiMotion.ticker, reduceMotion: motion.reduceMotion), value: value)
    }
}

struct MotionTick<Value: Equatable>: ViewModifier {
    let trigger: Value
    var tint: Color = WikiTheme.blue
    var enabled = true
    @EnvironmentObject private var motion: MotionSettings
    @State private var isLit = false

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(tint)
                    .frame(width: 3)
                    .opacity(isLit && enabled && !motion.reduceMotion ? 1 : 0)
            }
            .overlay {
                if enabled && !motion.reduceMotion {
                    RoundedRectangle(cornerRadius: WikiTheme.radius, style: .continuous)
                        .stroke(tint.opacity(isLit ? 0.72 : 0), lineWidth: 1)
                }
            }
            .onChange(of: trigger) { _, _ in
                pulse()
            }
    }

    private func pulse() {
        guard enabled, !motion.reduceMotion else { return }
        withAnimation(WikiMotion.tick) {
            isLit = true
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 220_000_000)
            withAnimation(WikiMotion.quick) {
                isLit = false
            }
        }
    }
}

struct RevealSweep<Value: Equatable>: ViewModifier {
    let trigger: Value
    var tint: Color = WikiTheme.blue
    var enabled = true
    @EnvironmentObject private var motion: MotionSettings
    @State private var offset: CGFloat = -1.2

    func body(content: Content) -> some View {
        content
            .overlay {
                if enabled && !motion.reduceMotion {
                    GeometryReader { proxy in
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [.clear, tint.opacity(0.52), .clear],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(42, proxy.size.width * 0.32))
                            .offset(x: offset * proxy.size.width)
                            .allowsHitTesting(false)
                    }
                    .clipped()
                    .blendMode(.screen)
                }
            }
            .onAppear { sweep() }
            .onChange(of: trigger) { _, _ in
                sweep()
            }
    }

    private func sweep() {
        guard enabled, !motion.reduceMotion else { return }
        offset = -0.42
        withAnimation(WikiMotion.lineDraw) {
            offset = 1.12
        }
    }
}

struct ResultPop<Value: Equatable>: ViewModifier {
    let trigger: Value
    var tint: Color = WikiTheme.green
    @EnvironmentObject private var motion: MotionSettings
    @State private var scale: CGFloat = 1

    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(tint)
                    .frame(height: 3)
                    .scaleEffect(x: scale > 1 ? 1 : 0.52, anchor: .leading)
                    .opacity(motion.reduceMotion ? 0 : 1)
            }
            .onAppear { pop() }
            .onChange(of: trigger) { _, _ in
                pop()
            }
    }

    private func pop() {
        guard !motion.reduceMotion else { return }
        withAnimation(WikiMotion.result) {
            scale = 1.012
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 180_000_000)
            withAnimation(WikiMotion.quick) {
                scale = 1
            }
        }
    }
}

struct PinPulse<Value: Equatable>: ViewModifier {
    let trigger: Value
    var tint: Color = WikiTheme.blue
    @EnvironmentObject private var motion: MotionSettings
    @State private var pulse = false

    func body(content: Content) -> some View {
        content
            .overlay {
                Circle()
                    .stroke(tint.opacity(pulse ? 0 : 0.72), lineWidth: 2)
                    .scaleEffect(pulse ? 1.75 : 0.72)
                    .opacity(motion.reduceMotion ? 0 : 1)
            }
            .onAppear { ring() }
            .onChange(of: trigger) { _, _ in
                ring()
            }
    }

    private func ring() {
        guard !motion.reduceMotion else { return }
        pulse = false
        withAnimation(.easeOut(duration: 0.48)) {
            pulse = true
        }
    }
}

struct PanelReveal<Content: View>: View {
    let delay: Double
    @ViewBuilder var content: Content
    @EnvironmentObject private var motion: MotionSettings
    @State private var shown = false

    var body: some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: motion.reduceMotion ? 0 : (shown ? 0 : 8))
            .onAppear {
                withAnimation(motion.reduceMotion ? nil : WikiMotion.panel.delay(delay)) {
                    shown = true
                }
            }
    }
}

extension View {
    func motionTick<Value: Equatable>(trigger: Value, tint: Color = WikiTheme.blue, enabled: Bool = true) -> some View {
        modifier(MotionTick(trigger: trigger, tint: tint, enabled: enabled))
    }

    func revealSweep<Value: Equatable>(trigger: Value, tint: Color = WikiTheme.blue, enabled: Bool = true) -> some View {
        modifier(RevealSweep(trigger: trigger, tint: tint, enabled: enabled))
    }

    func resultPop<Value: Equatable>(trigger: Value, tint: Color = WikiTheme.green) -> some View {
        modifier(ResultPop(trigger: trigger, tint: tint))
    }

    func pinPulse<Value: Equatable>(trigger: Value, tint: Color = WikiTheme.blue) -> some View {
        modifier(PinPulse(trigger: trigger, tint: tint))
    }
}
