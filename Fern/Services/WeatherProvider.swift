import WeatherKit
import CoreLocation

/// Fetches current weather for a location via WeatherKit. Returns nil on any
/// failure (no entitlement, offline, denied) — weather is always optional.
enum WeatherProvider {
    static func current(for location: CLLocation) async -> (symbol: String, tempC: Double)? {
        do {
            let weather = try await WeatherService.shared.weather(for: location)
            let now = weather.currentWeather
            return (now.symbolName, now.temperature.converted(to: .celsius).value)
        } catch {
            return nil
        }
    }
}
