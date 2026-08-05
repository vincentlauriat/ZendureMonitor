import SwiftUI
import CoreLocation

/// Récupération one-shot de la position du Mac pour préremplir le module
/// Soleil (précision au km, jamais transmise). La demande d'autorisation
/// macOS n'est déclenchée qu'au clic sur le bouton. Chaque issue possible
/// (service coupé, refus, pas de fix, silence de locationd) aboutit à un
/// message clair — jamais à une attente infinie.
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
    private var timeoutTask: Task<Void, Never>?

    func fetch(_ done: @escaping (CLLocationCoordinate2D) -> Void) {
        onFix = done
        errorMessage = nil
        busy = true
        // locationServicesEnabled() peut bloquer → jamais sur le main thread.
        Task.detached { [weak self] in
            let enabled = CLLocationManager.locationServicesEnabled()
            DispatchQueue.main.async { self?.begin(servicesEnabled: enabled) }
        }
    }

    private func begin(servicesEnabled: Bool) {
        guard onFix != nil else { return }
        guard servicesEnabled else {
            finish(error: String(localized: "Le service de localisation de macOS est désactivé pour tout le système. Activez-le dans Réglages → Confidentialité et sécurité → Service de localisation, ou saisissez les coordonnées manuellement."))
            return
        }
        armTimeout()
        switch manager.authorizationStatus {
        case .denied, .restricted:
            finish(error: Self.deniedMessage)
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        default:
            manager.requestLocation()
        }
    }

    private func armTimeout() {
        timeoutTask?.cancel()
        timeoutTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(25))
            guard !Task.isCancelled else { return }
            DispatchQueue.main.async {
                self?.finish(error: String(localized: "Pas de réponse du service de localisation. Si aucune demande d'autorisation n'est apparue, vérifiez Réglages → Confidentialité et sécurité → Service de localisation — ou saisissez les coordonnées manuellement."))
            }
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard onFix != nil else { return }
        switch manager.authorizationStatus {
        case .authorized, .authorizedAlways:
            manager.requestLocation()
        case .denied, .restricted:
            finish(error: Self.deniedMessage)
        default:
            break   // .notDetermined : la demande d'autorisation est à l'écran.
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        DispatchQueue.main.async {
            self.finish(coordinate: locations.last?.coordinate)
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        DispatchQueue.main.async {
            if (error as? CLError)?.code == .denied {
                self.finish(error: Self.deniedMessage)
            } else {
                self.finish(error: String(localized: "Position introuvable pour ce Mac (pas de WiFi à proximité ?). Saisissez les coordonnées manuellement — une précision à la ville près suffit."))
            }
        }
    }

    private func finish(coordinate: CLLocationCoordinate2D? = nil, error: String? = nil) {
        timeoutTask?.cancel()
        timeoutTask = nil
        busy = false
        if let coordinate { onFix?(coordinate) }
        errorMessage = error
        onFix = nil
    }

    private static var deniedMessage: String {
        String(localized: "Position introuvable — autorisez Zendure Monitor dans Réglages → Confidentialité et sécurité → Service de localisation, ou saisissez les coordonnées manuellement.")
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
