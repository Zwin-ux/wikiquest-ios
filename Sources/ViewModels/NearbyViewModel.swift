import CoreLocation
import Foundation
import MapKit

enum NearbyPhase: Equatable {
    case locating
    case loading
    case guess
    case revealed
    case empty
    case denied
}

@MainActor
final class NearbyViewModel: ObservableObject {
    @Published var phase: NearbyPhase = .locating
    @Published var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
    )
    @Published var articles: [NearbyArticle] = []
    @Published var selected: NearbyArticle?
    @Published var guess: CLLocationCoordinate2D?
    @Published var distanceMeters: Double?
    @Published var localScore: Int?
    @Published var savedXP: Int?
    @Published var error: String?
    @Published var centerLabel: String?

    private let api: WikiQuestAPIClient
    private let wikipedia: WikipediaClient

    init(api: WikiQuestAPIClient, wikipedia: WikipediaClient = WikipediaClient()) {
        self.api = api
        self.wikipedia = wikipedia
    }

    func load(center: CLLocationCoordinate2D, label: String? = nil, denied: Bool = false) async {
        phase = .loading
        centerLabel = label
        guess = nil
        distanceMeters = nil
        localScore = nil
        savedXP = nil
        selected = nil
        error = nil
        region = MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
        )
        do {
            articles = try await wikipedia.nearby(latitude: center.latitude, longitude: center.longitude)
            guard !articles.isEmpty else {
                phase = .empty
                return
            }
            selected = articles.randomElement()
            phase = denied ? .denied : .guess
        } catch {
            self.error = error.localizedDescription
            phase = .empty
            Haptics.error()
        }
    }

    func placeGuess(_ coordinate: CLLocationCoordinate2D) {
        guard phase == .guess || phase == .denied else { return }
        guess = coordinate
        Haptics.light()
    }

    func reveal(session: SessionStore) async {
        guard let selected, let guess else {
            error = "Place a guess pin first."
            Haptics.error()
            return
        }
        let distance = NearbyScoring.distanceMeters(from: guess, to: selected.coordinate)
        distanceMeters = distance
        localScore = NearbyScoring.score(for: distance)
        phase = .revealed
        Haptics.success()
        if session.isSignedIn {
            let response = try? await api.recordCompletion(
                articleTitle: selected.title,
                mode: "nearby",
                displayName: session.displayName
            )
            savedXP = response?.xpAwarded ?? localScore
        } else {
            savedXP = localScore
        }
    }
}
