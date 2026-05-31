import CoreLocation
import Foundation

enum NearbyScoring {
    static func distanceMeters(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let a = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let b = CLLocation(latitude: to.latitude, longitude: to.longitude)
        return a.distance(from: b)
    }

    static func score(for distanceMeters: Double) -> Int {
        switch distanceMeters {
        case 0..<50:
            return 120
        case 50..<150:
            return 90
        case 150..<500:
            return 60
        case 500..<1_500:
            return 35
        default:
            return 20
        }
    }

    static func format(_ meters: Double) -> String {
        if meters < 1_000 {
            return "\(Int(meters.rounded())) m"
        }
        return String(format: "%.1f km", meters / 1_000)
    }
}
