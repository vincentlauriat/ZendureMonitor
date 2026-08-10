import AppKit
import Foundation
import SwiftUI
import UserNotifications
import WidgetKit

/// Thème d'apparence choisi par l'utilisateur.
enum AppearanceMode: String, CaseIterable, Identifiable {
    case auto, dark, light
    var id: String { rawValue }

    var label: LocalizedStringKey {
        switch self {
        case .auto: return "Auto"
        case .dark: return "Sombre"
        case .light: return "Clair"
        }
    }

    func apply() {
        switch self {
        case .auto: NSApp.appearance = nil
        case .dark: NSApp.appearance = NSAppearance(named: .darkAqua)
        case .light: NSApp.appearance = NSAppearance(named: .aqua)
        }
    }
}

/// Source des données : API locale du SolarFlow ou cloud Zendure (MQTT).
enum ConnectionMode: String, CaseIterable, Identifiable {
    case local, cloud
    var id: String { rawValue }

    var label: LocalizedStringKey {
        switch self {
        case .local: return "API locale"
        case .cloud: return "Cloud Zendure"
        }
    }
}

/// Solar energy produced on one day (persisted in UserDefaults as `energyWh-<yyyy-MM-dd>`).
struct DayEnergy: Identifiable, Equatable {
    let day: String   // "2026-08-04"
    let date: Date
    let wh: Double
    var id: String { day }
}

@MainActor
final class Monitor: ObservableObject {
    @Published var state: DeviceState?
    @Published var lastError: String?
    /// True when the last successful poll went through the fallback host.
    @Published var usingFallback = false
    /// Échecs réseau ressemblant à un refus TCC « réseau local » (voir LocalNetworkHint).
    @Published var localNetworkDenied = false
    /// Solar energy produced today (Wh), integrated from the polls while the app runs.
    @Published var energyTodayWh: Double = 0
    /// Last days of production (oldest first, today included), for the history card.
    @Published var dailyEnergy: [DayEnergy] = []
    /// True when the history currently displayed comes from the 24/7 collector.
    @Published var historyFromServer = false
    /// Historiques glissants pour les sparklines (un point par poll réussi).
    @Published var solarHistory: [Double] = []
    @Published var homeHistory: [Double] = []
    @Published var flowHistory: [Double] = []
    private let historyCapacity = 180
    /// Courbe de production du jour : le max de chaque tranche de 5 min (288 max),
    /// persistée par jour (`solarCurve-<day>`) pour survivre aux relances.
    @Published var todayCurve: [Double] = []
    /// Pic de puissance solaire du jour (W), persisté (`peakW-<day>`).
    @Published var peakTodayW: Double = 0
    /// Part de la production du jour partie charger la batterie (Wh),
    /// persistée (`storedWh-<day>`) — voir EnergyMath.solarToBattery.
    @Published var storedTodayWh: Double = 0
    /// Énergie tirée du réseau aujourd'hui (Wh), persistée (`gridWh-<day>`).
    @Published var gridTodayWh: Double = 0

    // MARK: - Cloud mode

    /// Phase courante de la session cloud (pour l'UI des réglages).
    @Published var cloudPhase: CloudService.Phase = .notConfigured
    /// Appareils du compte cloud (deviceList) — en général un seul.
    @Published var cloudDevices: [ZendureDevice] = []
    /// Dernier état cloud fusionné de l'appareil suivi.
    private var cloudLatest: CloudDeviceState?
    private var cloudService: CloudService?
    /// Au-delà de cet âge, l'instantané cloud est considéré périmé (le poll
    /// getAll tourne à 60 s : 3 cycles manqués = vraie coupure).
    private static let cloudStaleAfter: TimeInterval = 180

    // MARK: - Settings (persisted)

    @Published var connectionMode: ConnectionMode {
        didSet {
            UserDefaults.standard.set(connectionMode.rawValue, forKey: "connectionMode")
            applyConnectionMode()
            scheduleRestart()
        }
    }
    /// Appareil cloud suivi (deviceKey) — vide tant que la liste n'est pas connue.
    @Published var cloudDeviceKey: String {
        didSet {
            UserDefaults.standard.set(cloudDeviceKey, forKey: "cloudDeviceKey")
            if cloudDeviceKey != oldValue { cloudLatest = nil }
        }
    }
    @Published var host: String {
        didSet { UserDefaults.standard.set(host, forKey: "deviceHost"); scheduleRestart() }
    }
    /// Hôte local du compteur Smart CT (optionnel) — mesure le soutirage
    /// réseau réel de la maison. Interrogé quel que soit le mode (le CT n'est
    /// pas relayé par le cloud : API locale uniquement).
    @Published var ctHost: String {
        didSet { UserDefaults.standard.set(ctHost, forKey: "ctHost") }
    }
    /// Dernière mesure du Smart CT — nil dès que le compteur ne répond plus
    /// (le schéma de flux repasse alors en « non mesuré »).
    @Published var ctReport: CTReport?
    /// Un Smart CT est-il configuré (hôte renseigné) ? Permet à l'interface de
    /// distinguer « pas de compteur » de « compteur injoignable » — typiquement
    /// à distance en mode Cloud, le CT n'étant lisible que sur le réseau local.
    var ctConfigured: Bool {
        !ctHost.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    /// Optional second host tried when the primary is unreachable (e.g. a
    /// Tailscale/VPN address for remote access).
    @Published var fallbackHost: String {
        didSet { UserDefaults.standard.set(fallbackHost, forKey: "fallbackHost") }
    }
    /// Optional 24/7 collector base host:port (Scripts/collector) — when set and
    /// reachable, the daily history and today's energy come from it instead of
    /// the local (Mac-uptime-bound) accumulation.
    @Published var historyServer: String {
        didSet { UserDefaults.standard.set(historyServer, forKey: "historyServer"); lastServerFetch = .distantPast }
    }
    @Published var pollInterval: Double {
        didSet { UserDefaults.standard.set(pollInterval, forKey: "pollInterval"); scheduleRestart() }
    }
    @Published var showSolarInBar: Bool {
        didSet { UserDefaults.standard.set(showSolarInBar, forKey: "showSolarInBar") }
    }
    @Published var showBatteryInBar: Bool {
        didSet { UserDefaults.standard.set(showBatteryInBar, forKey: "showBatteryInBar") }
    }
    @Published var showHomeInBar: Bool {
        didSet { UserDefaults.standard.set(showHomeInBar, forKey: "showHomeInBar") }
    }
    @Published var lowSocAlertEnabled: Bool {
        didSet {
            UserDefaults.standard.set(lowSocAlertEnabled, forKey: "lowSocAlertEnabled")
            if lowSocAlertEnabled { Self.requestNotificationAuthorization() }
            refreshNotificationsStatus()
        }
    }
    /// Alerte batterie activée mais notifications refusées par macOS.
    @Published var notificationsDenied = false
    @Published var lowSocThreshold: Double {
        didSet { UserDefaults.standard.set(lowSocThreshold, forKey: "lowSocThreshold") }
    }
    /// Prix du kWh (€) et facteur d'émission (g CO₂/kWh) pour les estimations.
    @Published var kwhPrice: Double {
        didSet { UserDefaults.standard.set(kwhPrice, forKey: "kwhPrice") }
    }
    @Published var co2Factor: Double {
        didSet { UserDefaults.standard.set(co2Factor, forKey: "co2Factor") }
    }
    /// Notifications optionnelles (opt-in).
    @Published var notifyFullBattery: Bool {
        didSet {
            UserDefaults.standard.set(notifyFullBattery, forKey: "notifyFullBattery")
            if notifyFullBattery { Self.requestNotificationAuthorization() }
        }
    }
    @Published var notifyGridDraw: Bool {
        didSet {
            UserDefaults.standard.set(notifyGridDraw, forKey: "notifyGridDraw")
            if notifyGridDraw { Self.requestNotificationAuthorization() }
        }
    }
    @Published var notifyDailyRecord: Bool {
        didSet {
            UserDefaults.standard.set(notifyDailyRecord, forKey: "notifyDailyRecord")
            if notifyDailyRecord { Self.requestNotificationAuthorization() }
        }
    }
    /// Alertes de panne (activées par défaut — incident du 2026-08-07 : le
    /// SolarFlow est tombé en défaut puis hors réseau sans que l'app ne dise rien).
    @Published var notifyUnreachable: Bool {
        didSet {
            UserDefaults.standard.set(notifyUnreachable, forKey: "notifyUnreachable")
            if notifyUnreachable { Self.requestNotificationAuthorization() }
        }
    }
    /// Minutes de silence réseau tolérées avant l'alerte « injoignable ».
    @Published var unreachableMinutes: Double {
        didSet {
            UserDefaults.standard.set(unreachableMinutes, forKey: "unreachableMinutes")
            watchdog.unreachableAfter = unreachableMinutes * 60
        }
    }
    @Published var notifyNoProduction: Bool {
        didSet {
            UserDefaults.standard.set(notifyNoProduction, forKey: "notifyNoProduction")
            if notifyNoProduction { Self.requestNotificationAuthorization() }
        }
    }
    /// Vrai quand l'appareil est injoignable au-delà du seuil — la barre de
    /// menu passe en ⚠️ (voir MenuBarLabel).
    @Published var offlineAlert = false
    @Published var appearance: AppearanceMode {
        didSet {
            UserDefaults.standard.set(appearance.rawValue, forKey: "appearanceMode")
            appearance.apply()
        }
    }

    private var pollTask: Task<Void, Never>?
    private var restartDebounce: Task<Void, Never>?
    /// Dernier essai de l'hôte principal quand on est passé sur le secours.
    private var lastPrimaryAttempt: Date = .distantPast
    private let session: URLSession
    /// Logique pure des cumuls du jour (Wh, courbe, pic) — voir DailyAccumulator.
    private var accumulator: DailyAccumulator
    private var energyDay: String
    private var lowSocNotified = false
    /// Host of the last successful poll — control commands go there.
    private var activeHost: String?
    private var lastWidgetReload: Date = .distantPast
    private var lastServerFetch: Date = .distantPast
    private var lastCurveSave: Date = .distantPast
    private var fullBatteryNotified = false
    private var lastGridDrawNotify: Date = .distantPast
    private var recordNotifiedDay = ""
    /// Détection de panne (injoignable / production nulle en plein jour).
    private var watchdog = OutageWatchdog()

    init() {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 5
        config.waitsForConnectivity = false
        session = URLSession(configuration: config)

        let defaults = UserDefaults.standard
        connectionMode = ConnectionMode(rawValue: defaults.string(forKey: "connectionMode") ?? "local") ?? .local
        cloudDeviceKey = defaults.string(forKey: "cloudDeviceKey") ?? ""
        host = defaults.string(forKey: "deviceHost") ?? ""
        ctHost = defaults.string(forKey: "ctHost") ?? ""
        fallbackHost = defaults.string(forKey: "fallbackHost") ?? ""
        historyServer = defaults.string(forKey: "historyServer") ?? ""
        let saved = defaults.double(forKey: "pollInterval")
        pollInterval = saved >= 2 ? saved : 5
        showSolarInBar = defaults.object(forKey: "showSolarInBar") as? Bool ?? true
        showBatteryInBar = defaults.object(forKey: "showBatteryInBar") as? Bool ?? false
        showHomeInBar = defaults.object(forKey: "showHomeInBar") as? Bool ?? false
        lowSocAlertEnabled = defaults.object(forKey: "lowSocAlertEnabled") as? Bool ?? true
        let threshold = defaults.double(forKey: "lowSocThreshold")
        lowSocThreshold = threshold > 0 ? threshold : 15

        appearance = AppearanceMode(rawValue: defaults.string(forKey: "appearanceMode") ?? "auto") ?? .auto

        kwhPrice = defaults.object(forKey: "kwhPrice") as? Double ?? 0.20
        co2Factor = defaults.object(forKey: "co2Factor") as? Double ?? 55
        notifyFullBattery = defaults.bool(forKey: "notifyFullBattery")
        notifyGridDraw = defaults.bool(forKey: "notifyGridDraw")
        notifyDailyRecord = defaults.bool(forKey: "notifyDailyRecord")
        notifyUnreachable = defaults.object(forKey: "notifyUnreachable") as? Bool ?? true
        let minutes = defaults.double(forKey: "unreachableMinutes")
        unreachableMinutes = minutes >= 5 ? minutes : 10
        notifyNoProduction = defaults.object(forKey: "notifyNoProduction") as? Bool ?? true

        energyDay = Self.dayKey(.now)
        accumulator = DailyAccumulator(
            day: energyDay,
            solarWh: defaults.double(forKey: "energyWh-\(energyDay)"),
            storedWh: defaults.double(forKey: "storedWh-\(energyDay)"),
            gridWh: defaults.double(forKey: "gridWh-\(energyDay)"),
            curve: defaults.array(forKey: "solarCurve-\(energyDay)") as? [Double] ?? [],
            peakW: defaults.double(forKey: "peakW-\(energyDay)")
        )
        energyTodayWh = accumulator.solarWh
        todayCurve = accumulator.curve
        peakTodayW = accumulator.peakW
        storedTodayWh = accumulator.storedWh
        gridTodayWh = accumulator.gridWh
        pruneAuxKeys()

        watchdog.unreachableAfter = unreachableMinutes * 60
        if lowSocAlertEnabled { Self.requestNotificationAuthorization() }
        appearance.apply()
        reloadDailyEnergy()
        applyConnectionMode()
        restart()
        refreshNotificationsStatus()
    }

    /// Vérification au démarrage (et au changement du réglage d'alerte) pour
    /// signaler en amont une autorisation manquante plutôt que d'échouer en
    /// silence au moment d'envoyer la notification.
    func refreshNotificationsStatus() {
        guard lowSocAlertEnabled else {
            notificationsDenied = false
            return
        }
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                self?.notificationsDenied = settings.authorizationStatus == .denied
            }
        }
    }

    func restart() {
        lastPrimaryAttempt = .distantPast
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            while let self, !Task.isCancelled {
                await self.refresh()
                try? await Task.sleep(for: .seconds(self.pollInterval))
            }
        }
    }

    /// Le champ hôte et le slider d'intervalle déclenchent leur didSet à
    /// chaque frappe/cran : attendre que la saisie se pose avant de relancer
    /// le polling (sinon on interroge des adresses partielles).
    private func scheduleRestart() {
        restartDebounce?.cancel()
        restartDebounce = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(800))
            guard !Task.isCancelled else { return }
            self?.restart()
        }
    }

    func refresh() async {
        do {
            let fresh: DeviceState
            let viaFallback: Bool
            if connectionMode == .cloud {
                fresh = try cloudSnapshot()
                viaFallback = false
            } else {
                (fresh, viaFallback) = try await fetchWithFallback()
            }
            state = fresh
            usingFallback = viaFallback
            lastError = nil
            localNetworkDenied = false
            append(fresh.solarInputPower, to: &solarHistory)
            append(fresh.outputHomePower, to: &homeHistory)
            append(fresh.batteryFlow, to: &flowHistory)
            accumulateEnergy(fresh)
            checkLowSoc(fresh)
            checkExtraNotifications(fresh)
            checkOutage(fresh)
            publishWidgetSnapshot(fresh)
            await refreshSmartCT()
            await refreshHistoryFromServer()
        } catch {
            // Garder les dernières valeurs affichées (grisées côté panneau,
            // voir MenuView.isStale) plutôt que de retomber sur « Pas de
            // données » : en coupure réseau, l'état d'avant reste utile.
            lastError = error.localizedDescription
            accumulator.resetSampleClock()
            localNetworkDenied = connectionMode == .local && Self.looksLikeLocalNetworkDenial(error)
            // Le Smart CT est un appareil distinct : sa mesure reste suivie
            // (ou invalidée) même quand le SolarFlow ne répond pas.
            await refreshSmartCT()
            if let event = watchdog.pollFailed(at: .now), notifyUnreachable,
               case .unreachable(let since) = event {
                let minutes = Int(Date.now.timeIntervalSince(since) / 60)
                notify(id: "unreachable",
                       title: String(localized: "SolarFlow injoignable"),
                       body: String(localized: "Aucune réponse de l'appareil depuis \(minutes) min — vérifier la batterie et son réseau."))
            }
            offlineAlert = watchdog.isOffline(at: .now)
        }
    }

    // MARK: - Alertes de panne

    /// Élévation solaire actuelle si la position est configurée (module Soleil),
    /// sinon -90 (détection d'anomalie désactivée).
    private var currentSunElevation: Double {
        let defaults = UserDefaults.standard
        let latitude = defaults.double(forKey: "sunLatitude")
        let longitude = defaults.double(forKey: "sunLongitude")
        guard latitude != 0 || longitude != 0 else { return -90 }
        return SunCalc.compute(latitude: latitude, longitude: longitude).elevation
    }

    private func checkOutage(_ state: DeviceState) {
        let event = watchdog.deviceResponded(solarW: state.solarInputPower,
                                             homeW: state.outputHomePower,
                                             elevation: currentSunElevation,
                                             at: .now)
        offlineAlert = false
        if let event, notifyNoProduction, case .productionAnomaly(let since) = event {
            let minutes = Int(Date.now.timeIntervalSince(since) / 60)
            notify(id: "production-anomaly",
                   title: String(localized: "Production solaire anormale"),
                   body: String(localized: "Le SolarFlow ne produit ni n'injecte rien depuis \(minutes) min alors que le soleil est haut — vérifier l'appareil (défaut, batterie pleine sans exutoire…)."))
        }
    }

    /// TN3179 : un refus TCC « réseau local » remonte en ENETDOWN (POSIX 50)
    /// ou NSURLErrorNotConnectedToInternet. EHOSTUNREACH (65), -1004 et -1003
    /// sont ambigus (device éteint, mDNS bloqué…) mais méritent le même
    /// guidage — le bandeau reste formulé au conditionnel.
    static func looksLikeLocalNetworkDenial(_ error: Error) -> Bool {
        var current: NSError? = error as NSError
        while let nsError = current {
            if nsError.domain == NSPOSIXErrorDomain, nsError.code == 50 || nsError.code == 65 {
                return true
            }
            if nsError.domain == NSURLErrorDomain,
               [NSURLErrorNotConnectedToInternet,
                NSURLErrorCannotConnectToHost,
                NSURLErrorCannotFindHost].contains(nsError.code) {
                return true
            }
            current = nsError.userInfo[NSUnderlyingErrorKey] as? NSError
        }
        return false
    }

    /// One-shot probe used by the settings window ("Tester la connexion").
    func test(host: String) async -> Result<DeviceState, Error> {
        do { return .success(try await fetchReport(host: host)) }
        catch { return .failure(error) }
    }

    // MARK: - Cloud

    /// Applique le mode de connexion : démarre la session cloud ou l'arrête
    /// (retour au mode local).
    private func applyConnectionMode() {
        if connectionMode == .cloud {
            startCloudService()
        } else {
            cloudService?.stop()
            cloudService = nil
            cloudLatest = nil
            cloudPhase = .notConfigured
        }
    }

    /// Démarre (ou redémarre) la session cloud avec le jeton du trousseau.
    private func startCloudService() {
        let service: CloudService
        if let existing = cloudService {
            service = existing
        } else {
            service = CloudService()
            // Les callbacks sont dispatchés sur le main thread par CloudService.
            service.onPhaseChanged = { [weak self] phase in
                MainActor.assumeIsolated { self?.cloudPhase = phase }
            }
            service.onDevicesChanged = { [weak self] devices in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    self.cloudDevices = devices
                    if self.cloudDeviceKey.isEmpty
                        || !devices.contains(where: { $0.deviceKey == self.cloudDeviceKey }) {
                        self.cloudDeviceKey = devices.first?.deviceKey ?? ""
                    }
                }
            }
            service.onStateChanged = { [weak self] deviceKey, state in
                MainActor.assumeIsolated {
                    guard let self, deviceKey == self.cloudDeviceKey else { return }
                    self.cloudLatest = state
                }
            }
            cloudService = service
        }
        guard let token = KeychainHelper.read(account: KeychainHelper.cloudKeyAccount),
              !token.isEmpty else {
            cloudPhase = .notConfigured
            return
        }
        service.start(cloudKeyToken: token)
    }

    /// Instantané complet issu du flux MQTT — jette si la session cloud est en
    /// erreur, sans données, ou avec des données périmées, pour que la chaîne
    /// d'erreur existante (lastError, watchdog, isStale) s'applique à l'identique.
    private func cloudSnapshot() throws -> DeviceState {
        if case .failed(let message) = cloudPhase {
            throw ZendureError.cloudUnavailable(message)
        }
        if cloudPhase == .notConfigured {
            throw ZendureError.noCloudKey
        }
        guard let latest = cloudLatest, let date = latest.lastUpdate else {
            throw ZendureError.cloudWaiting
        }
        guard Date.now.timeIntervalSince(date) < Self.cloudStaleAfter else {
            throw ZendureError.cloudStale
        }
        let device = cloudDevices.first(where: { $0.deviceKey == cloudDeviceKey })
        return latest.deviceState(fallbackSerial: device?.snNumber)
    }

    /// Enregistre (ou efface, si vide) le Cloud Key dans le trousseau et
    /// relance la session cloud si le mode Cloud est actif.
    func saveCloudKey(_ token: String) {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            KeychainHelper.delete(account: KeychainHelper.cloudKeyAccount)
            cloudService?.stop()
            cloudLatest = nil
            cloudPhase = .notConfigured
        } else {
            KeychainHelper.save(trimmed, account: KeychainHelper.cloudKeyAccount)
            if connectionMode == .cloud { startCloudService() }
        }
    }

    func loadCloudKey() -> String? {
        KeychainHelper.read(account: KeychainHelper.cloudKeyAccount)
    }

    /// Sonde one-shot des réglages : décode le jeton et appelle deviceList.
    func testCloudKey(_ token: String) async -> Result<[ZendureDevice], Error> {
        do {
            let key = try CloudKey.decode(token)
            let (devices, _) = try await ZendureAPI.fetchDeviceList(cloudKey: key)
            return .success(devices)
        } catch {
            return .failure(error)
        }
    }

    // MARK: - Fetching

    private func fetchWithFallback() async throws -> (DeviceState, viaFallback: Bool) {
        let fallback = fallbackHost.trimmingCharacters(in: .whitespacesAndNewlines)
        // Une fois passé sur l'hôte de secours, rester dessus : réessayer le
        // principal à chaque poll coûterait son timeout (5 s) à chaque
        // rafraîchissement. On ne le reteste que toutes les 2 min.
        if usingFallback, !fallback.isEmpty,
           Date.now.timeIntervalSince(lastPrimaryAttempt) < 120 {
            if let state = try? await fetchReport(host: fallback) {
                activeHost = fallback
                return (state, true)
            }
            // Le secours ne répond plus : retomber sur l'essai complet.
        }
        lastPrimaryAttempt = .now
        do {
            let state = try await fetchReport(host: host)
            activeHost = host
            return (state, false)
        } catch {
            guard !fallback.isEmpty else { throw error }
            let state = try await fetchReport(host: fallback)
            activeHost = fallback
            return (state, true)
        }
    }

    // MARK: - Control (POST /properties/write)

    /// Sends a control command to the device. ⚠️ This drives the real battery.
    /// Mode Cloud : lecture seule — `properties/write` via MQTT n'a jamais été
    /// validé en réel, on refuse plutôt que de piloter la batterie à l'aveugle.
    func writeProperties(_ properties: [String: Any]) async throws {
        guard connectionMode == .local else { throw ZendureError.cloudReadOnly }
        guard let sn = state?.serialNumber else { throw ZendureError.noHost }
        let target = (activeHost ?? host).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !target.isEmpty, let url = URL(string: "http://\(target)/properties/write") else {
            throw ZendureError.noHost
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["sn": sn, "properties": properties])
        let (_, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw ZendureError.badResponse(http.statusCode)
        }
        await refresh()
    }

    // MARK: - Widget

    private func publishWidgetSnapshot(_ state: DeviceState) {
        WidgetSnapshotStore.write(WidgetSnapshot(
            capturedAt: state.updatedAt,
            solarInputPower: state.solarInputPower,
            electricLevel: state.electricLevel,
            outputHomePower: state.outputHomePower,
            batteryFlow: state.batteryFlow,
            energyTodayWh: energyTodayWh,
            solarHistory: Array(solarHistory.suffix(24)),
            dailyEnergy: dailyEnergy.map { WidgetSnapshot.DayWh(day: $0.day, wh: $0.wh) }
        ))
        // Widgets refresh on their own timeline; a reload every 2 min keeps
        // them reasonably fresh without hammering WidgetKit's budget.
        if Date.now.timeIntervalSince(lastWidgetReload) >= 120 {
            lastWidgetReload = .now
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    // MARK: - CSV export

    /// CSV of every stored day (up to 90), oldest first: `date,wh`.
    func historyCSV() -> String {
        let all = collectDailyEnergy()
        var lines = ["date,wh"]
        lines += all.map { "\($0.day),\(Int($0.wh.rounded()))" }
        return lines.joined(separator: "\n") + "\n"
    }

    private func fetchReport(host: String) async throws -> DeviceState {
        let trimmed = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let url = URL(string: "http://\(trimmed)/properties/report") else {
            throw ZendureError.noHost
        }
        let (data, response) = try await session.data(from: url)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw ZendureError.badResponse(http.statusCode)
        }
        return try ZendureParser.parse(data)
    }

    // MARK: - Smart CT

    /// Interroge le Smart CT local (best effort) : succès → mesure fraîche,
    /// échec → nil, pour que l'interface ne présente jamais une mesure
    /// figée comme un flux réel.
    private func refreshSmartCT() async {
        let target = ctHost.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !target.isEmpty, let url = URL(string: "http://\(target)/properties/report") else {
            ctReport = nil
            return
        }
        do {
            let (data, response) = try await session.data(from: url)
            if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                throw ZendureError.badResponse(http.statusCode)
            }
            ctReport = try SmartCTParser.parse(data)
        } catch {
            ctReport = nil
        }
    }

    /// Sonde one-shot des réglages (« Tester ») pour le Smart CT.
    func testSmartCT(host: String) async -> Result<CTReport, Error> {
        let trimmed = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let url = URL(string: "http://\(trimmed)/properties/report") else {
            return .failure(ZendureError.noHost)
        }
        do {
            let (data, response) = try await session.data(from: url)
            if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                throw ZendureError.badResponse(http.statusCode)
            }
            return .success(try SmartCTParser.parse(data))
        } catch {
            return .failure(error)
        }
    }

    // MARK: - 24/7 collector

    /// Refreshes daily history + today's energy from the optional collector,
    /// at most once a minute. Silently falls back to local data when absent.
    private func refreshHistoryFromServer() async {
        let server = historyServer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !server.isEmpty else {
            historyFromServer = false
            return
        }
        guard Date.now.timeIntervalSince(lastServerFetch) >= 60 else { return }
        lastServerFetch = .now

        struct ServerDay: Decodable { let day: String; let wh: Double }
        struct ServerToday: Decodable { let day: String; let wh: Double }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"

        do {
            guard let dailyURL = URL(string: "http://\(server)/daily?days=90"),
                  let todayURL = URL(string: "http://\(server)/today") else { return }
            let (dailyData, _) = try await session.data(from: dailyURL)
            let (todayData, _) = try await session.data(from: todayURL)
            let days = try JSONDecoder().decode([ServerDay].self, from: dailyData)
            let today = try JSONDecoder().decode(ServerToday.self, from: todayData)

            var merged = days.compactMap { entry -> DayEnergy? in
                guard let date = formatter.date(from: entry.day) else { return nil }
                return DayEnergy(day: entry.day, date: date, wh: entry.wh)
            }
            // Le collecteur peut avoir démarré après l'app : garder le meilleur
            // des deux mondes pour les jours où l'app a compté davantage.
            for local in collectDailyEnergy() {
                if let index = merged.firstIndex(where: { $0.day == local.day }) {
                    if local.wh > merged[index].wh {
                        merged[index] = local
                    }
                } else {
                    merged.append(local)
                }
            }
            dailyEnergy = Array(merged.sorted { $0.date < $1.date }.suffix(14))
            accumulator.mergeSolarWh(today.wh)
            energyTodayWh = accumulator.solarWh
            historyFromServer = true
        } catch {
            historyFromServer = false
        }
    }

    // MARK: - Daily energy

    private func accumulateEnergy(_ state: DeviceState) {
        let date = state.updatedAt
        let day = Self.dayKey(date)
        let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
        let peakBefore = accumulator.peakW

        // En cloud, les échantillons sont datés du dernier rapport MQTT : ils
        // peuvent être espacés jusqu'au cycle getAll (60 s) — un maxDt calé sur
        // pollInterval*3 (15 s par défaut) ne créditerait presque rien.
        let maxDt = connectionMode == .cloud ? Self.cloudStaleAfter : pollInterval * 3
        accumulator.ingest(solar: state.solarInputPower,
                           charge: state.outputPackPower,
                           gridIn: state.gridInputPower,
                           at: date, dayKey: day,
                           minuteOfDay: (comps.hour ?? 0) * 60 + (comps.minute ?? 0),
                           maxDt: maxDt)

        energyDay = accumulator.day
        energyTodayWh = accumulator.solarWh
        storedTodayWh = accumulator.storedWh
        gridTodayWh = accumulator.gridWh
        todayCurve = accumulator.curve
        peakTodayW = accumulator.peakW

        UserDefaults.standard.set(energyTodayWh, forKey: "energyWh-\(day)")
        UserDefaults.standard.set(storedTodayWh, forKey: "storedWh-\(day)")
        UserDefaults.standard.set(gridTodayWh, forKey: "gridWh-\(day)")
        if peakTodayW > peakBefore {
            UserDefaults.standard.set(peakTodayW, forKey: "peakW-\(day)")
        }
        if date.timeIntervalSince(lastCurveSave) >= 60 {
            lastCurveSave = date
            UserDefaults.standard.set(todayCurve, forKey: "solarCurve-\(day)")
        }

        // Keep today's bar in the history card live.
        if let index = dailyEnergy.firstIndex(where: { $0.day == day }) {
            dailyEnergy[index] = DayEnergy(day: day, date: dailyEnergy[index].date, wh: energyTodayWh)
        } else {
            reloadDailyEnergy()
        }
    }

    /// All stored days (≤ 90, pruned), oldest first.
    private func collectDailyEnergy() -> [DayEnergy] {
        let defaults = UserDefaults.standard
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        let cutoff = Calendar.current.date(byAdding: .day, value: -90, to: .now)!

        var days: [DayEnergy] = []
        for (key, value) in defaults.dictionaryRepresentation() where key.hasPrefix("energyWh-") {
            let dayString = String(key.dropFirst("energyWh-".count))
            guard let date = formatter.date(from: dayString) else { continue }
            if date < cutoff {
                defaults.removeObject(forKey: key)
                continue
            }
            let wh = (value as? Double) ?? (value as? NSNumber)?.doubleValue ?? 0
            days.append(DayEnergy(day: dayString, date: date, wh: wh))
        }
        return days.sorted { $0.date < $1.date }
    }

    /// Rebuilds the history card data (last 14 days).
    private func reloadDailyEnergy() {
        dailyEnergy = Array(collectDailyEnergy().suffix(14))
    }

    /// Clé de jour en fuseau LOCAL — la courbe 5 min et l'historique raisonnent
    /// en heure locale ; l'ancien format ISO8601 basculait le jour à minuit UTC.
    private static let dayKeyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static func dayKey(_ date: Date) -> String {
        dayKeyFormatter.string(from: date)
    }

    // MARK: - Low battery alert

    private func checkLowSoc(_ state: DeviceState) {
        guard lowSocAlertEnabled, let soc = state.electricLevel else { return }
        if soc <= lowSocThreshold, !lowSocNotified {
            lowSocNotified = true
            let content = UNMutableNotificationContent()
            content.title = String(localized: "Batterie SolarFlow faible")
            content.body = String(localized: "Niveau de charge :") + " \(Int(soc)) % ("
                + String(localized: "seuil") + " : \(Int(lowSocThreshold)) %)"
            content.sound = .default
            UNUserNotificationCenter.current().add(
                UNNotificationRequest(identifier: "low-soc", content: content, trigger: nil)
            )
        } else if soc > lowSocThreshold + 5 {
            lowSocNotified = false
        }
    }

    // MARK: - Notifications optionnelles

    private func checkExtraNotifications(_ state: DeviceState) {
        if notifyFullBattery, let soc = state.electricLevel {
            let target = min(state.socMax ?? 100, 100)
            if soc >= target - 0.5, !fullBatteryNotified {
                fullBatteryNotified = true
                notify(id: "full-battery",
                       title: String(localized: "Batterie SolarFlow pleine"),
                       body: String(localized: "Niveau de charge : \(Int(soc)) %"))
            } else if soc < target - 5 {
                fullBatteryNotified = false
            }
        }
        if notifyGridDraw, state.gridInputPower > 50, state.solarInputPower > 100,
           Date.now.timeIntervalSince(lastGridDrawNotify) > 3600 {
            lastGridDrawNotify = .now
            notify(id: "grid-draw",
                   title: String(localized: "Tirage réseau inattendu"),
                   body: String(localized: "Le SolarFlow tire \(Format.watts(state.gridInputPower)) du réseau alors que le solaire produit \(Format.watts(state.solarInputPower))."))
        }
        if notifyDailyRecord, energyDay != recordNotifiedDay, dailyEnergy.count >= 4 {
            let previousBest = dailyEnergy.filter { $0.day != energyDay }.map(\.wh).max() ?? 0
            if previousBest > 0, energyTodayWh > previousBest {
                recordNotifiedDay = energyDay
                notify(id: "daily-record",
                       title: String(localized: "Record de production battu !"),
                       body: String(localized: "\(Format.kilowattHours(energyTodayWh)) aujourd'hui — ancien record : \(Format.kilowattHours(previousBest))."))
            }
        }
    }

    private func notify(id: String, title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: id, content: content, trigger: nil)
        )
    }

    // MARK: - Statistiques

    /// Production d'hier (Wh), si connue.
    var yesterdayWh: Double? {
        guard let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: .now) else { return nil }
        let wh = UserDefaults.standard.double(forKey: "energyWh-\(Self.dayKey(yesterday))")
        return wh > 0 ? wh : nil
    }

    /// Purge les clés auxiliaires par jour sorties de l'historique.
    private func pruneAuxKeys() {
        let defaults = UserDefaults.standard
        let keep = Set(collectDailyEnergy().suffix(15).map(\.day))
        for key in defaults.dictionaryRepresentation().keys
        where key.hasPrefix("solarCurve-") || key.hasPrefix("peakW-")
            || key.hasPrefix("storedWh-") || key.hasPrefix("gridWh-") {
            let day = String(key.split(separator: "-", maxSplits: 1)[1])
            if !keep.contains(day), day != energyDay {
                defaults.removeObject(forKey: key)
            }
        }
    }

    private static func requestNotificationAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private func append(_ value: Double, to history: inout [Double]) {
        history.append(value)
        if history.count > historyCapacity {
            history.removeFirst(history.count - historyCapacity)
        }
    }
}
