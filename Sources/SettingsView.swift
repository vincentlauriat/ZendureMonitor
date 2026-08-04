import SwiftUI

/// Fenêtre de réglages en onglets (style Réglages Système) :
/// Appareil / Affichage / Général / Notifications / Distant.
struct SettingsView: View {
    @EnvironmentObject var monitor: Monitor

    var body: some View {
        TabView {
            DeviceSettingsTab()
                .tabItem { Label("Appareil", systemImage: "antenna.radiowaves.left.and.right") }
            DisplaySettingsTab()
                .tabItem { Label("Affichage", systemImage: "menubar.rectangle") }
            GeneralSettingsTab()
                .tabItem { Label("Général", systemImage: "gearshape") }
            NotificationSettingsTab()
                .tabItem { Label("Notifications", systemImage: "bell.badge") }
            RemoteSettingsTab()
                .tabItem { Label("Distant", systemImage: "network") }
        }
        .frame(width: 440)
        .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - Appareil

private struct DeviceSettingsTab: View {
    @EnvironmentObject var monitor: Monitor
    @StateObject private var discovery = DeviceDiscovery()
    @State private var testResult: String?
    @State private var testOK = false
    @State private var testing = false

    var body: some View {
        Form {
            Section("Appareil SolarFlow") {
                TextField("Adresse IP ou nom d'hôte", text: $monitor.host, prompt: Text("192.168.1.xx ou Zendure-….local"))
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()

                HStack {
                    Button(discovery.isSearching ? "Recherche…" : "Rechercher sur le réseau") {
                        discovery.start()
                    }
                    .disabled(discovery.isSearching)

                    Button(testing ? "Test…" : "Tester la connexion") { runTest() }
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
        .formStyle(.grouped)
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
                var parts = [String(localized: "Connecté"),
                             Format.watts(state.solarInputPower) + " " + String(localized: "solaire")]
                if let soc = state.electricLevel {
                    parts.append("\(Int(soc)) % " + String(localized: "batterie"))
                }
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

// MARK: - Affichage

private struct DisplaySettingsTab: View {
    @EnvironmentObject var monitor: Monitor

    var body: some View {
        Form {
            Section("Barre de menu") {
                Toggle("Production solaire (W)", isOn: $monitor.showSolarInBar)
                Toggle("Niveau de batterie (%)", isOn: $monitor.showBatteryInBar)
                Toggle("Consommation maison (W)", isOn: $monitor.showHomeInBar)
                Text("Tout décocher n'affiche que l'icône ☀️.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("Thème") {
                Picker("Thème", selection: $monitor.appearance) {
                    ForEach(AppearanceMode.allCases) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Général

private struct GeneralSettingsTab: View {
    @EnvironmentObject var monitor: Monitor
    @State private var launchAtLogin = LoginItem.isEnabled
    @State private var loginError: String?

    var body: some View {
        Form {
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
            }
            Section("Rafraîchissement") {
                Slider(value: $monitor.pollInterval, in: 2...60, step: 1) {
                    Text("Rafraîchissement")
                } minimumValueLabel: {
                    Text(verbatim: "2 s")
                } maximumValueLabel: {
                    Text(verbatim: "60 s")
                }
                Text("Toutes les \(Int(monitor.pollInterval)) secondes")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Notifications

private struct NotificationSettingsTab: View {
    @EnvironmentObject var monitor: Monitor

    var body: some View {
        Form {
            Section("Notifications") {
                Toggle("Alerte batterie faible", isOn: $monitor.lowSocAlertEnabled)
                if monitor.lowSocAlertEnabled {
                    Slider(value: $monitor.lowSocThreshold, in: 5...50, step: 5) {
                        Text("Seuil")
                    } minimumValueLabel: {
                        Text(verbatim: "5 %")
                    } maximumValueLabel: {
                        Text(verbatim: "50 %")
                    }
                    HStack(spacing: 4) {
                        Text("Notification quand la batterie passe sous")
                        Text(verbatim: "\(Int(monitor.lowSocThreshold)) %")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Distant

private struct RemoteSettingsTab: View {
    @EnvironmentObject var monitor: Monitor

    var body: some View {
        Form {
            Section("Accès distant (optionnel)") {
                TextField("Hôte de secours", text: $monitor.fallbackHost, prompt: Text("ex. 100.x.y.z (IP Tailscale)"))
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
                Text("Essayé automatiquement quand l'adresse principale ne répond pas (hors du réseau domestique). Recommandé : un VPN type Tailscale/WireGuard vers la maison. ⚠️ N'exposez jamais le port 80 du SolarFlow directement sur Internet : son API locale n'a aucune authentification.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .formStyle(.grouped)
    }
}
