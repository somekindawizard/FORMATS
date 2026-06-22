import CoreLocation

/// One-shot current-place lookup. Requests when-in-use authorization if
/// needed, gets a single coarse fix, and reverse-geocodes it to a short
/// place name. Returns nil if unavailable or denied — never throws, never
/// blocks the UI. Requires NSLocationWhenInUseUsageDescription (Info.plist).
@MainActor
final class LocationProvider: NSObject, CLLocationManagerDelegate {
    struct Place { let name: String; let latitude: Double; let longitude: Double }

    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocation?, Never>?

    /// Fetch the current place, or nil. Safe to call repeatedly.
    func currentPlace() async -> Place? {
        guard let location = await requestLocation() else { return nil }
        let name = await reverseGeocode(location)
        return Place(name: name ?? "Here",
                     latitude: location.coordinate.latitude,
                     longitude: location.coordinate.longitude)
    }

    private func requestLocation() async -> CLLocation? {
        await withCheckedContinuation { (cont: CheckedContinuation<CLLocation?, Never>) in
            self.continuation = cont
            manager.delegate = self
            manager.desiredAccuracy = kCLLocationAccuracyKilometer
            switch manager.authorizationStatus {
            case .notDetermined:
                manager.requestWhenInUseAuthorization()
            case .authorizedWhenInUse, .authorizedAlways:
                manager.requestLocation()
            default:
                finish(nil)
            }
        }
    }

    private func finish(_ location: CLLocation?) {
        continuation?.resume(returning: location)
        continuation = nil
    }

    private func reverseGeocode(_ location: CLLocation) async -> String? {
        let geocoder = CLGeocoder()
        guard let placemark = try? await geocoder.reverseGeocodeLocation(location).first else {
            return nil
        }
        // Prefer a neighborhood/city; fall back to the most specific available.
        return placemark.locality
            ?? placemark.subLocality
            ?? placemark.administrativeArea
            ?? placemark.name
    }

    // MARK: CLLocationManagerDelegate

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            switch manager.authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways: manager.requestLocation()
            case .denied, .restricted: finish(nil)
            default: break
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager,
                                     didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in finish(locations.last) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager,
                                     didFailWithError error: Error) {
        Task { @MainActor in finish(nil) }
    }
}
