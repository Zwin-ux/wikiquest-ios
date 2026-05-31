import Foundation
import SwiftUI
import WidgetKit

struct WikiQuestWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: WikiQuestWidgetSnapshot
}

struct WikiQuestWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> WikiQuestWidgetEntry {
        WikiQuestWidgetEntry(date: Date(), snapshot: .signedOut)
    }

    func getSnapshot(in context: Context, completion: @escaping (WikiQuestWidgetEntry) -> Void) {
        completion(WikiQuestWidgetEntry(date: Date(), snapshot: WikiQuestSnapshotStore.readSnapshot()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WikiQuestWidgetEntry>) -> Void) {
        let entry = WikiQuestWidgetEntry(date: Date(), snapshot: WikiQuestSnapshotStore.readSnapshot())
        let refresh = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date()
        completion(Timeline(entries: [entry], policy: .after(refresh)))
    }
}

struct WikiQuestDailyWidgetView: View {
    let entry: WikiQuestWidgetEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        Link(destination: AppRoute.daily.url) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 7) {
                    WidgetBrandMark(size: 24, glyph: true)
                    Text("WIKIQUEST")
                        .font(.caption2.weight(.bold).monospaced())
                        .foregroundStyle(WidgetPalette.muted)
                }
                Text(entry.snapshot.dailyTitle)
                    .font(family == .systemSmall ? .headline : .title3.weight(.bold))
                    .foregroundStyle(WidgetPalette.ink)
                    .lineLimit(2)
                Spacer(minLength: 4)
                HStack(spacing: 10) {
                    Metric(label: "STREAK", value: "\(entry.snapshot.streak)")
                    Metric(label: "XP", value: "\(entry.snapshot.xp)")
                    if family != .systemSmall {
                        Metric(label: "MEMBER", value: entry.snapshot.isMember ? "ON" : "OFF")
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .containerBackground(WidgetPalette.paper, for: .widget)
        }
    }
}

private enum WidgetPalette {
    static let paper = Color(red: 0.949, green: 0.918, blue: 0.847)
    static let paperStrong = Color(red: 1.0, green: 0.981, blue: 0.941)
    static let ink = Color(red: 0.094, green: 0.106, blue: 0.122)
    static let muted = Color(red: 0.39, green: 0.36, blue: 0.29)
    static let rule = Color(red: 0.67, green: 0.61, blue: 0.48)
    static let blue = Color(red: 0.14, green: 0.36, blue: 0.66)
    static let green = Color(red: 0.12, green: 0.44, blue: 0.28)
    static let amber = Color(red: 0.78, green: 0.47, blue: 0.08)
}

private struct WidgetBrandMark: View {
    var size: CGFloat
    var glyph = false

    var body: some View {
        Image(glyph ? "BrandGlyph" : "BrandMark")
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

private struct Metric: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2.weight(.bold).monospaced())
                .foregroundStyle(WidgetPalette.muted)
            Text(value)
                .font(.caption.weight(.black).monospacedDigit())
                .foregroundStyle(WidgetPalette.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct WikiQuestDailyWidget: Widget {
    let kind = "WikiQuestDailyWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WikiQuestWidgetProvider()) { entry in
            WikiQuestDailyWidgetView(entry: entry)
        }
        .configurationDisplayName("Daily Mystery")
        .description("Open today's WikiQuest and track streak/XP.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

#if canImport(ActivityKit)
import ActivityKit

struct LinkRaceLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LinkRaceActivityAttributes.self) { context in
            LinkRaceActivityView(state: context.state)
                .activityBackgroundTint(WidgetPalette.paper)
                .activitySystemActionForegroundColor(WidgetPalette.blue)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 6) {
                        WidgetBrandMark(size: 22, glyph: true)
                        Text("\(context.state.clicks) clicks")
                            .font(.caption.weight(.bold).monospacedDigit())
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    LinkRaceTimer(state: context.state)
                        .font(.caption.weight(.bold).monospacedDigit())
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 5) {
                        HStack(spacing: 6) {
                            Text(context.state.currentTitle)
                                .lineLimit(1)
                            Image(systemName: "arrow.right")
                                .font(.caption2.weight(.black))
                                .foregroundStyle(WidgetPalette.blue)
                            Text(context.state.targetTitle)
                                .lineLimit(1)
                        }
                        .font(.caption.weight(.semibold))
                        LinkRacePathTail(path: context.state.pathTail)
                    }
                }
            } compactLeading: {
                Text("\(context.state.clicks)")
                    .font(.caption2.weight(.black).monospacedDigit())
            } compactTrailing: {
                LinkRaceTimer(state: context.state)
                    .font(.caption2.weight(.black).monospacedDigit())
            } minimal: {
                Image(systemName: context.state.completed ? "checkmark" : "link")
            }
        }
    }
}

private struct LinkRaceActivityView: View {
    let state: LinkRaceActivityAttributes.ContentState

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            WidgetBrandMark(size: 36, glyph: false)
            VStack(alignment: .leading, spacing: 6) {
                Text(state.completed ? "LINK RACE COMPLETE" : "LINK RACE")
                    .font(.caption2.weight(.bold).monospaced())
                    .foregroundStyle(WidgetPalette.muted)
                HStack(spacing: 6) {
                    Text(state.currentTitle)
                        .font(.headline)
                        .lineLimit(1)
                    Image(systemName: "arrow.right")
                        .font(.caption.weight(.black))
                        .foregroundStyle(WidgetPalette.blue)
                    Text(state.targetTitle)
                        .font(.headline)
                        .lineLimit(1)
                }
                HStack(spacing: 12) {
                    Text("\(state.clicks) clicks")
                    LinkRaceTimer(state: state)
                    Spacer(minLength: 4)
                    LinkRacePathTail(path: state.pathTail)
                }
                .font(.caption.weight(.bold).monospacedDigit())
                .foregroundStyle(WidgetPalette.ink)
            }
        }
        .padding()
    }
}

private struct LinkRaceTimer: View {
    let state: LinkRaceActivityAttributes.ContentState

    var body: some View {
        if state.completed, let endedAt = state.endedAt {
            Text(elapsedText(start: state.startedAt, end: endedAt))
        } else {
            Text(state.startedAt, style: .timer)
        }
    }

    private func elapsedText(start: Date, end: Date) -> String {
        let seconds = max(0, Int(end.timeIntervalSince(start)))
        if seconds < 60 {
            return "\(seconds)s"
        }
        return "\(seconds / 60):\(String(format: "%02d", seconds % 60))"
    }
}

private struct LinkRacePathTail: View {
    let path: [String]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(path.enumerated()), id: \.offset) { index, title in
                Text(shortTitle(title))
                    .font(.caption2.weight(.semibold).monospaced())
                    .lineLimit(1)
                    .foregroundStyle(index == path.count - 1 ? WidgetPalette.ink : WidgetPalette.blue)
                if index < path.count - 1 {
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.black))
                        .foregroundStyle(WidgetPalette.muted)
                }
            }
        }
    }

    private func shortTitle(_ title: String) -> String {
        title.count > 18 ? "\(title.prefix(16))..." : title
    }
}

struct NearbyRevealLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: NearbyRevealActivityAttributes.self) { context in
            HStack(alignment: .top, spacing: 10) {
                WidgetBrandMark(size: 36, glyph: true)
                VStack(alignment: .leading, spacing: 6) {
                    Text("NEARBY REVEAL")
                        .font(.caption2.weight(.bold).monospaced())
                        .foregroundStyle(WidgetPalette.muted)
                    Text(context.state.articleTitle)
                        .font(.headline)
                        .lineLimit(1)
                    Text("\(context.state.distanceText) / \(context.state.score) XP")
                        .font(.caption.weight(.bold).monospacedDigit())
                        .foregroundStyle(WidgetPalette.ink)
                }
            }
            .padding()
            .activityBackgroundTint(WidgetPalette.paper)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    WidgetBrandMark(size: 24, glyph: true)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("\(context.state.score) XP")
                        .font(.caption.weight(.bold).monospacedDigit())
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(context.state.articleTitle)
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                        Text(context.state.distanceText)
                            .font(.caption2.weight(.bold).monospacedDigit())
                            .foregroundStyle(WidgetPalette.green)
                    }
                }
            } compactLeading: {
                Image(systemName: "mappin")
            } compactTrailing: {
                Text("\(context.state.score)XP")
                    .font(.caption2.weight(.black).monospacedDigit())
            } minimal: {
                Image(systemName: "mappin")
            }
        }
    }
}
#endif

@main
struct WikiQuestWidgets: WidgetBundle {
    var body: some Widget {
        WikiQuestDailyWidget()
        #if canImport(ActivityKit)
        LinkRaceLiveActivityWidget()
        NearbyRevealLiveActivityWidget()
        #endif
    }
}
