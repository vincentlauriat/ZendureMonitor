import Foundation
import SwiftUI

@MainActor
final class Monitor: ObservableObject {
    @Published var state: DeviceState?
    @Published var lastError: String?
    /// Historiques glissants pour les sparklines (un point par poll réussi).
    @Published var solarHistory: [Double] = []
    @Published var homeHistory: [Double] = []
    @Published var flowHistory: [Double] = []
    private let historyCapacity = 180
    @Published var host: String {
        didSet {
            UserDefaults.standard.set(host, forKey: "deviceHost")
            restart()
        }
    }
    @Published var pollInterval: Double {
        didSet {
            UserDefaults.standard.set(pollInterval, forKey: "pollInterval")
            restart()
        }
    }

    private var pollTask: Task<Void, Never>?
    private let session: URLSession

    init() {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 5
        config.waitsForConnectivity = false
        session = URLSession(configuration: config)

        host = UserDefaults.standard.string(forKey: "deviceHost") ?? ""
        let saved = UserDefaults.standard.double(forKey: "pollInterval")
        pollInterval = saved >= 2 ? saved : 5
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
            let fresh = try await fetchReport(host: host)
            state = fresh
            lastError = nil
            append(fresh.solarInputPower, to: &solarHistory)
            append(fresh.outputHomePower, to: &homeHistory)
            append(fresh.batteryFlow, to: &flowHistory)
        } catch {
            // Keep the last known values visible, but flag the problem.
            lastError = error.localizedDescription
            if state == nil || Date.now.timeIntervalSince(state!.updatedAt) > 60 {
                state = nil
            }
        }
    }

    private func append(_ value: Double, to history: inout [Double]) {
        history.append(value)
        if history.count > historyCapacity {
            history.removeFirst(history.count - historyCapacity)
        }
    }

    /// One-shot probe used by the settings window ("Tester la connexion").
    func test(host: String) async -> Result<DeviceState, Error> {
        do { return .success(try await fetchReport(host: host)) }
        catch { return .failure(error) }
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
}
