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
