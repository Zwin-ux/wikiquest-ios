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
                        if
                            viewModel.phase == .revealed,
                            let guess = viewModel.guess,
                            let target = viewModel.selected?.coordinate
                        {
                            MapPolyline(coordinates: [guess, target])
                                .stroke(WikiTheme.red.opacity(0.72), lineWidth: 3)
                        }

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
                .overlay(alignment: .bottom) {
                    Rectangle().fill(WikiTheme.hairline).frame(height: 1)
                }
                .accessibilityIdentifier("NearbyMapStage")

                ScrollView {
                    MapControlSheet(tint: phaseTint) {
                        MapQuestStatus(
                            title: mapSurveyTitle,
                            phase: viewModel.phase,
                            centerLabel: viewModel.centerLabel,
                            articleCount: viewModel.articles.count,
                            hasGuess: viewModel.guess != nil,
                            distanceText: viewModel.distanceMeters.map(NearbyScoring.format)
                        )
                            .accessibilityIdentifier("NearbyQuestStatus")

                        if shouldShowPinFeedback {
                            MapPinFeedbackStrip(trigger: guessPulse, tint: phaseTint)
                                .accessibilityIdentifier("NearbyPinFeedback")
                        }

                        if location.authorizationDenied || viewModel.phase == .denied {
                            InlineNotice(title: "LOCATION", detail: "Location is denied. You can still play from a sample city.", tint: WikiTheme.amber)
                        }

                        if let error = viewModel.error {
                            RecoveryNotice(
                                title: "MAP ERROR",
                                detail: error,
                                actionTitle: "Retry map",
                                tint: WikiTheme.red
                            ) {
                                Task {
                                    await viewModel.load(
                                        center: viewModel.region.center,
                                        label: viewModel.centerLabel,
                                        denied: location.authorizationDenied
                                    )
                                }
                            }
                            .accessibilityIdentifier("NearbyRecoveryNotice")
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

                        MapActionRow(
                            phase: viewModel.phase,
                            tint: phaseTint,
                            revealTitle: revealActionTitle,
                            revealIcon: revealActionIcon,
                            revealDisabled: revealDisabled,
                            revealPlaysHaptic: true,
                            hasGuess: viewModel.guess != nil,
                            shareText: mapShareText,
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
                            NearbyRevealPanel(
                                article: article,
                                distanceText: viewModel.distanceMeters.map(NearbyScoring.format) ?? "Unknown",
                                distanceMeters: viewModel.distanceMeters,
                                score: viewModel.savedXP ?? viewModel.localScore ?? 0
                            )
                        }

                        CityRail(cities: cities) { city in
                            Task { await loadCity(city) }
                        }
                        .accessibilityIdentifier("NearbyCityRail")
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

    private var mapSurveyTitle: String {
        switch viewModel.phase {
        case .locating:
            return "Finding map center"
        case .loading:
            return "Loading nearby pages"
        case .guess, .denied:
            return viewModel.guess == nil ? "Drop a pin" : "Pin armed"
        case .revealed:
            return viewModel.selected?.title ?? "Target revealed"
        case .empty:
            return "Try another city"
        }
    }

    private var revealDisabled: Bool {
        if viewModel.phase == .revealed { return false }
        return viewModel.guess == nil || viewModel.selected == nil
    }

    private var shouldShowPinFeedback: Bool {
        viewModel.guess != nil && (viewModel.phase == .guess || viewModel.phase == .denied)
    }

    private var revealActionTitle: String {
        switch viewModel.phase {
        case .locating, .loading:
            return "Loading map"
        case .empty:
            return "Choose city"
        case .revealed:
            return "Next"
        case .guess, .denied:
            return viewModel.guess != nil ? "Reveal target" : "Reveal"
        }
    }

    private var revealActionIcon: String {
        switch viewModel.phase {
        case .locating, .loading:
            return "map"
        case .empty:
            return "location"
        case .revealed:
            return "arrow.clockwise"
        case .guess, .denied:
            return viewModel.guess != nil ? "scope" : "mappin.and.ellipse"
        }
    }

    private var mapShareText: String? {
        guard viewModel.phase == .revealed, let article = viewModel.selected else {
            return nil
        }
        return nearbyShareText(article: article)
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
        .accessibilityIdentifier("NearbyControlSheet")
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
        GameHUDCluster(items: items)
    }

    private var items: [GameHUDItem] {
        var hudItems = [
            GameHUDItem(label: "Pages", value: "\(articleCount)", systemImage: "doc.text.magnifyingglass", tint: WikiTheme.blue)
        ]
        if let distance {
            hudItems.append(GameHUDItem(label: "Distance", value: NearbyScoring.format(distance), systemImage: "ruler", tint: WikiTheme.violet))
        } else {
            hudItems.append(GameHUDItem(label: "Score", value: "\(score)", systemImage: "star.fill", tint: WikiTheme.green))
        }
        return hudItems
    }
}

private struct MapQuestStatus: View {
    let title: String
    let phase: NearbyPhase
    let centerLabel: String?
    let articleCount: Int
    let hasGuess: Bool
    let distanceText: String?

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Image("ModeNearbyMark")
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: 38, height: 38)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Kicker(text: centerLabel ?? "Map")
                    Text(phaseLabel)
                        .font(.caption2.weight(.black).monospaced())
                        .foregroundStyle(phaseTint)
                }
                Text(title)
                    .font(.headline.weight(.black))
                    .foregroundStyle(WikiTheme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 6) {
                        surveyChips
                    }
                    VStack(alignment: .leading, spacing: 5) {
                        surveyChips
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 10)
        .overlay(alignment: .bottom) {
            Rectangle().fill(WikiTheme.hairline).frame(height: 1)
        }
        .motionTick(trigger: "\(phase)-\(hasGuess)-\(distanceText ?? "none")-\(articleCount)", tint: phaseTint)
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

    private var statusChipLabel: String {
        switch phase {
        case .locating, .loading:
            return "State"
        case .guess, .denied:
            return "Pin"
        case .revealed:
            return "Distance"
        case .empty:
            return "Jump"
        }
    }

    private var statusChipValue: String {
        switch phase {
        case .locating:
            return "Find"
        case .loading:
            return "Load"
        case .guess, .denied:
            return hasGuess ? "Ready" : "Hidden"
        case .revealed:
            return distanceText ?? "Shown"
        case .empty:
            return "City"
        }
    }

    private var statusChipIcon: String {
        switch phase {
        case .locating, .loading:
            return "map"
        case .guess, .denied:
            return hasGuess ? "mappin.circle.fill" : "mappin.and.ellipse"
        case .revealed:
            return "ruler"
        case .empty:
            return "location"
        }
    }

    private var statusChipTint: Color {
        switch phase {
        case .revealed:
            return WikiTheme.violet
        case .guess, .denied:
            return hasGuess ? WikiTheme.blue : WikiTheme.muted
        case .empty:
            return WikiTheme.muted
        default:
            return WikiTheme.ink
        }
    }

    @ViewBuilder
    private var surveyChips: some View {
        MapSurveyChip(label: "Pages", value: "\(articleCount)", systemImage: "doc.text.magnifyingglass", tint: WikiTheme.blue)
        MapSurveyChip(label: statusChipLabel, value: statusChipValue, systemImage: statusChipIcon, tint: statusChipTint)
    }
}

private struct MapSurveyChip: View {
    let label: String
    let value: String
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: systemImage)
                .font(.caption2.weight(.black))
            Text(label.uppercased())
                .font(.caption2.weight(.black).monospaced())
            Text(value)
                .font(.caption2.weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 7)
        .padding(.vertical, 5)
        .background(tint.opacity(0.07))
        .overlay {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(tint.opacity(0.26), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
    }
}

private struct CityRail: View {
    let cities: [KnownCity]
    let choose: (KnownCity) -> Void
    @State private var selectedCityID: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Kicker(text: "Jump")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(cities) { city in
                        Button {
                            Haptics.light()
                            selectedCityID = city.id
                            choose(city)
                        } label: {
                            CityJumpChip(city: city, isSelected: selectedCityID == city.id)
                        }
                        .buttonStyle(ArcadePressStyle())
                        .motionTick(trigger: selectedCityID == city.id ? selectedCityID : nil, tint: WikiTheme.blue)
                        .accessibilityIdentifier("NearbyCityJump-\(city.label.replacingOccurrences(of: " ", with: ""))")
                    }
                }
                .padding(.vertical, 2)
            }
            .scrollIndicators(.hidden)
        }
    }
}

private struct CityJumpChip: View {
    let city: KnownCity
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: isSelected ? "scope" : "location")
                .font(.caption.weight(.black))
            Text(city.label)
                .font(.caption.weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.76)
        }
        .foregroundStyle(isSelected ? .white : WikiTheme.blue)
        .padding(.horizontal, 11)
        .padding(.vertical, 8)
        .background(isSelected ? WikiTheme.blue : WikiTheme.blue.opacity(0.06))
        .overlay {
            RoundedRectangle(cornerRadius: WikiTheme.radius, style: .continuous)
                .stroke(isSelected ? WikiTheme.blue : WikiTheme.rule.opacity(0.75), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: WikiTheme.radius, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

private struct MapPinFeedbackStrip: View {
    let trigger: String
    let tint: Color

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(tint.opacity(0.12))
                    .frame(width: 34, height: 34)
                Image(systemName: "mappin.circle.fill")
                    .font(.callout.weight(.black))
                    .foregroundStyle(tint)
            }

            VStack(alignment: .leading, spacing: 2) {
                Kicker(text: "Pin armed")
                Text("Reveal target or tap the map to move it.")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(WikiTheme.muted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)
            }

            Spacer(minLength: 8)

            Text("READY")
                .font(.caption2.weight(.black).monospaced())
                .foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 9)
        .overlay(alignment: .top) {
            Rectangle().fill(tint.opacity(0.28)).frame(height: 1)
        }
        .overlay(alignment: .bottom) {
            Rectangle().fill(tint.opacity(0.28)).frame(height: 1)
        }
        .motionTick(trigger: trigger, tint: tint)
    }
}

private struct MapActionRow: View {
    let phase: NearbyPhase
    let tint: Color
    let revealTitle: String
    let revealIcon: String
    let revealDisabled: Bool
    let revealPlaysHaptic: Bool
    let hasGuess: Bool
    let shareText: String?
    let reveal: () -> Void
    let locate: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            MapPrimaryActionLane(
                phase: phase,
                title: revealTitle,
                icon: revealIcon,
                tint: tint,
                isDisabled: revealDisabled,
                playsHaptic: revealPlaysHaptic,
                hasGuess: hasGuess,
                action: reveal
            )
            if let shareText {
                MapShareButton(shareText: shareText)
            }
            MapLocateButton(action: locate)
        }
        .padding(.top, 2)
        .accessibilityIdentifier("NearbyActionRow")
        .motionTick(trigger: "\(phase)-\(hasGuess)-\(shareText != nil)", tint: tint)
    }
}

private struct MapPrimaryActionLane: View {
    let phase: NearbyPhase
    let title: String
    let icon: String
    let tint: Color
    let isDisabled: Bool
    let playsHaptic: Bool
    let hasGuess: Bool
    let action: () -> Void
    @State private var tapToken = 0

    var body: some View {
        Button {
            if playsHaptic {
                Haptics.light()
            }
            tapToken &+= 1
            action()
        } label: {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(iconFill)
                    Image(systemName: icon)
                        .font(.callout.weight(.black))
                        .foregroundStyle(iconColor)
                }
                .frame(width: 38, height: 38)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(kicker)
                            .font(.caption2.weight(.black).monospaced())
                            .foregroundStyle(kickerColor)
                        Rectangle()
                            .fill(kickerColor.opacity(isDisabled ? 0.24 : 0.48))
                            .frame(width: 18, height: 1)
                    }

                    Text(title)
                        .font(.callout.weight(.black))
                        .foregroundStyle(titleColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.76)

                    Text(detail)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(WikiTheme.muted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.74)
                }
                .layoutPriority(1)

                Spacer(minLength: 8)

                Text(commandCode)
                    .font(.caption2.weight(.black).monospaced())
                    .foregroundStyle(commandColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(commandBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            }
            .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(laneBackground)
            .overlay {
                RoundedRectangle(cornerRadius: WikiTheme.controlRadius, style: .continuous)
                    .stroke(laneStroke, lineWidth: phase == .revealed ? 1.4 : 1)
            }
            .overlay(alignment: .topLeading) {
                Rectangle()
                    .fill(kickerColor.opacity(isDisabled ? 0.18 : 0.72))
                    .frame(width: 52, height: 2)
            }
            .clipShape(RoundedRectangle(cornerRadius: WikiTheme.controlRadius, style: .continuous))
        }
        .disabled(isDisabled)
        .buttonStyle(ArcadePressStyle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(detail)")
        .commandLanePulse(trigger: tapToken, tint: tint, enabled: !isDisabled)
        .motionTick(trigger: tapToken, tint: tint, enabled: !isDisabled)
    }

    private var kicker: String {
        switch phase {
        case .locating, .loading:
            return "MAP"
        case .guess, .denied:
            return hasGuess ? "PIN READY" : "DROP PIN"
        case .revealed:
            return "RESULT"
        case .empty:
            return "EMPTY"
        }
    }

    private var detail: String {
        switch phase {
        case .locating:
            return "Finding your map center."
        case .loading:
            return "Loading Wikipedia pages."
        case .guess, .denied:
            return hasGuess ? "Reveal target or move the pin." : "Tap the map to arm reveal."
        case .revealed:
            return "Load another hidden article."
        case .empty:
            return "Try a city jump below."
        }
    }

    private var commandCode: String {
        switch phase {
        case .locating, .loading:
            return "WAIT"
        case .guess, .denied:
            return hasGuess ? "REVEAL" : "PIN"
        case .revealed:
            return "NEXT"
        case .empty:
            return "JUMP"
        }
    }

    private var laneBackground: Color {
        if isDisabled {
            return WikiTheme.surfaceStrong.opacity(0.68)
        }
        return tint.opacity(phase == .revealed ? 0.10 : 0.07)
    }

    private var laneStroke: Color {
        if isDisabled {
            return WikiTheme.rule.opacity(0.78)
        }
        return tint.opacity(phase == .revealed ? 0.70 : 0.42)
    }

    private var iconFill: Color {
        isDisabled ? WikiTheme.surface : tint
    }

    private var iconColor: Color {
        isDisabled ? WikiTheme.muted : .white
    }

    private var kickerColor: Color {
        isDisabled ? WikiTheme.muted : tint
    }

    private var titleColor: Color {
        isDisabled ? WikiTheme.muted : WikiTheme.ink
    }

    private var commandColor: Color {
        isDisabled ? WikiTheme.muted : .white
    }

    private var commandBackground: Color {
        isDisabled ? WikiTheme.surface : tint
    }
}

private struct MapShareButton: View {
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
        .accessibilityIdentifier("NearbyShareResultButton")
        .motionTick(trigger: tapToken, tint: WikiTheme.blue)
    }
}

private struct MapLocateButton: View {
    let action: () -> Void
    @State private var tapToken = 0

    var body: some View {
        Button {
            Haptics.light()
            tapToken &+= 1
            action()
        } label: {
            Image(systemName: "location")
                .font(.callout.weight(.black))
                .foregroundStyle(WikiTheme.ink)
                .frame(width: 46, height: 46)
                .overlay {
                    RoundedRectangle(cornerRadius: WikiTheme.radius, style: .continuous)
                        .stroke(WikiTheme.rule.opacity(0.82), lineWidth: 1)
                }
        }
        .buttonStyle(ArcadePressStyle())
        .accessibilityLabel("Locate")
        .accessibilityIdentifier("NearbyLocateButton")
        .motionTick(trigger: tapToken, tint: WikiTheme.ink)
    }
}

private struct NearbyRevealPanel: View {
    let article: NearbyArticle
    let distanceText: String
    let distanceMeters: Double?
    let score: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            NearbyRevealSummary(
                title: article.title,
                distanceText: distanceText,
                distanceMeters: distanceMeters,
                score: score
            )

            PhotoClueCard(
                kicker: "Target revealed",
                title: article.title,
                detail: article.description ?? "Wikipedia target",
                media: article.media,
                visualState: .revealed,
                tint: WikiTheme.red,
                fallbackStyle: .map
            )
            MediaCreditRow(media: article.media)

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
        .accessibilityIdentifier("NearbyRevealPanel")
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .motionTick(trigger: "\(article.id)-\(distanceText)-\(score)", tint: WikiTheme.red)
    }
}

private struct NearbyRevealSummary: View {
    let title: String
    let distanceText: String
    let distanceMeters: Double?
    let score: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .center, spacing: 12) {
                ResultStamp(systemImage: grade.systemImage, tint: grade.tint, value: score)

                VStack(alignment: .leading, spacing: 3) {
                    MapRevealGradeBadge(grade: grade)

                    Kicker(text: "Pin to target")
                    Text(distanceText)
                        .font(.system(.title3, design: .monospaced).weight(.black))
                        .foregroundStyle(WikiTheme.violet)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                    Text(title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(WikiTheme.muted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.76)
                }

                Spacer(minLength: 8)
            }

            MapRevealResultRail(grade: grade, distanceText: distanceText, score: score)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
        .overlay(alignment: .bottom) {
            Rectangle().fill(WikiTheme.hairline).frame(height: 1)
        }
        .resultPop(trigger: "\(title)-\(distanceText)-\(score)-\(grade.label)", tint: grade.tint)
    }

    private var grade: MapRevealGrade {
        MapRevealGrade(distanceMeters: distanceMeters)
    }
}

private enum MapRevealGrade: Equatable {
    case bullseye
    case close
    case near
    case found
    case wide
    case unknown

    init(distanceMeters: Double?) {
        guard let distanceMeters else {
            self = .unknown
            return
        }

        switch distanceMeters {
        case 0..<50:
            self = .bullseye
        case 50..<150:
            self = .close
        case 150..<500:
            self = .near
        case 500..<1_500:
            self = .found
        default:
            self = .wide
        }
    }

    var label: String {
        switch self {
        case .bullseye:
            return "Bullseye"
        case .close:
            return "Close"
        case .near:
            return "Near"
        case .found:
            return "Found"
        case .wide:
            return "Wide"
        case .unknown:
            return "Found"
        }
    }

    var systemImage: String {
        switch self {
        case .bullseye:
            return "scope"
        case .close:
            return "location.north.line.fill"
        case .near:
            return "mappin.circle.fill"
        case .found, .unknown:
            return "mappin.and.ellipse"
        case .wide:
            return "ruler"
        }
    }

    var tint: Color {
        switch self {
        case .bullseye:
            return WikiTheme.green
        case .close:
            return WikiTheme.blue
        case .near:
            return WikiTheme.violet
        case .found, .unknown:
            return WikiTheme.amber
        case .wide:
            return WikiTheme.red
        }
    }
}

private struct MapRevealGradeBadge: View {
    let grade: MapRevealGrade

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: grade.systemImage)
                .font(.caption2.weight(.black))
            Text(grade.label.uppercased())
                .font(.caption2.weight(.black).monospaced())
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 7)
        .padding(.vertical, 5)
        .background(grade.tint)
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        .accessibilityLabel("Map result \(grade.label)")
    }
}

private struct MapRevealResultRail: View {
    let grade: MapRevealGrade
    let distanceText: String
    let score: Int

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 0) {
                MapRevealRailNode(systemImage: "mappin.circle.fill", label: "PIN", tint: WikiTheme.blue)
                MapRevealRailConnector(tint: grade.tint)
                MapRevealRailNode(systemImage: grade.systemImage, label: distanceText, tint: grade.tint)
                MapRevealRailConnector(tint: WikiTheme.green)
                MapRevealRailNode(systemImage: "star.fill", label: "\(score) XP", tint: WikiTheme.green)
            }

            HStack(spacing: 0) {
                MapRevealRailNode(systemImage: "mappin.circle.fill", label: "PIN", tint: WikiTheme.blue)
                MapRevealRailConnector(tint: grade.tint)
                MapRevealRailNode(systemImage: grade.systemImage, label: grade.label, tint: grade.tint)
                MapRevealRailConnector(tint: WikiTheme.green)
                MapRevealRailNode(systemImage: "star.fill", label: "\(score)", tint: WikiTheme.green)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 2)
        .revealSweep(trigger: "\(grade.label)-\(distanceText)-\(score)", tint: grade.tint)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Pin to target, \(distanceText), \(score) XP")
    }
}

private struct MapRevealRailNode: View {
    let systemImage: String
    let label: String
    let tint: Color

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: systemImage)
                .font(.caption2.weight(.black))
            Text(label.uppercased())
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .lineLimit(1)
                .minimumScaleFactor(0.68)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 7)
        .padding(.vertical, 5)
        .background(tint.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
    }
}

private struct MapRevealRailConnector: View {
    let tint: Color

    var body: some View {
        ZStack {
            Rectangle()
                .fill(WikiTheme.hairline)
                .frame(height: 1)
            Rectangle()
                .fill(tint.opacity(0.55))
                .frame(height: 2)
                .padding(.horizontal, 4)
        }
        .frame(width: 24)
    }
}
