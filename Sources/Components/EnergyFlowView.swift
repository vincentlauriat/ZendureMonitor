import SwiftUI

/// Schéma de flux d'énergie animé, planaire par construction : AUCUN lien
/// n'en croise un autre. Colonne centrale panneaux → SolarFlow → batteries
/// (batteries pile sous le hub) ; Réseau public et Maison sont ADJACENTS sur
/// la colonne de droite (maison en haut, réseau en bas — le compteur est
/// physiquement entre les deux), si bien que leur liaison directe est un
/// simple segment vertical le long du bord, hors du chemin de tous les autres
/// flux. La prise hors-réseau occupe le coin bas-gauche (seulement quand elle
/// débite). Chaque lien ne s'anime que lorsque l'énergie circule réellement,
/// dans le sens réel, à une vitesse proportionnelle à la puissance.
///
/// Honnêteté des données : le SolarFlow ne mesure que SES flux. Le soutirage
/// direct de la maison sur le réseau public (et donc la consommation totale
/// de la maison) n'est pas mesurable sans compteur en tableau (Smart CT) —
/// cette liaison est dessinée en gris « non mesuré », pas omise ni inventée.
///
/// Les positions sont ancrées sur le CENTRE des pastilles (les libellés sont
/// positionnés à part, au-dessus ou au-dessous selon la place disponible)
/// pour que liens et nœuds restent alignés — c'était le défaut de la v1, qui
/// centrait des blocs composites.
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
            // Colonne centrale (sun, hub, batteries : même x, décalé à gauche
            // pour équilibrer la colonne droite) ; colonne droite (home, grid :
            // même x) — leur liaison directe est verticale et ne peut croiser
            // aucun lien du hub, tous à gauche d'elle.
            let sun = CGPoint(x: size.width * 0.42, y: size.height * 0.13)
            let hub = CGPoint(x: size.width * 0.42, y: size.height * 0.45)
            let battery = CGPoint(x: size.width * 0.42, y: size.height * 0.77)
            let home = CGPoint(x: size.width * 0.84, y: size.height * 0.26)
            let grid = CGPoint(x: size.width * 0.84, y: size.height * 0.64)
            let outlet = CGPoint(x: size.width * 0.12, y: size.height * 0.64)
            let hubRadius: CGFloat = 38
            let nodeRadius: CGFloat = 26
            let batteryRadius: CGFloat = 32
            let outletActive = state.offGridPower > 1

            ZStack {
                // Liaison directe réseau → maison, verticale le long du bord
                // droit : ce flux existe électriquement mais rien ne le mesure
                // sans Smart CT — mesuré : flux animé comme les autres ; sinon
                // gris « non mesuré ».
                if ctTotalPower != nil {
                    link(from: grid, to: home, trimFrom: nodeRadius, trimTo: nodeRadius,
                         watts: gridToHomeWatts, color: gridColor)
                } else {
                    unmeasuredLink(from: grid, to: home, trim: nodeRadius)
                }

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
                     active: state.solarInputPower > 1, labels: .titleAbove)
                // Réseau et Maison : libellés vers l'extérieur (dessous /
                // dessus) pour laisser leur liaison verticale dégagée.
                node(at: grid, radius: nodeRadius, icon: "bolt.fill", tint: gridColor,
                     label: "Réseau public", value: gridValue,
                     active: state.gridInputPower > 1 || gridToHomeWatts > 1, labels: .below)
                if ctTotalPower != nil {
                    node(at: home, radius: nodeRadius, icon: "house.fill", tint: homeColor,
                         label: "Maison", value: Format.watts(homeTotalWatts),
                         detail: "consommation totale",
                         active: homeTotalWatts > 1, labels: .above)
                } else {
                    node(at: home, radius: nodeRadius, icon: "house.fill", tint: homeColor,
                         label: "Maison", value: Format.watts(state.outputHomePower),
                         detail: "+ réseau : non mesuré",
                         active: state.outputHomePower > 1, labels: .above)
                }
                if outletActive {
                    node(at: outlet, radius: nodeRadius, icon: "powerplug.fill", tint: outletColor,
                         label: "Prise hors-réseau", value: Format.watts(state.offGridPower),
                         active: true, labels: .below)
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

    /// Liaison réseau → maison sans compteur : segment gris statique marqué
    /// « ? non mesuré » (le cas mesuré passe par link(), comme tout flux réel).
    private func unmeasuredLink(from: CGPoint, to: CGPoint, trim: CGFloat) -> some View {
        let start = shorten(from, toward: to, by: trim)
        let end = shorten(to, toward: from, by: trim)
        let mid = CGPoint(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2)
        return ZStack {
            LinkPath(from: start, to: end)
                .stroke(Color.secondary.opacity(0.35),
                        style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [3, 6]))
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
            .position(mid)
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

    /// Où poser les textes d'un nœud, pour les garder hors du chemin des liens.
    private enum LabelPlacement {
        /// Libellé + valeur (+ détail) sous la pastille.
        case below
        /// Libellé + valeur (+ détail) au-dessus de la pastille.
        case above
        /// Libellé seul au-dessus — la valeur vit dans la capsule du lien.
        case titleAbove
    }

    /// Pastille ancrée par son CENTRE à `point` ; libellé et valeur positionnés
    /// à part au-dessus ou au-dessous — l'alignement des liens ne dépend ainsi
    /// jamais de la longueur des textes.
    @ViewBuilder
    private func node(at point: CGPoint, radius: CGFloat, icon: String, tint: Color,
                      label: LocalizedStringKey, value: String, detail: LocalizedStringKey? = nil,
                      active: Bool, labels: LabelPlacement) -> some View {
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

        switch labels {
        case .below, .above:
            let offset = radius + (detail == nil ? 22 : 28)
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
            .position(x: point.x, y: labels == .below ? point.y + offset : point.y - offset)
        case .titleAbove:
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
