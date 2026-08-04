import SwiftUI

/// Schéma de flux d'énergie animé : le SolarFlow au centre (anneau SOC),
/// Soleil / Maison / Réseau en satellites. Les liens actifs sont des pointillés
/// qui défilent, d'autant plus vite que la puissance est élevée.
struct EnergyFlowView: View {
    var state: DeviceState

    private let sunColor = Color.yellow
    private let homeColor = Color.blue
    private let gridColor = Color.orange
    private let chargeColor = Color.green

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let center = CGPoint(x: size.width * 0.5, y: size.height * 0.52)
            let sunPoint = CGPoint(x: size.width * 0.13, y: size.height * 0.22)
            let homePoint = CGPoint(x: size.width * 0.87, y: size.height * 0.22)
            let gridPoint = CGPoint(x: size.width * 0.13, y: size.height * 0.82)

            ZStack {
                flowLink(from: sunPoint, to: center, watts: state.solarInputPower, color: sunColor, size: size)
                flowLink(from: center, to: homePoint, watts: state.outputHomePower, color: homeColor, size: size)
                flowLink(from: gridPoint, to: center, watts: state.gridInputPower, color: gridColor, size: size)

                node(at: sunPoint, icon: "sun.max.fill", tint: sunColor,
                     label: "Soleil", value: Format.watts(state.solarInputPower),
                     active: state.solarInputPower > 0)
                node(at: homePoint, icon: "house.fill", tint: homeColor,
                     label: "Maison", value: Format.watts(state.outputHomePower),
                     active: state.outputHomePower > 0)
                node(at: gridPoint, icon: "bolt.fill", tint: gridColor,
                     label: "Réseau", value: Format.watts(state.gridInputPower),
                     active: state.gridInputPower > 0)

                centerNode(at: center)
            }
        }
    }

    // MARK: - Liens

    private func flowLink(from: CGPoint, to: CGPoint, watts: Double, color: Color, size: CGSize) -> some View {
        let active = watts > 1
        return TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !active)) { timeline in
            let phase: CGFloat = {
                guard active else { return 0 }
                let t = timeline.date.timeIntervalSinceReferenceDate
                // Vitesse de défilement proportionnelle à la puissance (bornée).
                let speed = 12.0 + min(watts / 40.0, 48.0)
                return CGFloat((t * speed).truncatingRemainder(dividingBy: 18)) * -1
            }()
            FlowPath(from: from, to: to)
                .stroke(active ? color : Color.secondary.opacity(0.25),
                        style: StrokeStyle(lineWidth: active ? 3 : 1.5,
                                           lineCap: .round,
                                           dash: active ? [7, 11] : [2, 5],
                                           dashPhase: phase))
        }
    }

    private struct FlowPath: Shape {
        var from: CGPoint
        var to: CGPoint

        func path(in rect: CGRect) -> Path {
            var path = Path()
            path.move(to: from)
            let mid = CGPoint(x: (from.x + to.x) / 2, y: (from.y + to.y) / 2)
            let control = CGPoint(x: mid.x, y: mid.y - 18)
            path.addQuadCurve(to: to, control: control)
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

    private func centerNode(at point: CGPoint) -> some View {
        VStack(spacing: 4) {
            CircularGauge(
                segments: [GaugeSegment(value: state.electricLevel ?? 0, color: socColor)],
                lineWidth: 8,
                centerText: "\(Int(state.electricLevel ?? 0)) %",
                centerSubtext: flowText
            )
            .frame(width: 92, height: 92)
            Text(verbatim: "SolarFlow")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .position(point)
    }

    private var socColor: Color {
        let soc = state.electricLevel ?? 0
        if soc < 15 { return .red }
        if soc < 40 { return .orange }
        return chargeColor
    }

    private var flowText: String? {
        if state.batteryFlow > 5 { return "▲ " + Format.watts(state.batteryFlow) }
        if state.batteryFlow < -5 { return "▼ " + Format.watts(-state.batteryFlow) }
        return nil
    }
}
