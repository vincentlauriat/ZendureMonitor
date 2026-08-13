import SwiftUI

/// Représentation en diagramme de Sankey des mêmes flux qu'`EnergyFlowView` :
/// la LARGEUR de chaque ruban est proportionnelle à la puissance, ce qui rend
/// les proportions lisibles d'un coup d'œil (ce que le schéma nodal, à traits
/// d'épaisseur constante, ne montre pas).
///
/// Trois colonnes : sources à gauche (Réseau, Panneaux, Batteries en décharge),
/// le SolarFlow au centre, usages à droite (Maison, Batteries en charge, prise
/// hors-réseau). Les colonnes sont alignées par le HAUT et le soutirage direct
/// réseau → maison occupe le créneau supérieur des deux colonnes : il passe
/// donc dans la bande libre au-dessus du hub et ne croise aucun autre ruban.
///
/// Conservation : un Sankey affirme visuellement que tout ce qui entre ressort.
/// Le hub ne boucle jamais exactement (pertes de conversion, bruit de mesure) —
/// l'écart est donc matérialisé par un ruban gris explicite, « Pertes &
/// conversion » quand il entre plus qu'il ne sort, « Écart de mesure » dans
/// l'autre sens. Les deux colonnes ont ainsi la même hauteur par construction.
///
/// Honnêteté des données : sans Smart CT, le soutirage direct de la maison sur
/// le réseau existe mais n'est pas mesuré. Lui donner une largeur serait
/// inventer une valeur, l'omettre serait affirmer qu'il vaut zéro — il est donc
/// dessiné à une épaisseur FIXE, hachurée et non proportionnelle, marquée
/// « non mesuré », et coiffe de la même façon la barre du nœud Maison.
struct SankeyFlowView: View {
    var state: DeviceState
    /// Mesure du Smart CT au compteur (W), si un compteur local répond.
    var ctTotalPower: Double? = nil

    // Mêmes couleurs qu'EnergyFlowView : basculer d'une vue à l'autre ne doit
    // rien changer au code couleur.
    private let pvColor = Color.yellow
    private let homeColor = Color.blue
    private let gridColor = Color.orange
    private let batteryColor = Color.green
    private let outletColor = Color.purple

    var body: some View {
        GeometryReader { geo in
            if let layout = makeLayout(size: geo.size) {
                ZStack {
                    ForEach(layout.bands) { band($0) }
                    ForEach(layout.nodes) { nodeBar($0) }
                    ForEach(layout.nodes) { nodeLabel($0, labelWidth: layout.labelWidth) }
                    hub(layout, height: geo.size.height)
                }
            } else {
                idleView
            }
        }
    }

    // MARK: - Valeurs partagées avec EnergyFlowView

    /// Soutirage réseau de la maison seule (la mesure du compteur inclut la
    /// charge secteur du SolarFlow, qui a son propre ruban — on la déduit).
    private var gridToHomeWatts: Double {
        guard let ct = ctTotalPower else { return 0 }
        return EnergyMath.gridToHome(ctTotal: ct, gridIn: state.gridInputPower)
    }

    private var homeTotalWatts: Double {
        guard let ct = ctTotalPower else { return state.outputHomePower }
        return EnergyMath.homeTotal(ctTotal: ct, gridIn: state.gridInputPower,
                                    outputHome: state.outputHomePower)
    }

    private var gridValue: String {
        if let ct = ctTotalPower { return Format.watts(ct) }
        return state.gridInputPower > 1 ? Format.watts(state.gridInputPower) : "—"
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

    // MARK: - Mise en page

    /// Calcule toute la géométrie, ou `nil` quand aucun flux n'est mesurable —
    /// sans ce garde-fou l'échelle diviserait par zéro toutes les nuits et les
    /// chemins seraient remplis de NaN.
    private func makeLayout(size: CGSize) -> SankeyLayout? {
        let barW: CGFloat = 12
        let hubW: CGFloat = 16
        let topInset: CGFloat = 10
        // Réserve basse : libellé du hub, et marge pour les barres portées à
        // leur hauteur minimale de lisibilité (3 pt) hors échelle.
        let bottomInset: CGFloat = 32
        let gap: CGFloat = 20
        let ghostH: CGFloat = 10
        let minBar: CGFloat = 3

        // Les colonnes de texte encadrent le diagramme : « + réseau : non
        // mesuré » ou « Pertes & conversion » ne doivent jamais être tronqués.
        let leftX = size.width * 0.24
        let hubX = size.width * 0.50
        let rightX = size.width * 0.76
        let labelW = max(56, leftX - barW / 2 - 10)

        let usable = size.height - topInset - bottomInset
        guard usable > 60 else { return nil }

        // Même seuil d'activité qu'EnergyFlowView (> 1 W) : aucun ruban ne
        // reçoit d'épaisseur plancher, sinon la somme des rubans ne coïncide
        // plus avec la hauteur de la barre du nœud.
        func gated(_ watts: Double) -> Double { watts > 1 ? watts : 0 }

        let measured = ctTotalPower != nil
        let solar = gated(state.solarInputPower)
        let gridIn = gated(state.gridInputPower)
        let charge = gated(max(0, state.batteryFlow))
        let discharge = gated(max(0, -state.batteryFlow))
        let home = gated(state.outputHomePower)
        let outlet = gated(state.offGridPower)
        let bypass = measured ? gated(gridToHomeWatts) : 0

        let totalIn = solar + gridIn + discharge
        let totalOut = home + charge + outlet
        let losses = gated(max(0, totalIn - totalOut))
        let deficit = gated(max(0, totalOut - totalIn))

        // Colonne gauche = colonne droite par construction (l'un des deux
        // rubans de bilan est nul).
        let columnTotal = totalIn + deficit + bypass
        guard columnTotal > 1 else { return nil }

        // La coiffe « non mesuré » n'existe que sans Smart CT.
        let ghostCap: CGFloat = measured ? 0 : ghostH

        struct Entry {
            var id: String
            var watts: Double
            var ghost: CGFloat
            var shown: Bool
        }

        let batteryIdle = charge == 0 && discharge == 0
        let leftEntries = [
            Entry(id: "grid", watts: gridIn + bypass, ghost: ghostCap,
                  shown: gridIn > 0 || bypass > 0 || !measured),
            Entry(id: "solar", watts: solar, ghost: 0, shown: solar > 0),
            // Le nœud batterie reste toujours visible à gauche quand elle ne
            // débite ni ne charge : c'est lui qui porte le SOC.
            Entry(id: "battery", watts: discharge, ghost: 0,
                  shown: discharge > 0 || batteryIdle),
            Entry(id: "deficit", watts: deficit, ghost: 0, shown: deficit > 0),
        ].filter(\.shown)
        let rightEntries = [
            Entry(id: "home", watts: home + bypass, ghost: ghostCap,
                  shown: home > 0 || bypass > 0 || !measured),
            Entry(id: "batteryCharge", watts: charge, ghost: 0, shown: charge > 0),
            Entry(id: "outlet", watts: outlet, ghost: 0, shown: outlet > 0),
            Entry(id: "losses", watts: losses, ghost: 0, shown: losses > 0),
        ].filter(\.shown)

        func fixedHeight(_ entries: [Entry]) -> CGFloat {
            CGFloat(max(0, entries.count - 1)) * gap + entries.reduce(0) { $0 + $1.ghost }
        }
        let scale = (usable - max(fixedHeight(leftEntries), fixedHeight(rightEntries))) / columnTotal
        guard scale > 0 else { return nil }

        func stack(_ entries: [Entry]) -> [String: (top: CGFloat, height: CGFloat, ghost: CGFloat)] {
            var result: [String: (top: CGFloat, height: CGFloat, ghost: CGFloat)] = [:]
            var y = topInset
            for entry in entries {
                let h = max(minBar, entry.ghost + CGFloat(entry.watts) * scale)
                result[entry.id] = (y, h, entry.ghost)
                y += h + gap
            }
            return result
        }
        let left = stack(leftEntries)
        let right = stack(rightEntries)

        // Le hub commence sous la bande réservée au soutirage direct, qui
        // occupe le créneau haut des deux colonnes.
        let topStrip = measured ? CGFloat(bypass) * scale : ghostCap
        let hubTop = topInset + topStrip
        let hubHeight = max(minBar, CGFloat(totalIn + deficit) * scale)

        let leftEdge = leftX + barW / 2
        let hubLeft = hubX - hubW / 2
        let hubRight = hubX + hubW / 2
        let rightEdge = rightX - barW / 2

        var bands: [SankeyBand] = []

        // Soutirage direct réseau → maison : créneau haut des deux colonnes.
        if let g = left["grid"], let h = right["home"] {
            if measured {
                if bypass > 0 {
                    bands.append(SankeyBand(id: "bypass", x0: leftEdge, y0: g.top,
                                            x1: rightEdge, y1: h.top,
                                            thickness: CGFloat(bypass) * scale,
                                            watts: bypass, color: gridColor, style: .flowing))
                }
            } else {
                bands.append(SankeyBand(id: "bypass", x0: leftEdge, y0: g.top,
                                        x1: rightEdge, y1: h.top,
                                        thickness: ghostH, watts: 0,
                                        color: .secondary, style: .ghost))
            }
        }

        // Entrées du hub, empilées dans le même ordre que les nœuds de gauche :
        // aucun croisement possible.
        var yIn = hubTop
        func input(_ id: String, nodeID: String, slotOffset: CGFloat, watts: Double,
                   color: Color, style: SankeyBand.Style) {
            guard watts > 0, let node = left[nodeID] else { return }
            let t = CGFloat(watts) * scale
            bands.append(SankeyBand(id: id, x0: leftEdge, y0: node.top + slotOffset,
                                    x1: hubLeft, y1: yIn, thickness: t,
                                    watts: watts, color: color, style: style))
            yIn += t
        }
        // Dans le nœud Réseau, le soutirage direct occupe le créneau haut : la
        // charge secteur démarre juste en dessous.
        let gridSlotOffset = measured ? CGFloat(bypass) * scale : ghostCap
        input("gridIn", nodeID: "grid", slotOffset: gridSlotOffset,
              watts: gridIn, color: gridColor, style: .flowing)
        input("solar", nodeID: "solar", slotOffset: 0,
              watts: solar, color: pvColor, style: .flowing)
        input("discharge", nodeID: "battery", slotOffset: 0,
              watts: discharge, color: batteryColor, style: .flowing)
        input("deficit", nodeID: "deficit", slotOffset: 0,
              watts: deficit, color: .secondary, style: .neutral)

        var yOut = hubTop
        func output(_ id: String, nodeID: String, slotOffset: CGFloat, watts: Double,
                    color: Color, style: SankeyBand.Style) {
            guard watts > 0, let node = right[nodeID] else { return }
            let t = CGFloat(watts) * scale
            bands.append(SankeyBand(id: id, x0: hubRight, y0: yOut,
                                    x1: rightEdge, y1: node.top + slotOffset,
                                    thickness: t, watts: watts, color: color, style: style))
            yOut += t
        }
        let homeSlotOffset = measured ? CGFloat(bypass) * scale : ghostCap
        output("home", nodeID: "home", slotOffset: homeSlotOffset,
               watts: home, color: homeColor, style: .flowing)
        output("charge", nodeID: "batteryCharge", slotOffset: 0,
               watts: charge, color: batteryColor, style: .flowing)
        output("outlet", nodeID: "outlet", slotOffset: 0,
               watts: outlet, color: outletColor, style: .flowing)
        output("losses", nodeID: "losses", slotOffset: 0,
               watts: losses, color: .secondary, style: .neutral)

        var nodes: [SankeyNode] = []
        func node(_ id: String, side: SankeyNode.Side, slots: [String: (top: CGFloat, height: CGFloat, ghost: CGFloat)],
                  color: Color, title: LocalizedStringKey, value: String,
                  detail: LocalizedStringKey? = nil, extra: String? = nil,
                  packs: [String] = [], dimmed: Bool = false) {
            guard let slot = slots[id] else { return }
            // `detail` compte double : à cette largeur de colonne il se replie
            // souvent sur deux lignes.
            let labelHeight: CGFloat = 30
                + (extra == nil ? 0 : 13)
                + (detail == nil ? 0 : 26)
                + (packs.isEmpty ? 0 : 16)
            nodes.append(SankeyNode(id: id, side: side, x: side == .left ? leftX : rightX,
                                    yTop: slot.top, height: slot.height, ghostHeight: slot.ghost,
                                    width: barW, color: color, title: title, value: value,
                                    detail: detail, extra: extra, packs: packs, dimmed: dimmed,
                                    labelCenterY: slot.top + slot.height / 2,
                                    labelHeight: labelHeight))
        }

        node("grid", side: .left, slots: left, color: gridColor,
             title: "Réseau public", value: gridValue,
             detail: measured ? nil : "soutirage direct : non mesuré")
        node("solar", side: .left, slots: left, color: pvColor,
             title: "Panneaux", value: Format.watts(state.solarInputPower))
        node("battery", side: .left, slots: left, color: batteryIdle ? .secondary : batteryColor,
             title: "Batteries", value: flowText,
             extra: state.electricLevel.map { "SOC \(Int($0.rounded())) %" },
             packs: packSOCs, dimmed: batteryIdle)
        node("deficit", side: .left, slots: left, color: .secondary,
             title: "Écart de mesure", value: Format.watts(deficit),
             detail: "sorties > entrées")
        node("home", side: .right, slots: right, color: homeColor,
             title: "Maison",
             value: Format.watts(measured ? homeTotalWatts : state.outputHomePower),
             detail: measured ? "consommation totale" : "+ réseau : non mesuré")
        // Même chaîne que le schéma nodal (▲/▼) : basculer d'une vue à l'autre
        // ne doit jamais changer un libellé.
        node("batteryCharge", side: .right, slots: right, color: batteryColor,
             title: "Batteries", value: flowText,
             extra: state.electricLevel.map { "SOC \(Int($0.rounded())) %" },
             packs: packSOCs)
        node("outlet", side: .right, slots: right, color: outletColor,
             title: "Prise hors-réseau", value: Format.watts(outlet))
        node("losses", side: .right, slots: right, color: .secondary,
             title: "Pertes & conversion", value: Format.watts(losses),
             detail: "entrées > sorties")

        // Les barres restent à leur place exacte, mais les blocs de texte
        // doivent tenir dans la vue sans se chevaucher : un nœud très fin (la
        // coiffe « non mesuré » seule, un ruban de bilan de quelques watts) a
        // un centre trop près de son voisin ou d'un bord. Passe descendante
        // puis remontante, comme un dépliage de libellés d'axe.
        for side in [SankeyNode.Side.left, .right] {
            var indices = nodes.indices.filter { nodes[$0].side == side }
            indices.sort { nodes[$0].labelCenterY < nodes[$1].labelCenterY }
            var previousBottom = CGFloat(0)
            for i in indices {
                let half = nodes[i].labelHeight / 2
                nodes[i].labelCenterY = max(nodes[i].labelCenterY, previousBottom + half)
                previousBottom = nodes[i].labelCenterY + half
            }
            var ceiling = size.height
            for i in indices.reversed() {
                let half = nodes[i].labelHeight / 2
                nodes[i].labelCenterY = min(nodes[i].labelCenterY, ceiling - half)
                ceiling = nodes[i].labelCenterY - half
            }
        }

        return SankeyLayout(
            nodes: nodes,
            bands: bands,
            hubRect: CGRect(x: hubLeft, y: hubTop, width: hubW, height: hubHeight),
            labelWidth: labelW
        )
    }

    private var packSOCs: [String] {
        guard state.packs.count > 1 else { return [] }
        return state.packs.map { $0.socLevel.map { "\(Int($0.rounded())) %" } ?? "—" }
    }

    // MARK: - Rendu

    private var idleView: some View {
        VStack(spacing: 6) {
            Image(systemName: "moon.zzz")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("Aucun flux mesurable")
                .font(.callout)
                .foregroundStyle(.secondary)
            if let soc = state.electricLevel {
                Text(verbatim: "SOC \(Int(soc.rounded())) %")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func band(_ band: SankeyBand) -> some View {
        let shape = RibbonShape(x0: band.x0, y0: band.y0, x1: band.x1, y1: band.y1,
                                thickness: band.thickness)
        let center = RibbonCenterline(x0: band.x0, y0: band.y0 + band.thickness / 2,
                                      x1: band.x1, y1: band.y1 + band.thickness / 2)
        let mid = CGPoint(x: (band.x0 + band.x1) / 2,
                          y: (band.y0 + band.y1) / 2 + band.thickness / 2)

        switch band.style {
        case .ghost:
            // Épaisseur fixe, hachurée : ce flux existe mais sa valeur est
            // inconnue — aucune largeur ne peut donc l'exprimer.
            ZStack {
                shape.fill(Color.secondary.opacity(0.06))
                shape.stroke(Color.secondary.opacity(0.4),
                             style: StrokeStyle(lineWidth: 1, dash: [3, 4]))
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
        case .neutral:
            ZStack {
                shape.fill(Color.secondary.opacity(0.18))
                shape.stroke(Color.secondary.opacity(0.3), lineWidth: 0.5)
            }
        case .flowing:
            ZStack {
                shape.fill(
                    LinearGradient(colors: [band.color.opacity(0.34), band.color.opacity(0.20)],
                                   startPoint: .leading, endPoint: .trailing)
                )
                // Même langage que le schéma nodal : des tirets défilent dans
                // le sens réel du flux, à une vitesse liée à la puissance.
                // Ils courent sur quelques VOIES parallèles à l'intérieur du
                // ruban, jamais sur toute son épaisseur : un trait aussi large
                // que la bande donne des dalles perpendiculaires au tracé, qui
                // se pincent dans les courbes et masquent le ruban.
                TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { timeline in
                    let t = timeline.date.timeIntervalSinceReferenceDate
                    let speed = 12.0 + min(band.watts / 40.0, 48.0)
                    let phase = CGFloat((t * speed).truncatingRemainder(dividingBy: 26)) * -1
                    ZStack {
                        ForEach(0..<band.laneCount, id: \.self) { lane in
                            let offset = band.thickness * (CGFloat(lane) + 0.5) / CGFloat(band.laneCount)
                            RibbonCenterline(x0: band.x0, y0: band.y0 + offset,
                                             x1: band.x1, y1: band.y1 + offset)
                                .stroke(band.color.opacity(0.85),
                                        style: StrokeStyle(lineWidth: band.laneWidth,
                                                           lineCap: .round,
                                                           dash: [9, 17], dashPhase: phase))
                        }
                    }
                }
                .clipShape(shape)
                if band.thickness >= 11 {
                    // Capsule seulement sur les rubans assez épais : en dessous
                    // elles se chevauchent et masquent le diagramme.
                    wattCapsule(Format.watts(band.watts), tint: band.color)
                        .position(mid)
                }
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

    @ViewBuilder
    private func nodeBar(_ node: SankeyNode) -> some View {
        let proportional = max(0, node.height - node.ghostHeight)
        VStack(spacing: 0) {
            if node.ghostHeight > 0 {
                // Coiffe hachurée : part inconnue, hors échelle.
                Rectangle()
                    .fill(Color.secondary.opacity(0.12))
                    .overlay(
                        Rectangle().strokeBorder(Color.secondary.opacity(0.45),
                                                 style: StrokeStyle(lineWidth: 1, dash: [2, 3]))
                    )
                    .frame(height: node.ghostHeight)
            }
            Rectangle()
                .fill(node.color.opacity(node.dimmed ? 0.35 : 0.9))
                .frame(height: proportional)
        }
        .frame(width: node.width, height: node.height)
        .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
        .position(x: node.x, y: node.yTop + node.height / 2)
    }

    @ViewBuilder
    private func nodeLabel(_ node: SankeyNode, labelWidth: CGFloat) -> some View {
        let alignment: HorizontalAlignment = node.side == .left ? .trailing : .leading
        let textAlignment: Alignment = node.side == .left ? .trailing : .leading
        let edge = node.side == .left
            ? node.x - node.width / 2 - 8 - labelWidth / 2
            : node.x + node.width / 2 + 8 + labelWidth / 2

        VStack(alignment: alignment, spacing: 1) {
            Text(node.title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(node.value)
                .font(.caption.monospacedDigit().weight(.medium))
                .foregroundStyle(node.dimmed ? .secondary : .primary)
            if let extra = node.extra {
                Text(verbatim: extra)
                    .font(.system(size: 9).monospacedDigit())
                    .foregroundStyle(socColor)
            }
            if let detail = node.detail {
                Text(detail)
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }
            if !node.packs.isEmpty {
                HStack(spacing: 3) {
                    ForEach(Array(node.packs.enumerated()), id: \.offset) { _, soc in
                        Text(verbatim: soc)
                            .font(.system(size: 9).monospacedDigit())
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(.regularMaterial))
                            .overlay(Capsule().strokeBorder(socColor.opacity(0.35), lineWidth: 1))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .frame(width: labelWidth, alignment: textAlignment)
        .fixedSize(horizontal: false, vertical: true)
        .position(x: edge, y: node.labelCenterY)
    }

    @ViewBuilder
    private func hub(_ layout: SankeyLayout, height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(Color.teal.opacity(0.85))
            .overlay(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .strokeBorder(Color.teal, lineWidth: 1)
            )
            .frame(width: layout.hubRect.width, height: layout.hubRect.height)
            .position(x: layout.hubRect.midX, y: layout.hubRect.midY)

        VStack(spacing: 1) {
            HStack(spacing: 4) {
                Image(systemName: "bolt.horizontal.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.teal)
                Text(verbatim: "SolarFlow")
                    .font(.caption2.weight(.medium))
            }
            if let temp = state.deviceTemperature {
                Text(verbatim: "\(Int(temp.rounded())) °C")
                    .font(.system(size: 9).monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        // Posé dans la marge basse réservée, sous le pied des colonnes : juste
        // sous la barre du hub, il chevaucherait le ruban le plus bas.
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(.regularMaterial))
        .position(x: layout.hubRect.midX, y: height - 16)
    }
}

// MARK: - Modèle de mise en page

private struct SankeyLayout {
    var nodes: [SankeyNode]
    var bands: [SankeyBand]
    var hubRect: CGRect
    var labelWidth: CGFloat
}

private struct SankeyNode: Identifiable {
    enum Side { case left, right }
    var id: String
    var side: Side
    /// Centre horizontal de la barre.
    var x: CGFloat
    var yTop: CGFloat
    var height: CGFloat
    /// Portion supérieure hachurée (flux réel de valeur inconnue), hors échelle.
    var ghostHeight: CGFloat
    var width: CGFloat
    var color: Color
    var title: LocalizedStringKey
    var value: String
    var detail: LocalizedStringKey?
    /// Texte libre non localisable (SOC).
    var extra: String?
    var packs: [String]
    var dimmed: Bool = false
    /// Centre vertical du bloc de texte, déplié pour ne sortir de la vue ni
    /// chevaucher un voisin — il peut donc différer du centre de la barre.
    var labelCenterY: CGFloat
    /// Hauteur estimée du bloc de texte, qui sert au dépliage.
    var labelHeight: CGFloat
}

private struct SankeyBand: Identifiable {
    enum Style { case flowing, neutral, ghost }
    var id: String
    var x0: CGFloat
    /// Ordonnée du BORD SUPÉRIEUR du ruban à son départ.
    var y0: CGFloat
    var x1: CGFloat
    var y1: CGFloat
    var thickness: CGFloat
    var watts: Double
    var color: Color
    var style: Style

    /// Nombre de voies de tirets à l'intérieur du ruban : une voie tous les
    /// ~16 pt d'épaisseur, pour que le mouvement reste lisible sur un ruban
    /// épais sans jamais couvrir toute sa largeur.
    var laneCount: Int { min(max(Int(thickness / 16), 1), 6) }

    /// Épaisseur d'une voie : au plus la moitié de la place qui lui revient,
    /// pour que le remplissage du ruban reste visible entre les tirets.
    var laneWidth: CGFloat {
        min(max(thickness / CGFloat(laneCount) * 0.45, 1.5), 6)
    }
}

/// Ruban de Sankey : deux cubiques symétriques fermées par les bords verticaux.
private struct RibbonShape: Shape {
    var x0: CGFloat, y0: CGFloat
    var x1: CGFloat, y1: CGFloat
    var thickness: CGFloat

    func path(in rect: CGRect) -> Path {
        let cx = (x0 + x1) / 2
        var path = Path()
        path.move(to: CGPoint(x: x0, y: y0))
        path.addCurve(to: CGPoint(x: x1, y: y1),
                      control1: CGPoint(x: cx, y: y0),
                      control2: CGPoint(x: cx, y: y1))
        path.addLine(to: CGPoint(x: x1, y: y1 + thickness))
        path.addCurve(to: CGPoint(x: x0, y: y0 + thickness),
                      control1: CGPoint(x: cx, y: y1 + thickness),
                      control2: CGPoint(x: cx, y: y0 + thickness))
        path.closeSubpath()
        return path
    }
}

/// Axe médian du ruban : c'est lui qu'on trace en tirets épais (écrêtés par le
/// ruban) pour animer le sens du flux, comme dans le schéma nodal.
private struct RibbonCenterline: Shape {
    var x0: CGFloat, y0: CGFloat
    var x1: CGFloat, y1: CGFloat

    func path(in rect: CGRect) -> Path {
        let cx = (x0 + x1) / 2
        var path = Path()
        path.move(to: CGPoint(x: x0, y: y0))
        path.addCurve(to: CGPoint(x: x1, y: y1),
                      control1: CGPoint(x: cx, y: y0),
                      control2: CGPoint(x: cx, y: y1))
        return path
    }
}
