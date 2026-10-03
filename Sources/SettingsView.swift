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
    /// Résultat du dernier test, par hôte.
    @State private var testResults: [String: (ok: Bool, text: String)] = [:]
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
            Section("Appareils SolarFlow") {
                ForEach(Array(monitor.deviceHosts.enumerated()), id: \.offset) { index, _ in
                    HStack {
                        TextField("Adresse IP ou nom d'hôte", text: hostBinding(index),
                                  prompt: Text("192.168.1.xx ou Zendure-….local"))
                            .textFieldStyle(.roundedBorder)
                            .autocorrectionDisabled()
                        if monitor.deviceHosts.count > 1 {
                            Button {
                                monitor.deviceHosts.remove(at: index)
                                testResults = [:]
                            } label: {
                                Image(systemName: "minus.circle")
                            }
                            .buttonStyle(.borderless)
                            .help("Retirer cet appareil")
                        }
                    }
                    if let result = testResults[monitor.deviceHosts[index].trimmingCharacters(in: .whitespacesAndNewlines)] {
                        Label(result.text, systemImage: result.ok ? "checkmark.circle" : "xmark.circle")
                            .foregroundStyle(result.ok ? .green : .red)
                            .font(.callout)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                HStack {
                    Button("Ajouter un appareil") { monitor.deviceHosts.append("") }
                    Button(discovery.isSearching ? "Recherche…" : "Rechercher sur le réseau") {
                        discovery.start()
                    }
                    .disabled(discovery.isSearching)

                    Button(testing ? "Test…" : "Tester") { runTest() }
                        .disabled(testing || monitor.configuredHosts.isEmpty)
                }

                // Le Smart CT s'annonce aussi en Bonjour (même préfixe
                // « Zendure ») : il a sa propre section, on l'écarte ici.
                ForEach(discovery.devices.filter { !$0.name.lowercased().contains("smartmeter") }) { device in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(device.name).font(.callout)
                            Text(device.host).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if monitor.configuredHosts.contains(device.host) {
                            Text("Ajouté").font(.caption).foregroundStyle(.secondary)
                        } else {
                            Button("Ajouter") { add(host: device.host) }
                        }
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

                Text("Tous les appareils sont interrogés à chaque rafraîchissement : l'app affiche le total de l'installation et le détail par appareil. L'hôte de secours (onglet Réseau) s'applique au premier.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .onAppear {
                // Toujours au moins une ligne à remplir (première installation).
                if monitor.deviceHosts.isEmpty { monitor.deviceHosts = [""] }
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

    /// Liaison sûre vers une ligne de la liste (une suppression peut
    /// invalider l'index pendant que SwiftUI relit encore la ligne).
    private func hostBinding(_ index: Int) -> Binding<String> {
        Binding(
            get: { monitor.deviceHosts.indices.contains(index) ? monitor.deviceHosts[index] : "" },
            set: { value in
                guard monitor.deviceHosts.indices.contains(index) else { return }
                monitor.deviceHosts[index] = value
            }
        )
    }

    /// Ajoute un hôte découvert : remplit la première ligne vide s'il y en a.
    private func add(host: String) {
        if let empty = monitor.deviceHosts.firstIndex(where: { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
            monitor.deviceHosts[empty] = host
        } else {
            monitor.deviceHosts.append(host)
        }
    }

    private func runTest() {
        testing = true
        testResults = [:]
        let hosts = monitor.configuredHosts
        Task {
            for host in hosts {
                let result = await monitor.test(host: host)
                switch result {
                case .success(let state):
                    var parts = [String(localized: "Connecté"),
                                 Format.watts(state.solarInputPower) + " " + String(localized: "solaire")]
                    if let soc = state.electricLevel {
                        parts.append("\(Int(soc)) % " + String(localized: "batterie"))
                    }
                    if let sn = state.serialNumber { parts.append("SN \(sn)") }
                    testResults[host] = (true, parts.joined(separator: " — "))
                case .failure(let error):
                    testResults[host] = (false, error.localizedDescription)
                }
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
                LabeledContent("Appareils", value: monitor.cloudDevices.map(\.displayName).joined(separator: ", "))
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
    @State private var reserve: Double = 20
    @State private var chargeMax: Double = 100
    @State private var feedIn = 2
    @State private var seeded = false
    @State private var sending = false
    @State private var status: String?
    @State private var statusOK = false
    /// Commande en attente de confirmation (limite à 0 W, injection autorisée).
    @State private var pending: [String: Any]?
    @State private var confirmZero = false
    @State private var confirmFeedIn = false
    @State private var confirmReserve = false
    /// Cible : un appareil précis, ou tous (`allTag`) — jamais l'agrégat.
    @State private var targetID: String?
    private static let allTag = "*all*"

    /// Appareils pilotables : ont répondu, avec un SN et un hôte connus.
    private var controllable: [DeviceReading] {
        monitor.devices.filter { $0.state?.serialNumber != nil && $0.host != nil }
    }

    /// Appareils visés par la prochaine commande.
    private var targets: [DeviceReading] {
        if controllable.count == 1 { return controllable }
        if targetID == Self.allTag { return controllable }
        return controllable.filter { $0.id == targetID }
    }

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
            Section {
                Text("⚠️ Ces commandes pilotent réellement la batterie (POST /properties/write).")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)

                if controllable.count > 1 {
                    Picker("Appareil", selection: $targetID) {
                        Text("Choisir…").tag(String?.none)
                        Text("Tous les appareils").tag(String?.some(Self.allTag))
                        ForEach(Array(controllable.enumerated()), id: \.element.id) { index, device in
                            Text(verbatim: "SolarFlow \(index + 1) — \(device.name)").tag(String?.some(device.id))
                        }
                    }
                    .onChange(of: targetID) { seeded = false; seedFromDevice() }
                }
                ForEach(targets) { device in
                    if let state = device.state {
                        Text(currentSummary(device: device, state: state))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("Réserve, charge et injection") {
                VStack(alignment: .leading) {
                    Slider(value: $reserve, in: 0...50, step: 5) {
                        Text("Réserve")
                    }
                    HStack {
                        Text("La batterie ne descend pas sous \(Int(reserve)) %")
                            .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                        Spacer()
                        Button("Appliquer la réserve") { send(["minSoc": Int(reserve * 10)]) }
                            .disabled(sending || targets.isEmpty)
                    }
                }

                VStack(alignment: .leading) {
                    Slider(value: $chargeMax, in: 70...100, step: 5) {
                        Text("Charge maximale")
                    }
                    HStack {
                        Text("Charge jusqu'à \(Int(chargeMax)) %")
                            .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                        Spacer()
                        Button("Appliquer la charge maximale") { send(["socSet": Int(chargeMax * 10)]) }
                            .disabled(sending || targets.isEmpty)
                    }
                }

                Picker("Injection du surplus", selection: $feedIn) {
                    Text("Autorisée — le surplus part sur le réseau").tag(1)
                    Text("Interdite — production bridée batterie pleine").tag(2)
                }
                HStack {
                    Spacer()
                    Button("Appliquer l'injection") { send(["gridReverse": feedIn]) }
                        .disabled(sending || targets.isEmpty)
                }

                Text("Valeurs envoyées par l'API locale. En smartMode (cas courant), l'appareil ne les écrit pas en mémoire permanente : elles sont perdues à son redémarrage. Pour un réglage durable, faites-le aussi dans l'app Zendure.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Section("Mode et puissances") {
                Picker("Mode AC", selection: $acMode) {
                    Text("Charge (depuis le secteur)").tag(1)
                    Text("Décharge (vers la maison)").tag(2)
                }
                HStack {
                    Spacer()
                    Button("Appliquer le mode") { send(["acMode": acMode]) }
                        .disabled(sending || targets.isEmpty)
                }

                VStack(alignment: .leading) {
                    Slider(value: $outputLimit, in: 0...2400, step: 50) {
                        Text("Limite de sortie")
                    }
                    HStack {
                        Text(verbatim: "\(Int(outputLimit)) W").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                        Spacer()
                        Button("Appliquer la limite de sortie") { send(["outputLimit": Int(outputLimit)]) }
                            .disabled(sending || targets.isEmpty)
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
                            .disabled(sending || targets.isEmpty)
                    }
                }
                Text("Avec un Smart CT, la régulation Zendure ajuste elle-même la limite de sortie en continu : une valeur imposée ici risque d'être écrasée en quelques secondes.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let status {
                Label(status, systemImage: statusOK ? "checkmark.circle" : "xmark.circle")
                    .foregroundStyle(statusOK ? .green : .red)
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .formStyle(.grouped)
        .onAppear { seedFromDevice() }
        .alert("Mettre la limite à 0 W ?", isPresented: $confirmZero) {
            Button("Confirmer 0 W", role: .destructive) { confirmPending() }
            Button("Annuler", role: .cancel) { pending = nil }
        } message: {
            Text("Une limite à 0 W coupe complètement ce flux sur la batterie.")
        }
        .alert("Recharger depuis le réseau ?", isPresented: $confirmReserve) {
            Button("Appliquer quand même", role: .destructive) { confirmPending() }
            Button("Annuler", role: .cancel) { pending = nil }
        } message: {
            Text("Au moins un appareil est sous cette réserve : il va se recharger immédiatement DEPUIS LE RÉSEAU pour l'atteindre, à pleine puissance (environ 2,4 kW par SolarFlow). Pour l'éviter, appliquez la réserve quand la batterie est au-dessus.")
        }
        .alert("Autoriser l'injection sur le réseau ?", isPresented: $confirmFeedIn) {
            Button("Autoriser") { confirmPending() }
            Button("Annuler", role: .cancel) { pending = nil }
        } message: {
            Text("Batterie pleine, le surplus partira sur le réseau public. En France, injecter suppose une convention d'autoconsommation avec Enedis (CACSI), et un contrat d'achat pour être rémunéré.")
        }
    }

    /// « SolarFlow 2 : réserve 10 % · charge max 100 % · injection interdite »
    private func currentSummary(device: DeviceReading, state: DeviceState) -> String {
        let index = (controllable.firstIndex { $0.id == device.id } ?? 0) + 1
        var parts: [String] = []
        if let socMin = state.socMin { parts.append(String(localized: "réserve \(Int(socMin)) %")) }
        if let socMax = state.socMax { parts.append(String(localized: "charge max \(Int(socMax)) %")) }
        if let allowed = state.feedInAllowed {
            parts.append(allowed ? String(localized: "injection autorisée") : String(localized: "injection interdite"))
        }
        let prefix = controllable.count > 1 ? "SolarFlow \(index) : " : ""
        return prefix + (parts.isEmpty ? "—" : parts.joined(separator: " · "))
    }

    /// Pré-remplit les contrôles avec les valeurs actuelles du premier appareil visé.
    private func seedFromDevice() {
        guard !seeded, let state = targets.first?.state else { return }
        seeded = true
        if let mode = state.acMode, mode == 1 || mode == 2 { acMode = mode }
        if let output = state.outputLimit { outputLimit = min(max(output, 0), 2400) }
        if let input = state.inputLimit { inputLimit = min(max(input, 0), 2400) }
        if let socMin = state.socMin { reserve = min(max((socMin / 5).rounded() * 5, 0), 50) }
        if let socMax = state.socMax { chargeMax = min(max((socMax / 5).rounded() * 5, 70), 100) }
        if let reverse = state.gridReverse { feedIn = reverse == 1 ? 1 : 2 }
    }

    private func confirmPending() {
        guard let props = pending else { return }
        perform(props)
        pending = nil
    }

    private func send(_ properties: [String: Any]) {
        // Une limite à 0 W coupe réellement un flux, et autoriser l'injection
        // engage vis-à-vis du réseau : confirmation dans les deux cas.
        let zeroesSomething = properties.contains { ($0.key == "outputLimit" || $0.key == "inputLimit") && ($0.value as? Int) == 0 }
        let enablesFeedIn = (properties["gridReverse"] as? Int) == 1
        let reserveAboveLevel = (properties["minSoc"] as? Int).map { tenths in
            targets.contains { $0.state?.reserveWouldChargeFromGrid(Double(tenths) / 10) == true }
        } ?? false
        if zeroesSomething || enablesFeedIn || reserveAboveLevel {
            pending = properties
            if reserveAboveLevel { confirmReserve = true }
            else if enablesFeedIn { confirmFeedIn = true }
            else { confirmZero = true }
            return
        }
        perform(properties)
    }

    /// Envoie la commande à chaque appareil visé, l'un après l'autre ; le
    /// premier échec interrompt la série et dit où elle s'est arrêtée.
    private func perform(_ properties: [String: Any]) {
        let ids = targets.map(\.id)
        guard !ids.isEmpty else { return }
        sending = true
        status = nil
        Task {
            var done = 0
            do {
                for id in ids {
                    try await monitor.writeProperties(properties, to: id)
                    done += 1
                }
                statusOK = true
                status = ids.count > 1
                    ? String(localized: "Commande envoyée aux \(ids.count) appareils.")
                    : String(localized: "Commande envoyée.")
            } catch {
                statusOK = false
                status = ids.count > 1
                    ? String(localized: "Échec après \(done)/\(ids.count) appareil(s) : \(error.localizedDescription)")
                    : error.localizedDescription
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
