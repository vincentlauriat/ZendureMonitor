import Foundation

/// Météo locale pour la fenêtre Soleil, via Open-Meteo (HTTPS, sans clé,
/// usage non commercial libre). Rafraîchie au plus toutes les 30 min —
/// inutile de marteler l'API pour de la prévision horaire.
@MainActor
final class WeatherService: ObservableObject {
    struct Weather: Equatable {
        var temperature: Double        // °C
        var cloudCover: Double         // % actuel
        var weatherCode: Int           // code WMO
        var sunshineForecastSec: Double?   // s d'ensoleillement prévu aujourd'hui
        var fetchedAt: Date
    }

    @Published private(set) var weather: Weather?
    @Published private(set) var lastError: String?

    private var task: Task<Void, Never>?
    private var fetchedFor: (lat: Double, lon: Double) = (0, 0)

    func refresh(latitude: Double, longitude: Double) {
        guard latitude != 0 || longitude != 0 else { return }
        // Cache 30 min, invalidé si la position change.
        if let weather, fetchedFor == (latitude, longitude),
           Date.now.timeIntervalSince(weather.fetchedAt) < 1800 { return }
        guard task == nil else { return }

        task = Task { [weak self] in
            defer { self?.task = nil }
            do {
                let weather = try await Self.fetch(latitude: latitude, longitude: longitude)
                self?.weather = weather
                self?.fetchedFor = (latitude, longitude)
                self?.lastError = nil
            } catch {
                self?.lastError = error.localizedDescription
            }
        }
    }

    private static func fetch(latitude: Double, longitude: Double) async throws -> Weather {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        components.queryItems = [
            .init(name: "latitude", value: String(format: "%.4f", latitude)),
            .init(name: "longitude", value: String(format: "%.4f", longitude)),
            .init(name: "current", value: "temperature_2m,cloud_cover,weather_code"),
            .init(name: "daily", value: "sunshine_duration"),
            .init(name: "forecast_days", value: "1"),
            .init(name: "timezone", value: "auto"),
        ]
        struct Response: Decodable {
            struct Current: Decodable {
                let temperature_2m: Double
                let cloud_cover: Double
                let weather_code: Int
            }
            struct Daily: Decodable { let sunshine_duration: [Double?] }
            let current: Current
            let daily: Daily?
        }
        let (data, response) = try await URLSession.shared.data(from: components.url!)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw URLError(.badServerResponse)
        }
        let decoded = try JSONDecoder().decode(Response.self, from: data)
        return Weather(
            temperature: decoded.current.temperature_2m,
            cloudCover: decoded.current.cloud_cover,
            weatherCode: decoded.current.weather_code,
            sunshineForecastSec: decoded.daily?.sunshine_duration.first ?? nil,
            fetchedAt: .now
        )
    }
}

/// Libellé + symbole SF pour un code météo WMO (groupes, pas l'exhaustivité).
enum WMOCode {
    static func describe(_ code: Int) -> (symbol: String, label: String) {
        switch code {
        case 0: return ("sun.max.fill", String(localized: "Ciel clair"))
        case 1, 2: return ("cloud.sun.fill", String(localized: "Partiellement nuageux"))
        case 3: return ("cloud.fill", String(localized: "Couvert"))
        case 45, 48: return ("cloud.fog.fill", String(localized: "Brouillard"))
        case 51...57: return ("cloud.drizzle.fill", String(localized: "Bruine"))
        case 61...67, 80...82: return ("cloud.rain.fill", String(localized: "Pluie"))
        case 71...77, 85, 86: return ("cloud.snow.fill", String(localized: "Neige"))
        case 95...99: return ("cloud.bolt.rain.fill", String(localized: "Orage"))
        default: return ("cloud.fill", String(localized: "Nuageux"))
        }
    }
}
