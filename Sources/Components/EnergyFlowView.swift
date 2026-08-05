import SwiftUI

/// Schéma de flux d'énergie animé : le SolarFlow (l'onduleur-hub) au centre,
/// et en satellites tout ce qui s'y raccorde physiquement — panneaux
/// solaires, batteries (anneau SOC), réseau public, maison, prise
/// hors-réseau. Chaque lien ne s'anime que lorsque l'énergie circule
/// réellement, dans le sens réel du flux, avec sa puissance affichée ;
/// la vitesse des pointillés suit la puissance. Le lien batterie change de
/// sens selon charge/décharge.
struct EnergyFlowView: View {
    var state: DeviceState

    private let pvColor = Color.yellow
    private let homeColor = Color.blue
    private let gridColor = Color.orange
    private let batteryColor = Color.green
    private let outletColor = Color.purple

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let hub = CGPoint(x: size.width * 0.5, y: size.height * 0.46)
            let pv = CGPoint(x: size.width * 0.13, y: size.height * 0.2)
            let home = CGPoint(x: size.width * 0.87, y: size.height * 0.2)
            let grid = CGPoint(x: size.width * 0.13, y: size.height * 0.78)
            let outlet = CGPoint(x: size.width * 0.87, y: size.height * 0.78)
            let battery = CGPoint(x: size.width * 0.5, y: size.height * 0.85)
            let hubRadius: CGFloat = 42
            let nodeRadius: CGFloat = 30
            let batteryRadius: CGFloat = 42

            ZStack {
                link(from: pv, to: hub, trimFrom: nodeRadius, trimTo: hubRadius,
                     watts: state.solarInputPower, color: pvColor)
                link(from: hub, to: home, trimFrom: hubRadius, trimTo: nodeRadius,
                     watts: state.outputHomePower, color: homeColor)
                link(from: grid, to: hub, trimFrom: nodeRadius, trimTo: hubRadius,
                     watts: state.gridInputPower, color: gridColor)
                link(from: hub, to: outlet, trimFrom: hubRadius, trimTo: nodeRadius,
                     watts: state.offGridPower, color: outletColor)
                if state.batteryFlow >= 0 {
                    link(from: hub, to: battery, trimFrom: hubRadius, trimTo: batteryRadius,
                         watts: state.batteryFlow, color: batteryColor)
                } else {
                    link(from: battery, to: hub, trimFrom: batteryRadius, trimTo: hubRadius,
                         watts: -state.batteryFlow, color: batteryColor)
                }

                node(at: pv, icon: "sun.max.fill", tint: pvColor,
                     label: "Panneaux", value: Format.watts(state.solarInputPower),
                     active: state.solarInputPower > 1)
                node(at: home, icon: "house.fill", tint: homeColor,
                     label: "Maison", value: Format.watts(state.outputHomePower),
                     active: state.outputHomePower > 1)
                node(at: grid, icon: "bolt.fill", tint: gridColor,
                     label: "Réseau public", value: Format.watts(state.gridInputPower),
                     active: state.gridInputPower > 1)
                node(at: outlet, icon: "powerplug.fill", tint: outletColor,
                     label: "Prise hors-réseau", value: Format.watts(state.offGridPower),
                     active: state.offGridPower > 1)
                batteryNode(at: battery)
                hubNode(at: hub)
            }
        }
    }

    // MARK: - Liens

    private func shorten(_ point: CGPoint, toward other: CGPoint, by distance: CGFloat) -> CGPoint {
        let dx = other.x - point.x
        let dy = other.y - point.y
        let length = max(1, (dx * dx + dy * dy).squareRoot())
        return CGPoint(x: point.x + dx / length * distance,
                       y: point.y + dy / length * distance)
    }

    private func link(from: CGPoint, to: CGPoint, trimFrom: CGFloat, trimTo: CGFloat,
                      watts: Double, color: Color) -> some View {
        let start = shorten(from, toward: to, by: trimFrom)
        let end = shorten(to, toward: from, by: trimTo)
        let mid = CGPoint(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2)
        let active = watts > 1
        return ZStack {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !active)) { timeline in
                let phase: CGFloat = {
                    guard active else { return 0 }
                    let t = timeline.date.timeIntervalSinceReferenceDate
                    // Vitesse de défilement proportionnelle à la puissance (bornée).
                    let speed = 12.0 + min(watts / 40.0, 48.0)
                    return CGFloat((t * speed).truncatingRemainder(dividingBy: 18)) * -1
                }()
                LinkPath(from: start, to: end)
                    .stroke(active ? color : Color.secondary.opacity(0.2),
                            style: StrokeStyle(lineWidth: active ? 3 : 1.5,
                                               lineCap: .round,
                                               dash: active ? [7, 11] : [2, 5],
                                               dashPhase: phase))
            }
            if active {
                Text(Format.watts(watts))
                    .font(.caption2.monospacedDigit().weight(.medium))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(.regularMaterial))
                    .overlay(Capsule().strokeBorder(color.opacity(0.5), lineWidth: 1))
                    .position(mid)
            }
        }
    }

    private struct LinkPath: Shape {
        var from: CGPoint
        var to: CGPoint

        func path(in rect: CGRect) -> Path {
            var path = Path()
            path.move(to: from)
            path.addLine(to: to)
            return path
        }
    }

    // MARK: - Nœuds

    private func node(at point: CGPoint, icon: String, tint: Color,
                      label: LocalizedStringKey, value: String, active: Bool) -> some View {
        VStack(spacing: 3) {
            ZStack {
                Circle()
                    .fill(.regularMaterial)
                    .frame(width: 52, height: 52)
                    .overlay(Circle().strokeBorder(tint.opacity(active ? 0.8 : 0.25), lineWidth: 2))
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(active ? tint : .secondary)
            }
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.monospacedDigit().weight(.medium))
                .foregroundStyle(active ? .primary : .secondary)
        }
        .position(point)
    }

    private func hubNode(at point: CGPoint) -> some View {
        ZStack {
            Circle()
                .fill(.regularMaterial)
                .frame(width: 76, height: 76)
                .overlay(Circle().strokeBorder(Color.teal.opacity(0.7), lineWidth: 2))
            VStack(spacing: 2) {
                Image(systemName: "bolt.horizontal.fill")
                    .font(.title3)
                    .foregroundStyle(.teal)
                Text(verbatim: "SolarFlow")
                    .font(.caption2.weight(.medium))
                if let temp = state.deviceTemperature {
                    Text(verbatim: "\(Int(temp.rounded())) °C")
                        .font(.system(size: 9).monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
        .position(point)
    }

    private func batteryNode(at point: CGPoint) -> some View {
        HStack(spacing: 8) {
            CircularGauge(
                segments: [GaugeSegment(value: state.electricLevel ?? 0, color: socColor)],
                lineWidth: 7,
                centerText: "\(Int(state.electricLevel ?? 0)) %"
            )
            .frame(width: 64, height: 64)
            VStack(alignment: .leading, spacing: 1) {
                Text("Batteries")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(flowText)
                    .font(.caption.monospacedDigit().weight(.medium))
                    .foregroundStyle(abs(state.batteryFlow) > 5 ? .primary : .secondary)
            }
        }
        .position(point)
    }

    private var socColor: Color {
        let soc = state.electricLevel ?? 0
        if soc < 15 { return .red }
        if soc < 40 { return .orange }
        return batteryColor
    }

    private var flowText: String {
        if state.batteryFlow > 5 { return "▲ " + Format.watts(state.batteryFlow) }
        if state.batteryFlow < -5 { return "▼ " + Format.watts(-state.batteryFlow) }
        return "—"
    }
}
