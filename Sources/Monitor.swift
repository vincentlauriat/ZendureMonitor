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

    // MARK: - Settings (persisted)

    @Published var host: String {
        didSet { UserDefaults.standard.set(host, forKey: "deviceHost"); restart() }
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
        didSet { UserDefaults.standard.set(pollInterval, forKey: "pollInterval"); restart() }
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
    @Published var appearance: AppearanceMode {
        didSet {
            UserDefaults.standard.set(appearance.rawValue, forKey: "appearanceMode")
            appearance.apply()
        }
    }

    private var pollTask: Task<Void, Never>?
    private let session: URLSession
    private var lastSampleAt: Date?
    private var energyDay: String
    private var lowSocNotified = false
    /// Host of the last successful poll — control commands go there.
    private var activeHost: String?
    private var lastWidgetReload: Date = .distantPast
    private var lastServerFetch: Date = .distantPast

    init() {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 5
        config.waitsForConnectivity = false
        session = URLSession(configuration: config)

        let defaults = UserDefaults.standard
        host = defaults.string(forKey: "deviceHost") ?? ""
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

        energyDay = Self.dayKey(.now)
        energyTodayWh = defaults.double(forKey: "energyWh-\(energyDay)")

        if lowSocAlertEnabled { Self.requestNotificationAuthorization() }
        appearance.apply()
        reloadDailyEnergy()
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
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            while let self, !Task.isCancelled {
                await self.refresh()
                try? await Task.sleep(for: .seconds(self.pollInterval))
            }
        }
    }

    func refresh() async {
        do {
            let (fresh, viaFallback) = try await fetchWithFallback()
            state = fresh
            usingFallback = viaFallback
            lastError = nil
            localNetworkDenied = false
            append(fresh.solarInputPower, to: &solarHistory)
            append(fresh.outputHomePower, to: &homeHistory)
            append(fresh.batteryFlow, to: &flowHistory)
            accumulateEnergy(solarPower: fresh.solarInputPower, at: fresh.updatedAt)
            checkLowSoc(fresh)
            publishWidgetSnapshot(fresh)
            await refreshHistoryFromServer()
        } catch {
            // Keep the last known values visible, but flag the problem.
            lastError = error.localizedDescription
            lastSampleAt = nil
            localNetworkDenied = Self.looksLikeLocalNetworkDenial(error)
            if state == nil || Date.now.timeIntervalSince(state!.updatedAt) > 60 {
                state = nil
            }
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

    // MARK: - Fetching

    private func fetchWithFallback() async throws -> (DeviceState, viaFallback: Bool) {
        do {
            let state = try await fetchReport(host: host)
            activeHost = host
            return (state, false)
        } catch {
            let fallback = fallbackHost.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !fallback.isEmpty else { throw error }
            let state = try await fetchReport(host: fallback)
            activeHost = fallback
            return (state, true)
        }
    }

    // MARK: - Control (POST /properties/write)

    /// Sends a control command to the device. ⚠️ This drives the real battery.
    func writeProperties(_ properties: [String: Any]) async throws {
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
            solarHistory: Array(solarHistory.suffix(24))
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
            energyTodayWh = max(today.wh, energyTodayWh)
            historyFromServer = true
        } catch {
            historyFromServer = false
        }
    }

    // MARK: - Daily energy

    private func accumulateEnergy(solarPower: Double, at date: Date) {
        let day = Self.dayKey(date)
        if day != energyDay {
            energyDay = day
            energyTodayWh = 0
            lastSampleAt = nil
        }
        if let last = lastSampleAt {
            // Cap dt so a machine wake-up doesn't credit hours of sleep.
            let dt = min(date.timeIntervalSince(last), pollInterval * 3)
            if dt > 0 { energyTodayWh += solarPower * dt / 3600 }
        }
        lastSampleAt = date
        UserDefaults.standard.set(energyTodayWh, forKey: "energyWh-\(day)")

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

    private static func dayKey(_ date: Date) -> String {
        date.formatted(.iso8601.year().month().day())
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

enum Format {
    static func watts(_ value: Double) -> String {
        if abs(value) >= 1000 {
            return String(format: "%.2f kW", locale: .current, value / 1000)
        }
        return "\(Int(value.rounded())) W"
    }

    /// Shorter variant for the menu bar itself.
    static func wattsCompact(_ value: Double) -> String {
        if abs(value) >= 1000 {
            return String(format: "%.1f kW", locale: .current, value / 1000)
        }
        return "\(Int(value.rounded())) W"
    }

    static func kilowattHours(_ wh: Double) -> String {
        if wh >= 1000 {
            return String(format: "%.2f kWh", locale: .current, wh / 1000)
        }
        return "\(Int(wh.rounded())) Wh"
    }

    static func duration(minutes: Double) -> String {
        let total = Int(minutes.rounded())
        if total >= 60 { return "\(total / 60) h \(String(format: "%02d", total % 60))" }
        return "\(total) min"
    }
}
