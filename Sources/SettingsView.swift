import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var monitor: Monitor
    @StateObject private var discovery = DeviceDiscovery()
    @State private var testResult: String?
    @State private var testOK = false
    @State private var testing = false
    @State private var launchAtLogin = LoginItem.isEnabled
    @State private var loginError: String?

    var body: some View {
        Form {
            deviceSection
            menuBarSection
            generalSection
            notificationsSection
            remoteSection
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Appareil

    private var deviceSection: some View {
        Section("Appareil SolarFlow") {
            TextField("Adresse IP ou nom d'hôte", text: $monitor.host, prompt: Text("192.168.1.xx ou Zendure-….local"))
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()

            HStack {
                Button(discovery.isSearching ? "Recherche…" : "Rechercher sur le réseau") {
                    discovery.start()
                }
                .disabled(discovery.isSearching)

                Button(testing ? "Test…" : "Tester la connexion") {
                    runTest()
                }
                .disabled(testing || monitor.host.isEmpty)
            }

            if let testResult {
                Label(testResult, systemImage: testOK ? "checkmark.circle" : "xmark.circle")
                    .foregroundStyle(testOK ? .green : .red)
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
            }

            ForEach(discovery.devices) { device in
                HStack {
                    VStack(alignment: .leading) {
                        Text(device.name).font(.callout)
                        Text(device.host).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Utiliser") { monitor.host = device.host }
                }
            }
        }
    }

    // MARK: - Barre de menu

    private var menuBarSection: some View {
        Section("Barre de menu") {
            Toggle("Production solaire (W)", isOn: $monitor.showSolarInBar)
            Toggle("Niveau de batterie (%)", isOn: $monitor.showBatteryInBar)
            Toggle("Consommation maison (W)", isOn: $monitor.showHomeInBar)
            Text("Tout décocher n'affiche que l'icône ☀️. Astuce : si l'icône est invisible, vérifiez les apps qui masquent la barre de menu et le réglage macOS « Masquer/afficher automatiquement la barre des menus ».")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Général

    private var generalSection: some View {
        Section("Général") {
            Toggle("Lancer au démarrage de la session", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _, enabled in
                    loginError = LoginItem.set(enabled: enabled)
                    if loginError != nil { launchAtLogin = LoginItem.isEnabled }
                }
            if let loginError {
                Label(loginError, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            Slider(value: $monitor.pollInterval, in: 2...60, step: 1) {
                Text("Rafraîchissement")
            } minimumValueLabel: {
                Text("2 s")
            } maximumValueLabel: {
                Text("60 s")
            }
            Text("Toutes les \(Int(monitor.pollInterval)) secondes")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Notifications

    private var notificationsSection: some View {
        Section("Notifications") {
            Toggle("Alerte batterie faible", isOn: $monitor.lowSocAlertEnabled)
            if monitor.lowSocAlertEnabled {
                Slider(value: $monitor.lowSocThreshold, in: 5...50, step: 5) {
                    Text("Seuil")
                } minimumValueLabel: {
                    Text("5 %")
                } maximumValueLabel: {
                    Text("50 %")
                }
                Text("Notification quand la batterie passe sous \(Int(monitor.lowSocThreshold)) %")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Accès distant

    private var remoteSection: some View {
        Section("Accès distant (optionnel)") {
            TextField("Hôte de secours", text: $monitor.fallbackHost, prompt: Text("ex. 100.x.y.z (IP Tailscale)"))
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()
            Text("Essayé automatiquement quand l'adresse principale ne répond pas (hors du réseau domestique). Recommandé : un VPN type Tailscale/WireGuard vers la maison, avec le sous-réseau local partagé. ⚠️ N'exposez jamais le port 80 du SolarFlow directement sur Internet : son API locale n'a aucune authentification.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func runTest() {
        testing = true
        testResult = nil
        let host = monitor.host
        Task {
            let result = await monitor.test(host: host)
            switch result {
            case .success(let state):
                testOK = true
                var parts = ["Connecté", Format.watts(state.solarInputPower) + " solaire"]
                if let soc = state.electricLevel { parts.append("\(Int(soc)) % batterie") }
                if let sn = state.serialNumber { parts.append("SN \(sn)") }
                testResult = parts.joined(separator: " — ")
            case .failure(let error):
                testOK = false
                testResult = error.localizedDescription
            }
            testing = false
        }
    }
}
