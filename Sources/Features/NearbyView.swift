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
                            }
                        }
                        if viewModel.phase == .revealed {
                            ForEach(viewModel.articles) { article in
                                Annotation(article.title, coordinate: article.coordinate) {
                                    Image(systemName: article.id == viewModel.selected?.id ? "scope" : "smallcircle.filled.circle")
                                        .font(.system(size: article.id == viewModel.selected?.id ? 28 : 15, weight: .bold))
                                        .foregroundStyle(article.id == viewModel.selected?.id ? WikiTheme.red : WikiTheme.muted)
                                        .wikiBounce(enabled: !motion.reduceMotion, value: viewModel.phase == .revealed)
                                }
                            }
                        }
                    }
                    .mapStyle(.standard(elevation: .flat))
                    .gesture(
                        SpatialTapGesture()
                            .onEnded { value in
                                if let coordinate = proxy.convert(value.location, from: .local) {
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
                    VStack(alignment: .leading, spacing: 14) {
                        WikiOSWindowHeader(title: "Nearby")
                        MapQuestStatus(title: viewModel.targetTitle, detail: phaseDetail, phase: viewModel.phase, centerLabel: viewModel.centerLabel)

                        if location.authorizationDenied || viewModel.phase == .denied {
                            InlineNotice(title: "LOCATION", detail: "Location is denied. You can still play from a sample city.", tint: WikiTheme.amber)
                        }

                        if let error = viewModel.error {
                            InlineNotice(title: "ERROR", detail: error, tint: WikiTheme.red)
                        }

                        CityRail(cities: cities) { city in
                            Task { await loadCity(city) }
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
                            NearbyRevealPanel(article: article, score: viewModel.savedXP ?? viewModel.localScore ?? 0)
                            ShareLink(item: nearbyShareText(article: article)) {
                                Label("Share result", systemImage: "square.and.arrow.up")
                                    .font(.callout.weight(.semibold))
                                    .foregroundStyle(WikiTheme.blue)
                            }
                            .buttonStyle(ArcadePressStyle())
                        }

                        HStack(spacing: 10) {
                            CommandButton(
                                title: viewModel.phase == .revealed ? "Next" : "Reveal",
                                icon: viewModel.phase == .revealed ? "arrow.clockwise" : "mappin.and.ellipse",
                                tint: WikiTheme.blue,
                                isDisabled: revealDisabled,
                                playsHaptic: viewModel.phase == .revealed
                            ) {
                                Task {
                                    if viewModel.phase == .revealed {
                                        await viewModel.load(center: viewModel.region.center, label: viewModel.centerLabel, denied: location.authorizationDenied)
                                    } else {
                                        await viewModel.reveal(session: session)
                                    }
                                }
                            }
                            CommandButton(title: "Locate", icon: "location", tint: WikiTheme.ink) {
                                location.request()
                            }
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
        .overlay(alignment: .top) {
            Rectangle().fill(phaseTint).frame(height: 2)
        }
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

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Kicker(text: "Jump")
            HStack(spacing: 8) {
                ForEach(cities) { city in
                    Button(city.label) {
                        choose(city)
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(WikiTheme.blue)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .overlay(RoundedRectangle(cornerRadius: WikiTheme.radius).stroke(WikiTheme.rule.opacity(0.75)))
                    .buttonStyle(ArcadePressStyle())
                }
            }
        }
    }
}

private struct NearbyRevealPanel: View {
    let article: NearbyArticle
    let score: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            PhotoClueCard(
                kicker: "Target revealed",
                title: article.title,
                detail: article.description ?? "Wikipedia article",
                media: article.media,
                visualState: .revealed,
                tint: WikiTheme.red
            )
            MediaCreditRow(media: article.media)
            Kicker(text: "Target")
            Text(article.title)
                .font(.title2.weight(.bold))
                .foregroundStyle(WikiTheme.ink)
                .lineLimit(2)
                .minimumScaleFactor(0.82)
            if let description = article.description {
                Text(description)
                    .foregroundStyle(WikiTheme.muted)
            }
            if let extract = article.extract {
                Text(extract)
                    .lineLimit(4)
                    .lineSpacing(3)
            }
            TickerNumberText(value: score, suffix: " XP", font: .system(.title3, design: .monospaced).weight(.black))
                .foregroundStyle(WikiTheme.green)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 12)
        .overlay(alignment: .top) {
            Rectangle().fill(WikiTheme.red).frame(height: 3)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}
