import SwiftUI

/// Schéma de flux d'énergie animé : Soleil, Maison, Réseau en satellites,
/// la batterie (anneau SOC) au centre. Chaque lien représente un flux réel :
/// le solaire qui alimente la maison passe par l'arc du haut sans transiter
/// par la batterie ; les liens de la batterie ne s'animent que lorsqu'elle
/// charge ou décharge effectivement. Les pointillés défilent d'autant plus
/// vite que la puissance est élevée, avec la valeur affichée sur le lien.
struct EnergyFlowView: View {
    var state: DeviceState

    private let sunColor = Color.yellow
    private let homeColor = Color.blue
    private let gridColor = Color.orange
    private let batteryColor = Color.green

    // MARK: - Décomposition des flux
    // Bilan du SolarFlow : solaire + réseau + décharge = maison + charge.
    // Le solaire couvre d'abord la charge batterie, le reste part vers la
    // maison ; le réseau complète la charge ; la décharge alimente la maison.
    private var charge: Double { max(0, state.batteryFlow) }
    private var discharge: Double { max(0, -state.batteryFlow) }
    private var solarToBattery: Double { min(state.solarInputPower, charge) }
    private var solarToHome: Double { max(0, state.solarInputPower - solarToBattery) }
    private var batteryToHome: Double { discharge }
    private var gridToBattery: Double { min(state.gridInputPower, max(0, charge - solarToBattery)) }
    private var gridToHome: Double { max(0, state.gridInputPower - gridToBattery) }

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let sunPoint = CGPoint(x: size.width * 0.13, y: size.height * 0.22)
            let homePoint = CGPoint(x: size.width * 0.87, y: size.height * 0.22)
            let gridPoint = CGPoint(x: size.width * 0.13, y: size.height * 0.82)
            let batteryPoint = CGPoint(x: size.width * 0.5, y: size.height * 0.55)
            // Les liens s'arrêtent au bord de l'anneau SOC (intérieur transparent).
            let gaugeRadius: CGFloat = 54

            ZStack {
                flowLink(from: sunPoint, to: homePoint,
                         control: CGPoint(x: size.width * 0.5, y: size.height * 0.02),
                         watts: solarToHome, color: sunColor)
                flowLink(from: sunPoint, to: shorten(batteryPoint, toward: sunPoint, by: gaugeRadius),
                         watts: solarToBattery, color: sunColor)
                flowLink(from: shorten(batteryPoint, toward: homePoint, by: gaugeRadius), to: homePoint,
                         watts: batteryToHome, color: batteryColor)
                flowLink(from: gridPoint, to: shorten(batteryPoint, toward: gridPoint, by: gaugeRadius),
                         watts: gridToBattery, color: gridColor)
                // Arc par le coin inférieur droit pour éviter le libellé « Batterie ».
                flowLink(from: gridPoint, to: homePoint,
                         control: CGPoint(x: size.width * 0.95, y: size.height * 1.05),
                         watts: gridToHome, color: gridColor)

                node(at: sunPoint, icon: "sun.max.fill", tint: sunColor,
                     label: "Soleil", value: Format.watts(state.solarInputPower),
                     active: state.solarInputPower > 0)
                node(at: homePoint, icon: "house.fill", tint: homeColor,
                     label: "Maison", value: Format.watts(state.outputHomePower),
                     active: state.outputHomePower > 0)
                node(at: gridPoint, icon: "bolt.fill", tint: gridColor,
                     label: "Réseau", value: Format.watts(state.gridInputPower),
                     active: state.gridInputPower > 0)

                batteryNode(at: batteryPoint)
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

    private func flowLink(from: CGPoint, to: CGPoint, control: CGPoint? = nil,
                          watts: Double, color: Color) -> some View {
        let mid = CGPoint(x: (from.x + to.x) / 2, y: (from.y + to.y) / 2)
        let controlPoint = control ?? CGPoint(x: mid.x, y: mid.y - 18)
        // Point du lien à t = 0,5 sur la courbe quadratique, pour l'étiquette.
        let labelPoint = CGPoint(x: 0.25 * from.x + 0.5 * controlPoint.x + 0.25 * to.x,
                                 y: 0.25 * from.y + 0.5 * controlPoint.y + 0.25 * to.y)
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
                FlowPath(from: from, to: to, control: controlPoint)
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
                    .position(labelPoint)
            }
        }
    }

    private struct FlowPath: Shape {
        var from: CGPoint
        var to: CGPoint
        var control: CGPoint

        func path(in rect: CGRect) -> Path {
            var path = Path()
            path.move(to: from)
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

    private func batteryNode(at point: CGPoint) -> some View {
        VStack(spacing: 4) {
            CircularGauge(
                segments: [GaugeSegment(value: state.electricLevel ?? 0, color: socColor)],
                lineWidth: 8,
                centerText: "\(Int(state.electricLevel ?? 0)) %",
                centerSubtext: flowText
            )
            .frame(width: 92, height: 92)
            Text("Batterie")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .position(point)
    }

    private var socColor: Color {
        let soc = state.electricLevel ?? 0
        if soc < 15 { return .red }
        if soc < 40 { return .orange }
        return batteryColor
    }

    private var flowText: String? {
        if state.batteryFlow > 5 { return "▲ " + Format.watts(state.batteryFlow) }
        if state.batteryFlow < -5 { return "▼ " + Format.watts(-state.batteryFlow) }
        return nil
    }
}
