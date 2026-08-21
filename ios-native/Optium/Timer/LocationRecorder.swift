import CoreLocation
import Foundation
import Observation

/// Capture la position une fois par activation du reglage, pas a chaque session :
/// on cherche a savoir *ou* l'utilisateur se concentre, pas a le suivre.
@Observable
@MainActor
final class LocationRecorder {
    private(set) var coordinate: (lat: Double, lng: Double)?

    @ObservationIgnored private let manager = CLLocationManager()

    func refresh(enabled: Bool) async {
        guard enabled else {
            coordinate = nil
            return
        }
        manager.requestWhenInUseAuthorization()
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters

        guard let update = try? await CLLocationUpdate.liveUpdates().first(where: { $0.location != nil }),
              let location = update.location else { return }

        coordinate = (lat: location.coordinate.latitude, lng: location.coordinate.longitude)
    }
}
