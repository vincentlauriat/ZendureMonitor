import SwiftUI

/// Schéma de flux d'énergie animé, en losange strictement aligné : panneaux
/// en haut, SolarFlow au centre, batteries exactement sous lui, réseau public
/// à gauche, maison à droite (prise hors-réseau en coin, seulement quand elle
/// débite). Chaque lien ne s'anime que lorsque l'énergie circule réellement,
/// dans le sens réel, à une vitesse proportionnelle à la puissance.
///
/// Honnêteté des données : le SolarFlow ne mesure que SES flux. Le soutirage
/// direct de la maison sur le réseau public (et donc la consommation totale
/// de la maison) n'est pas mesurable sans compteur en tableau (Smart CT) —
/// ce flux est dessiné en arc gris « non mesuré », pas omis ni inventé.
///
/// Les positions sont ancrées sur le CENTRE des pastilles (les libellés sont
/// positionnés à part, sous chaque pastille) pour que liens et nœuds restent
/// alignés — c'était le défaut de la v1, qui centrait des blocs composites.
struct EnergyFlowView: View {
    var state: DeviceState
    /// Mesure du Smart CT au compteur (W), si un compteur local répond :
    /// l'arc réseau → maison devient alors un vrai flux mesuré, et le nœud
    /// Maison affiche la consommation totale.
    var ctTotalPower: Double? = nil

    private let pvColor = Color.yellow
    private let homeColor = Color.blue
    private let gridColor = Color.orange
    private let batteryColor = Color.green
    private let outletColor = Color.purple

    /// Halo pulsé partagé par les nœuds actifs (même langage que la fenêtre
    /// Soleil : SkyDomeView anime ses badges de la même façon).
    @State private var pulse = false

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            // Losange aligné : sun, hub et batteries partagent le même x ;
            // grid, hub et home partagent le même y.
            let sun = CGPoint(x: size.width * 0.5, y: size.height * 0.13)
            let hub = CGPoint(x: size.width * 0.5, y: size.height * 0.45)
            let battery = CGPoint(x: size.width * 0.5, y: size.height * 0.77)
            let grid = CGPoint(x: size.width * 0.13, y: size.height * 0.45)
            let home = CGPoint(x: size.width * 0.87, y: size.height * 0.45)
            let outlet = CGPoint(x: size.width * 0.85, y: size.height * 0.77)
            let hubRadius: CGFloat = 38
            let nodeRadius: CGFloat = 26
            let batteryRadius: CGFloat = 32
            let outletActive = state.offGridPower > 1

            ZStack {
                // Arc « non mesuré » réseau → maison, sous le hub : ce flux
                // existe électriquement mais rien ne le mesure sans Smart CT.
                // Contrôle choisi pour que l'apex (0,64 h) passe entre le bas
                // du hub et le haut de la jauge batterie, sans les toucher.
                gridToHomeArc(from: grid, to: home,
                              control: CGPoint(x: size.width * 0.5, y: size.height * 0.74),
                              trim: nodeRadius)

                link(from: sun, to: hub, trimFrom: nodeRadius, trimTo: hubRadius,
                     watts: state.solarInputPower, color: pvColor)
                link(from: grid, to: hub, trimFrom: nodeRadius, trimTo: hubRadius,
                     watts: state.gridInputPower, color: gridColor)
                link(from: hub, to: home, trimFrom: hubRadius, trimTo: nodeRadius,
                     watts: state.outputHomePower, color: homeColor)
                if outletActive {
                    link(from: hub, to: outlet, trimFrom: hubRadius, trimTo: nodeRadius,
                         watts: state.offGridPower, color: outletColor)
                }
                // Le flux batterie est court et vertical : sa valeur vit dans
                // le libellé du nœud (▲/▼), pas dans une capsule sur le lien.
                if state.batteryFlow >= 0 {
                    link(from: hub, to: battery, trimFrom: hubRadius, trimTo: batteryRadius,
                         watts: state.batteryFlow, color: batteryColor, showLabel: false)
                } else {
                    link(from: battery, to: hub, trimFrom: batteryRadius, trimTo: hubRadius,
                         watts: -state.batteryFlow, color: batteryColor, showLabel: false)
                }

                // La valeur PV vit dans la capsule du lien : le libellé seul
                // se place au-dessus, pour ne pas recouvrir le lien vertical.
                node(at: sun, radius: nodeRadius, icon: "sun.max.fill", tint: pvColor,
                     label: "Panneaux", value: Format.watts(state.solarInputPower),
                     active: state.solarInputPower > 1, labelsBelow: false)
                node(at: grid, radius: nodeRadius, icon: "bolt.fill", tint: gridColor,
                     label: "Réseau public", value: gridValue,
                     active: state.gridInputPower > 1 || gridToHomeWatts > 1, labelsBelow: true)
                if ctTotalPower != nil {
                    node(at: home, radius: nodeRadius, icon: "house.fill", tint: homeColor,
                         label: "Maison", value: Format.watts(homeTotalWatts),
                         detail: "consommation totale",
                         active: homeTotalWatts > 1, labelsBelow: true)
                } else {
                    node(at: home, radius: nodeRadius, icon: "house.fill", tint: homeColor,
                         label: "Maison", value: Format.watts(state.outputHomePower),
                         detail: "+ réseau : non mesuré",
                         active: state.outputHomePower > 1, labelsBelow: true)
                }
                if outletActive {
                    node(at: outlet, radius: nodeRadius, icon: "powerplug.fill", tint: outletColor,
                         label: "Prise hors-réseau", value: Format.watts(state.offGridPower),
                         active: true, labelsBelow: true)
                }
                batteryNode(at: battery, radius: batteryRadius)
                hubNode(at: hub, radius: hubRadius)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }

    /// Soutirage réseau de la maison seule : la mesure du compteur inclut la
    /// charge secteur du SolarFlow, qui a son propre lien — on la déduit.
    private var gridToHomeWatts: Double {
        guard let ct = ctTotalPower else { return 0 }
        return max(0, ct - state.gridInputPower)
    }

    /// Consommation totale de la maison : soutirage réseau + injection SolarFlow.
    private var homeTotalWatts: Double {
        gridToHomeWatts + state.outputHomePower
    }

    private var gridValue: String {
        if let ct = ctTotalPower { return Format.watts(ct) }
        return state.gridInputPower > 1 ? Format.watts(state.gridInputPower) : "—"
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
                      watts: Double, color: Color, showLabel: Bool = true) -> some View {
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
                    .shadow(color: active ? color.opacity(0.35) : .clear, radius: 3)
            }
            if active, showLabel {
                wattCapsule(Format.watts(watts), tint: color)
                    .position(mid)
            }
        }
    }

    /// Arc quadratique réseau → maison. Avec un Smart CT qui répond, c'est un
    /// vrai flux mesuré (couleur réseau, pointillés animés, puissance) ; sans
    /// compteur, un arc gris statique marqué « ? non mesuré ».
    private func gridToHomeArc(from: CGPoint, to: CGPoint,
                               control: CGPoint, trim: CGFloat) -> some View {
        let start = CGPoint(x: from.x + trim * 0.4, y: from.y + trim)
        let end = CGPoint(x: to.x - trim * 0.4, y: to.y + trim)
        // Étiquette posée sur le flanc gauche de l'arc (t = 0,22), dans le
        // vide entre Réseau et Batteries — le sommet passerait derrière la
        // jauge batterie.
        let t: CGFloat = 0.22
        let labelPoint = CGPoint(
            x: (1 - t) * (1 - t) * start.x + 2 * t * (1 - t) * control.x + t * t * end.x,
            y: (1 - t) * (1 - t) * start.y + 2 * t * (1 - t) * control.y + t * t * end.y
        )
        let measured = ctTotalPower != nil
        let watts = gridToHomeWatts
        let active = measured && watts > 1
        return ZStack {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !active)) { timeline in
                let phase: CGFloat = {
                    guard active else { return 0 }
                    let time = timeline.date.timeIntervalSinceReferenceDate
                    let speed = 12.0 + min(watts / 40.0, 48.0)
                    return CGFloat((time * speed).truncatingRemainder(dividingBy: 18)) * -1
                }()
                Path { path in
                    path.move(to: start)
                    path.addQuadCurve(to: end, control: control)
                }
                .stroke(active ? gridColor : Color.secondary.opacity(0.35),
                        style: StrokeStyle(lineWidth: active ? 3 : 1.5,
                                           lineCap: .round,
                                           dash: active ? [7, 11] : [3, 6],
                                           dashPhase: phase))
                .shadow(color: active ? gridColor.opacity(0.35) : .clear, radius: 3)
            }
            if measured {
                if active {
                    wattCapsule(Format.watts(watts), tint: gridColor)
                        .position(labelPoint)
                }
            } else {
                HStack(spacing: 3) {
                    Image(systemName: "questionmark.circle")
                        .font(.system(size: 9))
                    Text("non mesuré")
                        .font(.caption2)
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Capsule().fill(.regularMaterial))
                .overlay(Capsule().strokeBorder(Color.secondary.opacity(0.3), lineWidth: 1))
                .position(labelPoint)
            }
        }
    }

    private func wattCapsule(_ text: String, tint: Color) -> some View {
        Text(text)
            .font(.caption2.monospacedDigit().weight(.medium))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(.regularMaterial))
            .overlay(Capsule().strokeBorder(tint.opacity(0.5), lineWidth: 1))
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

    /// Pastille ancrée par son CENTRE à `point` ; libellé et valeur positionnés
    /// à part sous la pastille — l'alignement des liens ne dépend ainsi jamais
    /// de la longueur des textes.
    @ViewBuilder
    private func node(at point: CGPoint, radius: CGFloat, icon: String, tint: Color,
                      label: LocalizedStringKey, value: String, detail: LocalizedStringKey? = nil,
                      active: Bool, labelsBelow: Bool) -> some View {
        ZStack {
            if active {
                Circle()
                    .fill(RadialGradient(colors: [tint.opacity(0.45), .clear],
                                         center: .center, startRadius: 2, endRadius: radius * 1.6))
                    .frame(width: radius * 3.2, height: radius * 3.2)
                    .blur(radius: 5)
                    .scaleEffect(pulse ? 1.15 : 0.9)
            }
            Circle()
                .fill(.regularMaterial)
                .frame(width: radius * 2, height: radius * 2)
                .overlay(Circle().strokeBorder(tint.opacity(active ? 0.8 : 0.25), lineWidth: 2))
                .shadow(color: active ? tint.opacity(0.5) : .clear, radius: pulse ? 6 : 3)
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(active ? tint : .secondary)
        }
        .position(point)

        if labelsBelow {
            VStack(spacing: 1) {
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.caption.monospacedDigit().weight(.medium))
                    .foregroundStyle(active ? .primary : .secondary)
                if let detail {
                    Text(detail)
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                }
            }
            .position(x: point.x, y: point.y + radius + (detail == nil ? 22 : 28))
        } else {
            // Libellé seul au-dessus de la pastille (la valeur est ailleurs).
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .position(x: point.x, y: point.y - radius - 10)
        }
    }

    private func hubNode(at point: CGPoint, radius: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(.regularMaterial)
                .frame(width: radius * 2, height: radius * 2)
                .overlay(Circle().strokeBorder(Color.teal.opacity(0.7), lineWidth: 2))
                .shadow(color: .teal.opacity(0.3), radius: 4)
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

    /// Jauge SOC ancrée par son centre (alignée sous le hub) ; flux ▲/▼ et
    /// SOC de chaque pack en dessous, centrés.
    @ViewBuilder
    private func batteryNode(at point: CGPoint, radius: CGFloat) -> some View {
        CircularGauge(
            segments: [GaugeSegment(value: state.electricLevel ?? 0, color: socColor)],
            lineWidth: 7,
            centerText: "\(Int(state.electricLevel ?? 0)) %"
        )
        .frame(width: radius * 2, height: radius * 2)
        .background(
            Circle()
                .fill(RadialGradient(colors: [batteryColor.opacity(abs(state.batteryFlow) > 5 ? 0.3 : 0), .clear],
                                     center: .center, startRadius: 2, endRadius: radius * 1.7))
                .frame(width: radius * 3.4, height: radius * 3.4)
                .blur(radius: 5)
                .scaleEffect(pulse ? 1.12 : 0.9)
        )
        .position(point)

        VStack(spacing: 1) {
            HStack(spacing: 5) {
                Text("Batteries")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(flowText)
                    .font(.caption.monospacedDigit().weight(.medium))
                    .foregroundStyle(abs(state.batteryFlow) > 5 ? .primary : .secondary)
            }
            if state.packs.count > 1 {
                HStack(spacing: 4) {
                    ForEach(state.packs) { pack in
                        Text(verbatim: pack.socLevel.map { "\(Int($0)) %" } ?? "—")
                            .font(.system(size: 9).monospacedDigit())
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(.regularMaterial))
                            .overlay(Capsule().strokeBorder(socColor.opacity(0.35), lineWidth: 1))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .position(x: point.x, y: point.y + radius + (state.packs.count > 1 ? 20 : 12))
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
