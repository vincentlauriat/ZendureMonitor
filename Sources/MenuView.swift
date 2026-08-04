import SwiftUI

struct MenuView: View {
    @EnvironmentObject var monitor: Monitor
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let state = monitor.state {
                header(state)
                Divider()
                rows(state)
                Divider()
                Text("Mis à jour à \(state.updatedAt.formatted(date: .omitted, time: .standard))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Label("Pas de données", systemImage: "sun.max.trianglebadge.exclamationmark")
                    .font(.headline)
                Text(monitor.lastError ?? "Connexion au SolarFlow en cours…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if monitor.state != nil, let error = monitor.lastError {
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()
            HStack {
                Button("Réglages…") {
                    openSettings()
                    NSApp.activate(ignoringOtherApps: true)
                }
                Spacer()
                Button("Mises à jour…") { Updater.checkForUpdates() }
                Spacer()
                Button("Quitter") { NSApplication.shared.terminate(nil) }
            }
            .buttonStyle(.borderless)
            .font(.callout)
        }
        .padding(14)
        .frame(width: 280)
    }

    private func header(_ state: DeviceState) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "sun.max.fill")
                .font(.title)
                .foregroundStyle(.yellow)
            VStack(alignment: .leading, spacing: 1) {
                Text(Format.watts(state.solarInputPower))
                    .font(.title2.weight(.semibold))
                    .monospacedDigit()
                Text("Production solaire")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func rows(_ state: DeviceState) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if state.solarChannels.count > 1 {
                row(icon: "square.grid.2x2", tint: .yellow,
                    label: "Entrées PV",
                    value: state.solarChannels.map { "\(Int($0)) W" }.joined(separator: " · "))
            }
            if let soc = state.electricLevel {
                row(icon: batteryIcon(soc), tint: soc <= 15 ? .red : .green,
                    label: "Batterie", value: "\(Int(soc)) %" + batterySuffix(state))
            }
            row(icon: "house", tint: .blue,
                label: "Vers la maison", value: Format.watts(state.outputHomePower))
            if state.gridInputPower > 0 {
                row(icon: "bolt", tint: .orange,
                    label: "Depuis le réseau", value: Format.watts(state.gridInputPower))
            }
        }
    }

    private func batterySuffix(_ state: DeviceState) -> String {
        let flow = state.batteryFlow
        if flow > 5 { return "  (charge \(Format.watts(flow)))" }
        if flow < -5 { return "  (décharge \(Format.watts(-flow)))" }
        return ""
    }

    private func batteryIcon(_ soc: Double) -> String {
        switch soc {
        case ..<15: return "battery.0percent"
        case ..<40: return "battery.25percent"
        case ..<65: return "battery.50percent"
        case ..<90: return "battery.75percent"
        default: return "battery.100percent"
        }
    }

    private func row(icon: String, tint: Color, label: String, value: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(tint)
                .frame(width: 20)
            Text(label)
            Spacer()
            Text(value)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .font(.callout)
    }
}
