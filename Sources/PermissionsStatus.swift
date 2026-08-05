import SwiftUI
import CoreLocation
import UserNotifications

/// État des autorisations système dont l'app dépend — vérifié au démarrage
/// et à l'affichage des Réglages, pour corriger en amont plutôt que de
/// découvrir le problème à l'usage. macOS n'offre aucune API pour interroger
/// l'autorisation « réseau local » : son état est inféré du résultat des
/// polls (voir Monitor.localNetworkDenied).
@MainActor
final class PermissionsStatus: ObservableObject {
    @Published var locationServicesOn: Bool?
    @Published var locationAuth: CLAuthorizationStatus?
    @Published var notificationsAuth: UNAuthorizationStatus?

    func refresh() {
        Task.detached { [weak self] in
            let enabled = CLLocationManager.locationServicesEnabled()
            let auth = CLLocationManager().authorizationStatus
            await MainActor.run {
                self?.locationServicesOn = enabled
                self?.locationAuth = auth
            }
        }
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            Task { @MainActor [weak self] in
                self?.notificationsAuth = settings.authorizationStatus
            }
        }
    }
}

/// Section « Autorisations » des Réglages : un état par autorisation, avec
/// un bouton vers le bon panneau des Réglages Système quand il y a à faire.
struct PermissionsSection: View {
    @EnvironmentObject var monitor: Monitor
    @StateObject private var status = PermissionsStatus()

    var body: some View {
        Section("Autorisations") {
            localNetworkRow
            locationRow
            notificationsRow
        }
        .onAppear { status.refresh() }
    }

    @ViewBuilder
    private var localNetworkRow: some View {
        if monitor.state != nil {
            row(ok: true, name: "Réseau local", detail: String(localized: "Autorisé — connexion au SolarFlow active"))
        } else if monitor.localNetworkDenied {
            row(ok: false, name: "Réseau local",
                detail: String(localized: "Bloqué par macOS — l'app ne peut pas joindre le SolarFlow"),
                pane: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocalNetwork")
        } else {
            row(ok: nil, name: "Réseau local", detail: String(localized: "Vérification en cours…"))
        }
    }

    @ViewBuilder
    private var locationRow: some View {
        if status.locationServicesOn == false {
            row(ok: false, name: "Localisation",
                detail: String(localized: "Service désactivé pour tout le système (facultatif — sert au module Soleil)"),
                pane: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices")
        } else {
            switch status.locationAuth {
            case .authorized, .authorizedAlways:
                row(ok: true, name: "Localisation", detail: String(localized: "Autorisée"))
            case .denied, .restricted:
                row(ok: false, name: "Localisation",
                    detail: String(localized: "Refusée (facultatif — sert au module Soleil)"),
                    pane: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices")
            default:
                row(ok: nil, name: "Localisation", detail: String(localized: "Demandée au premier usage (facultative)"))
            }
        }
    }

    @ViewBuilder
    private var notificationsRow: some View {
        switch status.notificationsAuth {
        case .authorized, .provisional:
            row(ok: true, name: "Notifications", detail: String(localized: "Autorisées"))
        case .denied:
            row(ok: !monitor.lowSocAlertEnabled ? nil : false, name: "Notifications",
                detail: monitor.lowSocAlertEnabled
                    ? String(localized: "Refusées — l'alerte batterie faible ne s'affichera pas")
                    : String(localized: "Refusées (alerte batterie désactivée)"),
                pane: monitor.lowSocAlertEnabled ? "x-apple.systempreferences:com.apple.preference.notifications" : nil)
        default:
            row(ok: nil, name: "Notifications", detail: String(localized: "Demandées à l'activation de l'alerte batterie"))
        }
    }

    private func row(ok: Bool?, name: LocalizedStringKey, detail: String, pane: String? = nil) -> some View {
        HStack(spacing: 8) {
            Image(systemName: ok == true ? "checkmark.circle.fill"
                            : ok == false ? "exclamationmark.triangle.fill" : "circle.dashed")
                .foregroundStyle(ok == true ? .green : ok == false ? .orange : .secondary)
            VStack(alignment: .leading, spacing: 1) {
                Text(name)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            if let pane, let url = URL(string: pane) {
                Button("Ouvrir…") { NSWorkspace.shared.open(url) }
            }
        }
    }
}
