import WeatherKit
import CoreLocation
import os

/// Fetches current weather for a location via WeatherKit. Returns nil on any
/// failure (no entitlement, offline, denied, or service-not-yet-active) —
/// weather is always optional. Failures are logged so they can be diagnosed.
enum WeatherProvider {
    private static let log = Logger(subsystem: "garden.fern.Fern", category: "Weather")

    static func current(for location: CLLocation) async -> (symbol: String, tempC: Double)? {
        do {
            let weather = try await WeatherService.shared.weather(for: location)
            let now = weather.currentWeather
            return (now.symbolName, now.temperature.converted(to: .celsius).value)
        } catch {
            log.error("WeatherKit failed: \(String(describing: error), privacy: .public)")
            return nil
        }
    }
}
