import SwiftUI
import CoreLocation

/// Récupération one-shot de la position du Mac pour préremplir le module
/// Soleil (précision au km, jamais transmise). La demande d'autorisation
/// macOS n'est déclenchée qu'au clic sur le bouton.
final class LocationFetcher: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var busy = false
    @Published var errorMessage: String?

    private lazy var manager: CLLocationManager = {
        let manager = CLLocationManager()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
        return manager
    }()
    private var onFix: ((CLLocationCoordinate2D) -> Void)?

    func fetch(_ done: @escaping (CLLocationCoordinate2D) -> Void) {
        onFix = done
        errorMessage = nil
        busy = true
        if manager.authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
            // requestLocation() partira depuis locationManagerDidChangeAuthorization.
        } else {
            manager.requestLocation()
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard onFix != nil else { return }
        switch manager.authorizationStatus {
        case .authorized, .authorizedAlways:
            manager.requestLocation()
        case .denied, .restricted:
            fail()
        default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        DispatchQueue.main.async {
            self.busy = false
            if let coordinate = locations.last?.coordinate { self.onFix?(coordinate) }
            self.onFix = nil
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        fail()
    }

    private func fail() {
        DispatchQueue.main.async {
            self.busy = false
            self.onFix = nil
            self.errorMessage = String(localized: "Position introuvable — autorisez Zendure Monitor dans Réglages → Confidentialité et sécurité → Service de localisation, ou saisissez les coordonnées manuellement.")
        }
    }
}

/// Bouton « Utiliser la position de ce Mac » : remplit sunLatitude/sunLongitude.
struct UseMacLocationButton: View {
    @AppStorage("sunLatitude") private var sunLatitude: Double = 0
    @AppStorage("sunLongitude") private var sunLongitude: Double = 0
    @StateObject private var fetcher = LocationFetcher()

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Button {
                    fetcher.fetch { coordinate in
                        sunLatitude = (coordinate.latitude * 10000).rounded() / 10000
                        sunLongitude = (coordinate.longitude * 10000).rounded() / 10000
                    }
                } label: {
                    Label("Utiliser la position de ce Mac", systemImage: "location.fill")
                }
                .disabled(fetcher.busy)
                if fetcher.busy {
                    ProgressView().controlSize(.small)
                }
            }
            if let message = fetcher.errorMessage {
                Text(message)
                    .font(.caption2)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
