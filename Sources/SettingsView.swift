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
            SunSettingsTab()
                .tabItem { Label("Soleil", systemImage: "sun.horizon") }
            NotificationSettingsTab()
                .tabItem { Label("Notifications", systemImage: "bell.badge") }
            ControlSettingsTab()
                .tabItem { Label("Contrôle", systemImage: "slider.horizontal.3") }
            RemoteSettingsTab()
                .tabItem { Label("Distant", systemImage: "network") }
            GeneralSettingsTab()
                .tabItem { Label("Général", systemImage: "gearshape") }
        }
        .frame(width: 500)
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
                if discovery.hasSearched, !discovery.isSearching, discovery.devices.isEmpty {
                    Label {
                        Text("Aucun appareil trouvé. Vérifiez que le SolarFlow est sur le même réseau, et que son API locale est active (app Zendure : ajouter un HEMS puis le quitter).")
                            .fixedSize(horizontal: false, vertical: true)
                    } icon: {
                        Image(systemName: "magnifyingglass")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
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

// MARK: - Soleil

private struct SunSettingsTab: View {
    @AppStorage("sunLatitude") private var sunLatitude: Double = 0
    @AppStorage("sunLongitude") private var sunLongitude: Double = 0
    @AppStorage("sunPeakWatts") private var sunPeakWatts: Double = 0
    @AppStorage(PanelArrayStore.key) private var arraysJSON: String = ""
    @State private var arrays: [PanelArray] = []
    @State private var loaded = false

    var body: some View {
        Form {
            Section("Position") {
                TextField("Latitude", value: $sunLatitude, format: .number.precision(.fractionLength(0...5)))
                TextField("Longitude", value: $sunLongitude, format: .number.precision(.fractionLength(0...5)))
                UseMacLocationButton()
                Text("Sert aux éphémérides de la fenêtre Soleil (lever, coucher, élévation). Jamais transmise.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("Champs de panneaux") {
                ForEach(Array(arrays.enumerated()), id: \.element.id) { index, array in
                    PanelArrayEditor(array: binding(for: array.id), index: index) {
                        arrays.removeAll { $0.id == array.id }
                    }
                    if index < arrays.count - 1 { Divider() }
                }
                HStack {
                    Button("Ajouter un champ", systemImage: "plus") {
                        arrays.append(PanelArray(peakWatts: 400,
                                                 azimuth: 180,
                                                 tilt: 30))
                    }
                    Spacer()
                    if arrays.isEmpty == false {
                        Text("Total : \(Format.watts(arrays.reduce(0) { $0 + $1.peakWatts })) crête")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
                Text("Un champ par orientation de toiture. Azimut : 0° = nord, 90° = est, 180° = plein sud, 270° = ouest. Inclinaison : 0° à plat, 30° pour une toiture courante, 90° en façade. La fenêtre Soleil en déduit l'incidence du soleil sur chaque champ, son productible ciel clair et sa meilleure heure.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .formStyle(.grouped)
        .onAppear {
            guard loaded == false else { return }
            arrays = PanelArrayStore.load()
            loaded = true
        }
        .onChange(of: arrays) {
            guard loaded else { return }
            arraysJSON = PanelArrayStore.encode(arrays)
            // La clé historique reste le total installé : elle sert de repli et
            // reste lisible par les versions antérieures de l'app.
            sunPeakWatts = arrays.reduce(0) { $0 + $1.peakWatts }
        }
    }

    /// Liaison par identité plutôt que par indice : la suppression d'un champ
    /// ne peut pas faire écrire une ligne à côté.
    private func binding(for id: UUID) -> Binding<PanelArray> {
        Binding(
            get: { arrays.first { $0.id == id } ?? PanelArray(peakWatts: 0) },
            set: { updated in
                guard let index = arrays.firstIndex(where: { $0.id == id }) else { return }
                arrays[index] = updated
            }
        )
    }
}

/// Éditeur d'un champ de panneaux : nom libre, puissance crête, azimut (avec
/// son libellé cardinal) et inclinaison.
private struct PanelArrayEditor: View {
    @Binding var array: PanelArray
    var index: Int
    var remove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                PanelGlyph(color: ArrayPalette.color(index))
                    .frame(width: 18, height: 14)
                TextField("Nom", text: $array.name, prompt: Text("Champ \(index + 1)"))
                    .textFieldStyle(.roundedBorder)
                TextField("Wc", value: $array.peakWatts, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 74)
                    .monospacedDigit()
                Button(role: .destructive) { remove() } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .help(Text("Supprimer ce champ"))
            }
            Slider(value: $array.azimuth, in: 0...360, step: 5)
            Text("Azimut \(Int(array.azimuth.rounded()))° — \(Cardinal.label(azimuth: array.azimuth))")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
            Slider(value: $array.tilt, in: 0...90, step: 1)
            Text("Inclinaison \(Int(array.tilt.rounded()))°")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
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
            Section("Économies") {
                TextField("Prix du kWh (€)", value: $monitor.kwhPrice, format: .number.precision(.fractionLength(0...4)))
                TextField("Facteur CO₂ (g/kWh)", value: $monitor.co2Factor, format: .number)
                Text("Servent aux estimations « € économisés » et « CO₂ évité » du tableau de bord.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            PermissionsSection()
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
            Section("Notifications optionnelles") {
                Toggle("Batterie pleine", isOn: $monitor.notifyFullBattery)
                Toggle("Tirage réseau alors que le solaire produit", isOn: $monitor.notifyGridDraw)
                Toggle("Record de production battu", isOn: $monitor.notifyDailyRecord)
                Text("Batterie pleine : au plafond de charge configuré. Tirage réseau : > 50 W depuis le réseau avec > 100 W de solaire (au plus une fois par heure). Record : dès que la production du jour dépasse le meilleur jour connu.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Section("Alertes de panne") {
                Toggle("Appareil injoignable", isOn: $monitor.notifyUnreachable)
                if monitor.notifyUnreachable {
                    Slider(value: $monitor.unreachableMinutes, in: 5...60, step: 5) {
                        Text("Délai")
                    } minimumValueLabel: {
                        Text(verbatim: "5 min")
                    } maximumValueLabel: {
                        Text(verbatim: "60 min")
                    }
                    HStack(spacing: 4) {
                        Text("Notification après")
                        Text(verbatim: "\(Int(monitor.unreachableMinutes)) min")
                        Text("sans réponse — l'icône de la barre de menu passe aussi en ⚠️")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                Toggle("Production nulle en plein jour", isOn: $monitor.notifyNoProduction)
                Text("Alerte quand le SolarFlow répond mais ne produit ni n'injecte rien pendant 30 min alors que le soleil est à plus de 20° (nécessite la position configurée dans l'onglet Soleil) — signe d'un défaut ou d'une batterie pleine sans exutoire.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Contrôle

private struct ControlSettingsTab: View {
    @EnvironmentObject var monitor: Monitor
    @State private var acMode = 2
    @State private var outputLimit: Double = 800
    @State private var inputLimit: Double = 1200
    @State private var seeded = false
    @State private var sending = false
    @State private var status: String?
    @State private var statusOK = false
    @State private var pendingZero: [String: Any]?
    @State private var confirmZero = false

    var body: some View {
        Form {
            Section("Contrôle de la batterie") {
                Text("⚠️ Ces commandes pilotent réellement la batterie (POST /properties/write).")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)

                Picker("Mode AC", selection: $acMode) {
                    Text("Charge (depuis le secteur)").tag(1)
                    Text("Décharge (vers la maison)").tag(2)
                }
                HStack {
                    Spacer()
                    Button("Appliquer le mode") { send(["acMode": acMode]) }
                        .disabled(sending || monitor.state == nil)
                }

                VStack(alignment: .leading) {
                    Slider(value: $outputLimit, in: 0...2400, step: 50) {
                        Text("Limite de sortie")
                    }
                    HStack {
                        Text(verbatim: "\(Int(outputLimit)) W").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                        Spacer()
                        Button("Appliquer la limite de sortie") { send(["outputLimit": Int(outputLimit)]) }
                            .disabled(sending || monitor.state == nil)
                    }
                }

                VStack(alignment: .leading) {
                    Slider(value: $inputLimit, in: 0...2400, step: 100) {
                        Text("Limite de charge")
                    }
                    HStack {
                        Text(verbatim: "\(Int(inputLimit)) W").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                        Spacer()
                        Button("Appliquer la limite de charge") { send(["inputLimit": Int(inputLimit)]) }
                            .disabled(sending || monitor.state == nil)
                    }
                }

                if let status {
                    Label(status, systemImage: statusOK ? "checkmark.circle" : "xmark.circle")
                        .foregroundStyle(statusOK ? .green : .red)
                        .font(.callout)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .formStyle(.grouped)
        .onAppear { seedFromDevice() }
        .alert("Mettre la limite à 0 W ?", isPresented: $confirmZero) {
            Button("Confirmer 0 W", role: .destructive) {
                if let props = pendingZero { send(props) }
                pendingZero = nil
            }
            Button("Annuler", role: .cancel) { pendingZero = nil }
        } message: {
            Text("Une limite à 0 W coupe complètement ce flux sur la batterie.")
        }
    }

    /// Pré-remplit les contrôles avec les valeurs actuelles du device (une fois).
    private func seedFromDevice() {
        guard !seeded, let state = monitor.state else { return }
        seeded = true
        if let mode = state.acMode, mode == 1 || mode == 2 { acMode = mode }
        if let output = state.outputLimit { outputLimit = min(max(output, 0), 2400) }
        if let input = state.inputLimit { inputLimit = min(max(input, 0), 2400) }
    }

    private func send(_ properties: [String: Any]) {
        // Une limite à 0 W coupe réellement la charge ou la sortie : confirmation.
        let zeroesSomething = properties.contains { ($0.key == "outputLimit" || $0.key == "inputLimit") && ($0.value as? Int) == 0 }
        if zeroesSomething, pendingZero == nil {
            pendingZero = properties
            confirmZero = true
            return
        }
        sending = true
        status = nil
        Task {
            do {
                try await monitor.writeProperties(properties)
                statusOK = true
                status = String(localized: "Commande envoyée.")
            } catch {
                statusOK = false
                status = error.localizedDescription
            }
            // Anti double-envoi : les boutons restent inactifs 2 s après la réponse.
            try? await Task.sleep(for: .seconds(2))
            sending = false
        }
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
                TextField("Serveur d'historique 24/7", text: $monitor.historyServer, prompt: Text(verbatim: "minicorse.local:8899"))
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
                Text("Collecteur optionnel qui tourne sur un Mac toujours allumé (voir Scripts/collector) : il enregistre la production 24 h/24 et l'app affiche alors un historique complet, même quand ce Mac est éteint.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Essayé automatiquement quand l'adresse principale ne répond pas (hors du réseau domestique). Recommandé : un VPN type Tailscale/WireGuard vers la maison. ⚠️ N'exposez jamais le port 80 du SolarFlow directement sur Internet : son API locale n'a aucune authentification.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .formStyle(.grouped)
    }
}
