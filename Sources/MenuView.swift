import SwiftUI

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
                footer(text: "Mis à jour à \(state.updatedAt.formatted(date: .omitted, time: .standard))")
            } else {
                MetricCard(title: "Pas de données", systemImage: "sun.max.trianglebadge.exclamationmark") {
                    Text(monitor.lastError ?? "Connexion au SolarFlow en cours…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                footer(text: nil)
            }
        }
        .padding(12)
        .frame(width: 320)
    }

    // MARK: - Cartes

    private func solarCard(_ state: DeviceState) -> some View {
        MetricCard(title: "Production solaire", systemImage: "sun.max.fill") {
            VStack(alignment: .leading, spacing: 10) {
                Text(Format.watts(state.solarInputPower))
                    .font(.system(.title, design: .rounded).weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(state.solarInputPower > 0 ? .primary : .secondary)

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
        }
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

    private func footer(text: String?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if monitor.state != nil, let error = monitor.lastError {
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack {
                if let text {
                    Text(text)
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
        if state.batteryFlow > 5 { return "charge" }
        if state.batteryFlow < -5 { return "décharge" }
        return nil
    }
}
