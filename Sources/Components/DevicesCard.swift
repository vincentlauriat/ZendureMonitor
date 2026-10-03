import SwiftUI

/// Détail par SolarFlow quand l'installation en compte plusieurs : le reste
/// de l'interface montre leur somme (DeviceState.combine), cette carte montre
/// la part de chacun — et lequel ne répond pas. `detailed` ajoute les
/// valeurs propres à l'appareil (température, Wi-Fi, mode, limites…) que
/// l'agrégat ne peut pas porter : c'est la version du tableau de bord.
struct DevicesCard: View {
    var devices: [DeviceReading]
    var detailed = false

    private let solarColor = Color.yellow
    private let homeColor = Color.blue

    var body: some View {
        MetricCard(title: "Appareils", systemImage: "square.stack.3d.up.fill",
                   collapseKey: detailed ? nil : "collapseDevicesCard",
                   collapsedSummary: summary) {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(devices.enumerated()), id: \.element.id) { index, device in
                    row(device, index: index)
                    if index < devices.count - 1 { Divider() }
                }
            }
        }
    }

    /// « 2/2 en ligne » — repère compact quand la carte est repliée.
    private var summary: String {
        let online = devices.filter { $0.state != nil }.count
        return String(localized: "\(online)/\(devices.count) en ligne")
    }

    @ViewBuilder
    private func row(_ device: DeviceReading, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Circle()
                    .fill(device.state != nil ? Color.green : Color.red)
                    .frame(width: 7, height: 7)
                Text("SolarFlow \(index + 1)")
                    .font(.callout.weight(.semibold))
                Text(caption(device))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer(minLength: 0)
            }
            if let state = device.state {
                LegendRow(color: solarColor, label: "Solaire", value: Format.watts(state.solarInputPower))
                LegendRow(color: .teal, label: "Batterie", value: batteryText(state))
                LegendRow(color: homeColor, label: "Vers la maison", value: Format.watts(state.outputHomePower))
                if detailed { details(state, device: device) }
            } else {
                Label(device.error?.localizedDescription ?? String(localized: "Sans réponse"),
                      systemImage: "wifi.exclamationmark")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder
    private func details(_ state: DeviceState, device: DeviceReading) -> some View {
        if state.solarChannels.count > 1 {
            LegendRow(color: solarColor.opacity(0.6), label: "Entrées PV",
                      value: state.solarChannels.map(Format.watts).joined(separator: " · "))
        }
        if let temp = state.deviceTemperature {
            LegendRow(color: temp > 45 ? .red : .mint, label: "Température", value: "\(Int(temp.rounded())) °C")
        }
        if let rssi = state.rssi {
            LegendRow(color: .gray, label: "Signal WiFi", value: "\(Int(rssi)) dBm")
        }
        if let mode = state.acMode {
            LegendRow(color: .indigo, label: "Mode AC",
                      value: mode == 1 ? String(localized: "Charge (depuis le secteur)")
                                       : String(localized: "Décharge (vers la maison)"))
        }
        if let input = state.inputLimit, let output = state.outputLimit {
            LegendRow(color: .orange, label: "Limites charge / sortie",
                      value: "\(Format.watts(input)) / \(Format.watts(output))")
        }
        if let socMin = state.socMin, let socMax = state.socMax {
            LegendRow(color: .teal, label: "Plage de charge", value: "\(Int(socMin)) % – \(Int(socMax)) %")
        }
    }

    /// Nom (SN ou nom cloud) et hôte qui a répondu, quand ils diffèrent. Le
    /// panneau (296 pt) n'a la place que pour l'un des deux : l'hôte, qui
    /// distingue les appareils d'un coup d'œil (SN ne diffèrent qu'à la fin).
    private func caption(_ device: DeviceReading) -> String {
        guard let host = device.host, host != device.name else { return device.name }
        return detailed ? "\(device.name) · \(host)" : host
    }

    private func batteryText(_ state: DeviceState) -> String {
        var parts: [String] = []
        if let soc = state.electricLevel { parts.append("\(Int(soc.rounded())) %") }
        if state.batteryFlow > 5 { parts.append("▲ " + Format.watts(state.batteryFlow)) }
        if state.batteryFlow < -5 { parts.append("▼ " + Format.watts(-state.batteryFlow)) }
        return parts.isEmpty ? "—" : parts.joined(separator: " · ")
    }
}
