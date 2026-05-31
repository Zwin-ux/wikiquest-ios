import CoreLocation
import Foundation

@MainActor
final class LocationStore: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var coordinate: CLLocationCoordinate2D?
    @Published var authorizationDenied = false
    @Published var statusText = "Locating"

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func request() {
        authorizationDenied = false
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            statusText = "Using current location"
            manager.requestLocation()
        case .denied, .restricted:
            authorizationDenied = true
            statusText = "Location denied. Showing San Francisco."
            coordinate = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        @unknown default:
            coordinate = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in request() }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latest = locations.last else { return }
        Task { @MainActor in
            coordinate = latest.coordinate
            statusText = "Current location"
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            statusText = "Location unavailable. Showing San Francisco."
            coordinate = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        }
    }
}
