import Combine
import MapKit
import SwiftUI

struct NearbyView: View {
    let api: WikiQuestAPIClient
    @EnvironmentObject private var session: SessionStore
    @EnvironmentObject private var motion: MotionSettings
    @EnvironmentObject private var gameCenter: GameCenterStore
    @EnvironmentObject private var liveActivities: LiveActivityStore
    @StateObject private var location = LocationStore()
    @StateObject private var viewModel: NearbyViewModel
    @State private var position = MapCameraPosition.region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
        )
    )

    private let cities = [
        KnownCity(label: "San Francisco", coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)),
        KnownCity(label: "New York", coordinate: CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060)),
        KnownCity(label: "London", coordinate: CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278))
    ]

    init(api: WikiQuestAPIClient) {
        self.api = api
        _viewModel = StateObject(wrappedValue: NearbyViewModel(api: api))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                MapReader { proxy in
                    Map(position: $position) {
                        if let guess = viewModel.guess {
                            Annotation("Guess", coordinate: guess) {
                                Image(systemName: "mappin.circle.fill")
                                    .font(.system(size: 32, weight: .bold))
                                    .foregroundStyle(WikiTheme.blue)
                                    .shadow(color: .black.opacity(0.18), radius: 4, y: 2)
                                    .wikiBounce(enabled: !motion.reduceMotion, value: guessPulse)
                                    .pinPulse(trigger: guessPulse, tint: WikiTheme.blue)
                            }
                        }
                        if viewModel.phase == .revealed {
                            ForEach(viewModel.articles) { article in
                                Annotation(article.title, coordinate: article.coordinate) {
                                    Image(systemName: article.id == viewModel.selected?.id ? "scope" : "smallcircle.filled.circle")
                                        .font(.system(size: article.id == viewModel.selected?.id ? 28 : 15, weight: .bold))
                                        .foregroundStyle(article.id == viewModel.selected?.id ? WikiTheme.red : WikiTheme.muted)
                                        .wikiBounce(enabled: !motion.reduceMotion, value: viewModel.phase == .revealed)
                                        .pinPulse(trigger: viewModel.phase == .revealed, tint: article.id == viewModel.selected?.id ? WikiTheme.red : WikiTheme.muted)
                                }
                            }
                        }
                    }
                    .mapStyle(.standard(elevation: .flat))
                    .gesture(
                        SpatialTapGesture()
                            .onEnded { value in
                                if let coordinate = proxy.convert(value.location, from: .local) {
                                    Haptics.light()
                                    viewModel.placeGuess(coordinate)
                                }
                            }
                    )
                }
                .frame(height: WikiTheme.mapHeight)
                .overlay(alignment: .topLeading) {
                    MapStatusBadge(phase: viewModel.phase)
                        .padding(12)
                }
                .overlay(alignment: .topTrailing) {
                    MapHUDCluster(
                        articleCount: viewModel.articles.count,
                        score: viewModel.localScore ?? viewModel.savedXP ?? 0,
                        distance: viewModel.distanceMeters
                    )
                    .padding(12)
                }
                .overlay(alignment: .bottomLeading) {
                    MapCommandOverlay(title: mapOverlayTitle, detail: mapOverlayDetail, tint: phaseTint)
                        .padding(12)
                }
                .overlay(alignment: .bottom) {
                    Rectangle().fill(WikiTheme.hairline).frame(height: 1)
                }

                ScrollView {
                    MapControlSheet(tint: phaseTint) {
                        MapQuestStatus(title: viewModel.targetTitle, detail: phaseDetail, phase: viewModel.phase, centerLabel: viewModel.centerLabel)

                        if location.authorizationDenied || viewModel.phase == .denied {
                            InlineNotice(title: "LOCATION", detail: "Location is denied. You can still play from a sample city.", tint: WikiTheme.amber)
                        }

                        if let error = viewModel.error {
                            InlineNotice(title: "ERROR", detail: error, tint: WikiTheme.red)
                        }

                        if viewModel.phase == .loading || viewModel.phase == .locating {
                            WikiLoadingGlyph(title: "LOADING", detail: location.statusText, tint: WikiTheme.blue)
                        }

                        if viewModel.phase == .empty {
                            HStack(alignment: .center, spacing: 12) {
                                BrandMarkView(variant: .glyph, size: 34, animated: false)
                                InlineNotice(title: "EMPTY", detail: "No georeferenced Wikipedia articles found here. Try another city.", tint: WikiTheme.muted)
                            }
                        }

                        if viewModel.phase == .revealed, let article = viewModel.selected {
                            NearbyRevealPanel(
                                article: article,
                                distanceText: viewModel.distanceMeters.map(NearbyScoring.format) ?? "Unknown",
                                score: viewModel.savedXP ?? viewModel.localScore ?? 0
                            )
                        }

                        MapActionRow(
                            tint: phaseTint,
                            revealTitle: viewModel.phase == .revealed ? "Next" : "Reveal",
                            revealIcon: viewModel.phase == .revealed ? "arrow.clockwise" : "mappin.and.ellipse",
                            revealDisabled: revealDisabled,
                            revealPlaysHaptic: true,
                            reveal: {
                                Task {
                                    if viewModel.phase == .revealed {
                                        await viewModel.load(center: viewModel.region.center, label: viewModel.centerLabel, denied: location.authorizationDenied)
                                    } else {
                                        await viewModel.reveal(session: session)
                                    }
                                }
                            },
                            locate: {
                                location.request()
                            }
                        )

                        if viewModel.phase == .revealed, let article = viewModel.selected {
                            ShareLink(item: nearbyShareText(article: article)) {
                                Label("Share result", systemImage: "square.and.arrow.up")
                                    .font(.callout.weight(.semibold))
                                    .foregroundStyle(WikiTheme.blue)
                            }
                            .buttonStyle(ArcadePressStyle())
                        }

                        CityRail(cities: cities) { city in
                            Task { await loadCity(city) }
                        }
                    }
                    .padding(WikiTheme.screenPadding)
                }
            }
            .background(WikiPaperBackground())
            .toolbar(.hidden, for: .navigationBar)
            .task {
                location.request()
                if location.coordinate == nil {
                    await viewModel.load(center: cities[0].coordinate, label: cities[0].label, denied: location.authorizationDenied)
                }
            }
            .onReceive(location.$coordinate.compactMap { $0 }) { coordinate in
                Task {
                    await viewModel.load(center: coordinate, denied: location.authorizationDenied)
                }
            }
            .onReceive(viewModel.$region) { region in
                position = .region(region)
            }
            .onChange(of: viewModel.phase) { _, phase in
                guard
                    phase == .revealed,
                    let article = viewModel.selected,
                    let distance = viewModel.distanceMeters
                else {
                    return
                }
                let score = viewModel.savedXP ?? viewModel.localScore ?? 0
                gameCenter.reportNearbyResult(distanceMeters: distance, score: score)
                liveActivities.showNearbyReveal(
                    articleTitle: article.title,
                    distanceText: NearbyScoring.format(distance),
                    score: score
                )
            }
        }
    }

    private var guessPulse: String {
        guard let guess = viewModel.guess else { return "empty" }
        return "\(guess.latitude)-\(guess.longitude)"
    }

    private var phaseTint: Color {
        switch viewModel.phase {
        case .revealed:
            return WikiTheme.red
        case .guess, .denied:
            return WikiTheme.blue
        case .empty:
            return WikiTheme.muted
        default:
            return WikiTheme.ink
        }
    }

    private var mapOverlayTitle: String {
        switch viewModel.phase {
        case .locating:
            return "Locating"
        case .loading:
            return "Loading map"
        case .guess, .denied:
            return "Place pin"
        case .revealed:
            return "Distance"
        case .empty:
            return "No articles"
        }
    }

    private var mapOverlayDetail: String {
        if viewModel.phase == .revealed, let distance = viewModel.distanceMeters {
            return NearbyScoring.format(distance)
        }
        return phaseDetail
    }

    private var phaseDetail: String {
        switch viewModel.phase {
        case .locating:
            return "Finding your map center."
        case .loading:
            return "Loading nearby Wikipedia coordinates."
        case .guess, .denied:
            return "Tap the map where you think the hidden article belongs."
        case .revealed:
            if let distance = viewModel.distanceMeters {
                return "Your pin landed \(NearbyScoring.format(distance)) from the target."
            }
            return "Target revealed."
        case .empty:
            return "Try another map center."
        }
    }

    private var revealDisabled: Bool {
        if viewModel.phase == .revealed { return false }
        return viewModel.guess == nil || viewModel.selected == nil
    }

    private func loadCity(_ city: KnownCity) async {
        await viewModel.load(center: city.coordinate, label: city.label, denied: false)
    }

    private func nearbyShareText(article: NearbyArticle) -> String {
        let distance = viewModel.distanceMeters.map(NearbyScoring.format) ?? "unknown distance"
        let score = viewModel.savedXP ?? viewModel.localScore ?? 0
        return "Found \(article.title) in WikiQuest Nearby: \(distance), \(score) XP."
    }
}

private struct KnownCity: Identifiable {
    let id = UUID()
    let label: String
    let coordinate: CLLocationCoordinate2D
}

private struct MapControlSheet<Content: View>: View {
    let tint: Color
    @ViewBuilder var content: Content

    init(tint: Color, @ViewBuilder content: () -> Content) {
        self.tint = tint
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 10)
        .overlay(alignment: .top) {
            Rectangle().fill(tint).frame(height: 3)
        }
        .overlay(alignment: .bottom) {
            Rectangle().fill(WikiTheme.hairline).frame(height: 1)
        }
        .motionTick(trigger: "\(tint)", tint: tint)
    }
}

private struct MapStatusBadge: View {
    let phase: NearbyPhase

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: phase == .revealed ? "eye" : "mappin")
            Text(label)
                .font(.caption.weight(.bold).monospaced())
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .foregroundStyle(.white)
        .background(phase == .revealed ? WikiTheme.red : WikiTheme.ink)
        .clipShape(RoundedRectangle(cornerRadius: WikiTheme.radius, style: .continuous))
    }

    private var label: String {
        switch phase {
        case .locating:
            return "LOCATING"
        case .loading:
            return "LOADING"
        case .guess, .denied:
            return "PLACE PIN"
        case .revealed:
            return "REVEALED"
        case .empty:
            return "EMPTY"
        }
    }
}

private struct MapHUDCluster: View {
    let articleCount: Int
    let score: Int
    let distance: Double?

    var body: some View {
        VStack(alignment: .trailing, spacing: 7) {
            GameHUDPill(label: "Pages", value: "\(articleCount)", systemImage: "doc.text.magnifyingglass", tint: WikiTheme.blue)
            if let distance {
                GameHUDPill(label: "Distance", value: NearbyScoring.format(distance), systemImage: "ruler", tint: WikiTheme.violet)
            } else {
                GameHUDPill(label: "Score", value: "\(score)", systemImage: "star.fill", tint: WikiTheme.green)
            }
        }
    }
}

private struct MapQuestStatus: View {
    let title: String
    let detail: String
    let phase: NearbyPhase
    let centerLabel: String?

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image("ModeNearbyMark")
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: 48, height: 48)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Kicker(text: centerLabel ?? "Map")
                    Text(phaseLabel)
                        .font(.caption2.weight(.black).monospaced())
                        .foregroundStyle(phaseTint)
                }
                Text(title)
                    .font(.system(.title3, design: .serif).weight(.black))
                    .foregroundStyle(WikiTheme.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
                Text(detail)
                    .font(.callout)
                    .foregroundStyle(WikiTheme.muted)
                    .lineLimit(3)
                    .lineSpacing(3)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) {
            Rectangle().fill(WikiTheme.hairline).frame(height: 1)
        }
    }

    private var phaseLabel: String {
        switch phase {
        case .locating:
            return "LOCATING"
        case .loading:
            return "LOADING"
        case .guess, .denied:
            return "PLACE PIN"
        case .revealed:
            return "REVEALED"
        case .empty:
            return "EMPTY"
        }
    }

    private var phaseTint: Color {
        switch phase {
        case .revealed:
            return WikiTheme.red
        case .guess, .denied:
            return WikiTheme.blue
        case .empty:
            return WikiTheme.muted
        default:
            return WikiTheme.ink
        }
    }
}

private struct CityRail: View {
    let cities: [KnownCity]
    let choose: (KnownCity) -> Void
    @State private var selectedCityID: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Kicker(text: "Jump")
            HStack(spacing: 8) {
                ForEach(cities) { city in
                    Button {
                        Haptics.light()
                        selectedCityID = city.id
                        choose(city)
                    } label: {
                        Text(city.label)
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(WikiTheme.blue)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .overlay(RoundedRectangle(cornerRadius: WikiTheme.radius).stroke(WikiTheme.rule.opacity(0.75)))
                    .buttonStyle(ArcadePressStyle())
                    .motionTick(trigger: selectedCityID == city.id ? selectedCityID : nil, tint: WikiTheme.blue)
                }
            }
        }
    }
}

private struct MapActionRow: View {
    let tint: Color
    let revealTitle: String
    let revealIcon: String
    let revealDisabled: Bool
    let revealPlaysHaptic: Bool
    let reveal: () -> Void
    let locate: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            CommandButton(
                title: revealTitle,
                icon: revealIcon,
                tint: tint,
                isDisabled: revealDisabled,
                playsHaptic: revealPlaysHaptic,
                action: reveal
            )
            CommandButton(title: "Locate", icon: "location", tint: WikiTheme.ink, action: locate)
        }
        .padding(.top, 2)
    }
}

private struct NearbyRevealPanel: View {
    let article: NearbyArticle
    let distanceText: String
    let score: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            PhotoClueCard(
                kicker: "Target revealed",
                title: article.title,
                detail: article.description ?? distanceText,
                media: article.media,
                visualState: .revealed,
                tint: WikiTheme.red
            )
            MediaCreditRow(media: article.media)

            HStack(spacing: 10) {
                NearbyRevealMetric(label: "Distance", value: distanceText, tint: WikiTheme.violet)
                NearbyRevealMetric(label: "XP", value: "\(score)", tint: WikiTheme.green)
            }

            if let extract = article.extract {
                Text(extract)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(WikiTheme.muted)
                    .lineLimit(3)
                    .lineSpacing(3)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 12)
        .overlay(alignment: .top) {
            Rectangle().fill(WikiTheme.red).frame(height: 3)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .motionTick(trigger: "\(article.id)-\(distanceText)-\(score)", tint: WikiTheme.red)
    }
}

private struct NearbyRevealMetric: View {
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
                .minimumScaleFactor(0.68)
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 10)
        .overlay(alignment: .top) {
            Rectangle().fill(WikiTheme.hairline).frame(height: 1)
        }
    }
}
