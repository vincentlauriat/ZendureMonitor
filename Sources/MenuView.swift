import SwiftUI
import UniformTypeIdentifiers

/// Panneau principal, style MacInside : cartes MetricCard avec jauge circulaire
/// pour la batterie et sparklines pour les tendances.
struct MenuView: View {
    @EnvironmentObject var monitor: Monitor
    @Environment(\.openSettings) private var openSettings

    private let solarColor = Color.yellow
    private let homeColor = Color.blue
    private let gridColor = Color.orange
    private let chargeColor = Color.green
    private let dischargeColor = Color.orange

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let state = monitor.state {
                solarCard(state)
                batteryCard(state)
                flowsCard(state)
                historyCard()
                footer(updatedAt: state.updatedAt)
            } else {
                MetricCard(title: "Pas de données", systemImage: "sun.max.trianglebadge.exclamationmark") {
                    Text(monitor.lastError ?? "Connexion au SolarFlow en cours…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                footer(updatedAt: nil)
            }
        }
        .padding(12)
        .frame(width: 320)
    }

    // MARK: - Cartes

    private func solarCard(_ state: DeviceState) -> some View {
        MetricCard(title: "Production solaire", systemImage: "sun.max.fill") {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text(Format.watts(state.solarInputPower))
                        .font(.system(.title, design: .rounded).weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(state.solarInputPower > 0 ? .primary : .secondary)
                    Spacer()
                    VStack(alignment: .trailing, spacing: 0) {
                        Text(Format.kilowattHours(monitor.energyTodayWh))
                            .font(.callout.monospacedDigit())
                        Text("aujourd'hui")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                SparklineChart(values: monitor.solarHistory, color: solarColor)
                    .frame(height: 36)

                if state.solarChannels.count > 1 {
                    VStack(spacing: 4) {
                        ForEach(Array(state.solarChannels.enumerated()), id: \.offset) { index, watts in
                            LegendRow(color: solarColor.opacity(0.55 + 0.15 * Double(index % 3)),
                                      label: "Entrée PV \(index + 1)",
                                      value: Format.watts(watts))
                        }
                    }
                }
            }
        }
    }

    private func batteryCard(_ state: DeviceState) -> some View {
        MetricCard(title: "Batterie", systemImage: "battery.100percent") {
            HStack(alignment: .center, spacing: 16) {
                let soc = state.electricLevel ?? 0
                CircularGauge(
                    segments: [GaugeSegment(value: soc, color: socColor(soc))],
                    centerText: "\(Int(soc)) %",
                    centerSubtext: flowSubtext(state)
                )
                .frame(width: 88, height: 88)

                VStack(spacing: 6) {
                    LegendRow(color: chargeColor, label: "Charge",
                              value: state.batteryFlow > 5 ? Format.watts(state.batteryFlow) : "—")
                    LegendRow(color: dischargeColor, label: "Décharge",
                              value: state.batteryFlow < -5 ? Format.watts(-state.batteryFlow) : "—")
                    SparklineChart(values: monitor.flowHistory, color: state.batteryFlow >= 0 ? chargeColor : dischargeColor)
                        .frame(height: 26)
                }
            }
            if !state.packs.isEmpty {
                VStack(spacing: 4) {
                    ForEach(Array(state.packs.enumerated()), id: \.element.id) { index, pack in
                        LegendRow(color: .teal,
                                  label: "Pack \(index + 1)",
                                  value: packSummary(pack))
                    }
                }
                .padding(.top, 6)
            }
        }
    }

    private func packSummary(_ pack: PackInfo) -> String {
        var parts: [String] = []
        if let soc = pack.socLevel { parts.append("\(Int(soc)) %") }
        if let temp = pack.temperature { parts.append("\(Int(temp.rounded())) °C") }
        if let power = pack.power, abs(power) > 5 { parts.append(Format.watts(power)) }
        return parts.isEmpty ? "—" : parts.joined(separator: " · ")
    }

    private func flowsCard(_ state: DeviceState) -> some View {
        MetricCard(title: "Flux", systemImage: "arrow.left.arrow.right") {
            VStack(alignment: .leading, spacing: 8) {
                LegendRow(color: homeColor, label: "Vers la maison", value: Format.watts(state.outputHomePower))
                LegendRow(color: gridColor, label: "Depuis le réseau", value: Format.watts(state.gridInputPower))
                SparklineChart(values: monitor.homeHistory, color: homeColor)
                    .frame(height: 36)
            }
        }
    }

    private func historyCard() -> some View {
        MetricCard(title: "Historique", systemImage: "calendar") {
            VStack(alignment: .leading, spacing: 8) {
                if monitor.dailyEnergy.count > 1 {
                    DailyBarChart(days: monitor.dailyEnergy, color: solarColor)
                        .frame(height: 72)
                    HStack {
                        Text("\(monitor.dailyEnergy.count) derniers jours")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Spacer()
                        let total = monitor.dailyEnergy.reduce(0) { $0 + $1.wh }
                        Text("Total : \(Format.kilowattHours(total))")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.secondary)
                        Button {
                            exportCSV()
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                        }
                        .buttonStyle(.borderless)
                        .font(.caption)
                        .help(Text("Exporter l'historique en CSV"))
                    }
                } else {
                    Text("L'historique se construira jour après jour.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func exportCSV() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.nameFieldStringValue = "zendure-production.csv"
        NSApp.activate(ignoringOtherApps: true)
        if panel.runModal() == .OK, let url = panel.url {
            try? monitor.historyCSV().write(to: url, atomically: true, encoding: .utf8)
        }
    }

    private func footer(updatedAt: Date?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if monitor.usingFallback {
                Label("Connecté via l'hôte de secours", systemImage: "network")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            if monitor.state != nil, let error = monitor.lastError {
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack {
                if let updatedAt {
                    Text("Mis à jour à \(updatedAt.formatted(date: .omitted, time: .standard))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Réglages…") {
                    openSettings()
                    NSApp.activate(ignoringOtherApps: true)
                }
                Button("Mises à jour…") { Updater.checkForUpdates() }
                Button("Quitter") { NSApplication.shared.terminate(nil) }
            }
            .buttonStyle(.borderless)
            .font(.caption)
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Helpers

    private func socColor(_ soc: Double) -> Color {
        switch soc {
        case ..<15: return .red
        case ..<40: return .orange
        default: return .green
        }
    }

    private func flowSubtext(_ state: DeviceState) -> String? {
        if state.batteryFlow > 5 { return String(localized: "charge") }
        if state.batteryFlow < -5 { return String(localized: "décharge") }
        return nil
    }
}
