import SwiftUI

/// Fenêtre de réglages en onglets (style Réglages Système) :
/// Appareil / Affichage / Soleil / Notifications / Contrôle / Réseau / Général.
/// L'onglet Appareil ne porte que la source de données ; les équipements
/// annexes (Smart CT, hôte de secours, collecteur) vivent dans Réseau.
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
            NetworkSettingsTab()
                .tabItem { Label("Réseau", systemImage: "network") }
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
            Section("Source des données") {
                Picker("Source", selection: $monitor.connectionMode) {
                    ForEach(ConnectionMode.allCases) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                Text(monitor.connectionMode == .local
                     ? "Lecture directe sur le SolarFlow via le réseau local — recommandé : plus rapide et sans dépendre d'Internet."
                     : "Données via les serveurs Zendure (MQTT temps réel) — utile quand l'API locale de l'appareil est inaccessible. Lecture seule.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Toggle("Basculer automatiquement", isOn: $monitor.autoSwitchMode)
                Text("Passe en Cloud quand le SolarFlow ne répond plus en local (typiquement hors du réseau domestique) et revient en local dès qu'il répond à nouveau. Nécessite une Cloud Key enregistrée.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if monitor.connectionMode == .cloud {
                CloudSettingsSection()
            } else {
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

// MARK: - Smart CT

/// Section Smart CT de l'onglet Appareil : le compteur en tableau (mesure du
/// soutirage réseau de la maison) est interrogé en local quel que soit le
/// mode — le cloud Zendure ne relaie pas ses mesures.
private struct SmartCTSection: View {
    @EnvironmentObject var monitor: Monitor
    @StateObject private var discovery = DeviceDiscovery()
    @State private var testing = false
    @State private var testResult: String?
    @State private var testOK = false

    var body: some View {
        Section("Compteur Smart CT (optionnel)") {
            TextField("Hôte du Smart CT", text: $monitor.ctHost,
                      prompt: Text(verbatim: "Zendure-smartMeter3CT-….local"))
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()

            HStack {
                Button(discovery.isSearching ? "Recherche…" : "Détecter sur le réseau") {
                    discovery.start()
                }
                .disabled(discovery.isSearching)
                Button(testing ? "Test…" : "Tester") { runTest() }
                    .disabled(testing || monitor.ctHost.isEmpty)
            }

            ForEach(discovery.devices.filter { $0.name.lowercased().contains("smartmeter") || $0.name.lowercased().contains("3ct") }) { device in
                HStack {
                    VStack(alignment: .leading) {
                        Text(device.name).font(.callout)
                        Text(device.host).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Utiliser") { monitor.ctHost = device.host }
                }
            }

            if let testResult {
                Label(testResult, systemImage: testOK ? "checkmark.circle" : "xmark.circle")
                    .foregroundStyle(testOK ? .green : .red)
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text("Compteur au tableau électrique : mesure le soutirage réseau réel de la maison, affiché dans le schéma de flux. Interrogé en local uniquement (le cloud ne relaie pas ses mesures).")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func runTest() {
        testing = true
        testResult = nil
        let host = monitor.ctHost
        Task {
            let result = await monitor.testSmartCT(host: host)
            switch result {
            case .success(let report):
                testOK = true
                testResult = String(localized: "Connecté — soutirage réseau : ") + Format.watts(report.totalPower)
            case .failure(let error):
                testOK = false
                testResult = error.localizedDescription
            }
            testing = false
        }
    }
}

// MARK: - Cloud

/// Section Cloud de l'onglet Appareil : saisie du Cloud Key (trousseau),
/// statut de la session MQTT et choix de l'appareil suivi.
private struct CloudSettingsSection: View {
    @EnvironmentObject var monitor: Monitor
    @State private var cloudKey = ""
    @State private var loaded = false
    @State private var testing = false
    @State private var testResult: String?
    @State private var testOK = false

    var body: some View {
        Section("Cloud Zendure") {
            SecureField("Authorization Cloud Key", text: $cloudKey, prompt: Text("Coller le jeton copié depuis l'app Zendure"))
                .textFieldStyle(.roundedBorder)

            HStack {
                Button(testing ? "Test…" : "Tester la clé") { runTest() }
                    .disabled(testing || cloudKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Button("Enregistrer et connecter") {
                    monitor.saveCloudKey(cloudKey)
                }
                .disabled(cloudKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            if let testResult {
                Label(testResult, systemImage: testOK ? "checkmark.circle" : "xmark.circle")
                    .foregroundStyle(testOK ? .green : .red)
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
            }

            phaseRow

            if monitor.cloudDevices.count > 1 {
                Picker("Appareil suivi", selection: $monitor.cloudDeviceKey) {
                    ForEach(monitor.cloudDevices) { device in
                        Text(device.displayName).tag(device.deviceKey)
                    }
                }
            } else if let device = monitor.cloudDevices.first {
                LabeledContent("Appareil", value: device.displayName)
            }

            Text("Clé à copier depuis l'app Zendure (Profil → « Authorization Cloud Key »), avec le compte principal. Conservée dans le trousseau macOS.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .onAppear {
            guard !loaded else { return }
            loaded = true
            cloudKey = monitor.loadCloudKey() ?? ""
        }
    }

    @ViewBuilder
    private var phaseRow: some View {
        switch monitor.cloudPhase {
        case .notConfigured:
            Label("Aucune clé enregistrée", systemImage: "key.slash")
                .foregroundStyle(.secondary)
                .font(.callout)
        case .fetchingDevices:
            Label("Connexion au compte Zendure…", systemImage: "arrow.triangle.2.circlepath")
                .foregroundStyle(.secondary)
                .font(.callout)
        case .connectingMQTT:
            Label("Connexion au flux temps réel…", systemImage: "arrow.triangle.2.circlepath")
                .foregroundStyle(.secondary)
                .font(.callout)
        case .live:
            Label("Connecté — données en temps réel", systemImage: "checkmark.circle")
                .foregroundStyle(.green)
                .font(.callout)
        case .failed(let message):
            Label(message, systemImage: "xmark.circle")
                .foregroundStyle(.red)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func runTest() {
        testing = true
        testResult = nil
        let token = cloudKey
        Task {
            let result = await monitor.testCloudKey(token)
            switch result {
            case .success(let devices):
                testOK = true
                testResult = String(localized: "Clé valide — \(devices.count) appareil(s) : ")
                    + devices.map(\.displayName).joined(separator: ", ")
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
    @AppStorage("showSolarCard") private var showSolarCard = true
    @AppStorage("showBatteryCard") private var showBatteryCard = true
    @AppStorage("showFlowsCard") private var showFlowsCard = true
    @AppStorage("showConsumptionCard") private var showConsumptionCard = true
    @AppStorage("showHistoryCard") private var showHistoryCard = true

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
            Section("Cartes du panneau") {
                Toggle("Production solaire", isOn: $showSolarCard)
                Toggle("Batterie", isOn: $showBatteryCard)
                Toggle("Flux", isOn: $showFlowsCard)
                Toggle("Consommation maison", isOn: $showConsumptionCard)
                Toggle("Historique", isOn: $showHistoryCard)
                Text("Chaque carte visible peut aussi être repliée d'un clic sur son en-tête dans le panneau — repliée, elle n'affiche que sa valeur clé.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
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

/// Interne (et non `private` comme les autres onglets) pour que le harnais de
/// capture du guide puisse la rendre hors de l'app.
struct SunSettingsTab: View {
    @AppStorage("sunLatitude") private var sunLatitude: Double = 0
    @AppStorage("sunLongitude") private var sunLongitude: Double = 0

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
            PanelArraysSection()
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
        if monitor.connectionMode == .cloud {
            Form {
                Section("Contrôle de la batterie") {
                    Label {
                        Text("Le contrôle n'est disponible qu'en mode API locale — le mode Cloud est en lecture seule.")
                            .fixedSize(horizontal: false, vertical: true)
                    } icon: {
                        Image(systemName: "lock")
                    }
                    .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
        } else {
            controlForm
        }
    }

    private var controlForm: some View {
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

// MARK: - Réseau

/// Équipements et accès réseau annexes : compteur Smart CT, hôte de secours
/// (mode local) et collecteur d'historique 24/7.
private struct NetworkSettingsTab: View {
    @EnvironmentObject var monitor: Monitor

    var body: some View {
        Form {
            SmartCTSection()
            Section("Accès distant (optionnel)") {
                if monitor.connectionMode == .local {
                    TextField("Hôte de secours", text: $monitor.fallbackHost, prompt: Text("ex. 100.x.y.z (IP Tailscale)"))
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                    Text("Essayé quand l'adresse principale ne répond pas (VPN type Tailscale recommandé). ⚠️ Ne jamais exposer le SolarFlow directement sur Internet : son API locale n'a aucune authentification.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("Hôte de secours : uniquement en mode API locale (le mode Cloud est déjà accessible partout).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Section("Historique 24/7 (optionnel)") {
                TextField("Serveur d'historique", text: $monitor.historyServer, prompt: Text(verbatim: "minicorse.local:8899"))
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
                Text("Collecteur optionnel sur un Mac toujours allumé (voir Scripts/collector) : l'app affiche alors un historique complet, même quand ce Mac-ci est éteint.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .formStyle(.grouped)
    }
}
