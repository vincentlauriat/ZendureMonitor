import Foundation
import SwiftUI
import UserNotifications

@MainActor
final class Monitor: ObservableObject {
    @Published var state: DeviceState?
    @Published var lastError: String?
    /// True when the last successful poll went through the fallback host.
    @Published var usingFallback = false
    /// Solar energy produced today (Wh), integrated from the polls while the app runs.
    @Published var energyTodayWh: Double = 0
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
        }
    }
    @Published var lowSocThreshold: Double {
        didSet { UserDefaults.standard.set(lowSocThreshold, forKey: "lowSocThreshold") }
    }

    private var pollTask: Task<Void, Never>?
    private let session: URLSession
    private var lastSampleAt: Date?
    private var energyDay: String
    private var lowSocNotified = false

    init() {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 5
        config.waitsForConnectivity = false
        session = URLSession(configuration: config)

        let defaults = UserDefaults.standard
        host = defaults.string(forKey: "deviceHost") ?? ""
        fallbackHost = defaults.string(forKey: "fallbackHost") ?? ""
        let saved = defaults.double(forKey: "pollInterval")
        pollInterval = saved >= 2 ? saved : 5
        showSolarInBar = defaults.object(forKey: "showSolarInBar") as? Bool ?? true
        showBatteryInBar = defaults.object(forKey: "showBatteryInBar") as? Bool ?? false
        showHomeInBar = defaults.object(forKey: "showHomeInBar") as? Bool ?? false
        lowSocAlertEnabled = defaults.object(forKey: "lowSocAlertEnabled") as? Bool ?? true
        let threshold = defaults.double(forKey: "lowSocThreshold")
        lowSocThreshold = threshold > 0 ? threshold : 15

        energyDay = Self.dayKey(.now)
        energyTodayWh = defaults.double(forKey: "energyWh-\(energyDay)")

        if lowSocAlertEnabled { Self.requestNotificationAuthorization() }
        restart()
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
            append(fresh.solarInputPower, to: &solarHistory)
            append(fresh.outputHomePower, to: &homeHistory)
            append(fresh.batteryFlow, to: &flowHistory)
            accumulateEnergy(solarPower: fresh.solarInputPower, at: fresh.updatedAt)
            checkLowSoc(fresh)
        } catch {
            // Keep the last known values visible, but flag the problem.
            lastError = error.localizedDescription
            lastSampleAt = nil
            if state == nil || Date.now.timeIntervalSince(state!.updatedAt) > 60 {
                state = nil
            }
        }
    }

    /// One-shot probe used by the settings window ("Tester la connexion").
    func test(host: String) async -> Result<DeviceState, Error> {
        do { return .success(try await fetchReport(host: host)) }
        catch { return .failure(error) }
    }

    // MARK: - Fetching

    private func fetchWithFallback() async throws -> (DeviceState, viaFallback: Bool) {
        do {
            return (try await fetchReport(host: host), false)
        } catch {
            let fallback = fallbackHost.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !fallback.isEmpty else { throw error }
            return (try await fetchReport(host: fallback), true)
        }
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
            content.title = "Batterie SolarFlow faible"
            content.body = "Niveau de charge : \(Int(soc)) % (seuil : \(Int(lowSocThreshold)) %)."
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
}
