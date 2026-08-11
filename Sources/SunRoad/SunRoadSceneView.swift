import SceneKit
import SwiftUI

/// Ce que la scène SunRoad affiche — piloté par les checkboxes du HUD.
struct SunRoadVisibility: Equatable {
    var buildings = true
    var roads = true
    var arc = true
    var panels = true
    var compass = true
    var energy = true
}

/// Flux d'énergie quantifiés en « nombre de billes » (0–4) — la cadence des
/// billes montre l'intensité sans reconstruire la scène à chaque watt.
struct SunRoadFlows: Equatable {
    var solar = 0
    var grid = 0
    var batteryCharge = 0
    var batteryDischarge = 0

    /// 0 W → rien ; puis 4 paliers (≤150, ≤500, ≤1200, au-delà).
    static func bucket(_ watts: Double) -> Int {
        switch watts {
        case ..<20: 0
        case ..<150: 1
        case ..<500: 2
        case ..<1200: 3
        default: 4
        }
    }

    init(solar: Int = 0, grid: Int = 0, batteryCharge: Int = 0, batteryDischarge: Int = 0) {
        self.solar = solar
        self.grid = grid
        self.batteryCharge = batteryCharge
        self.batteryDischarge = batteryDischarge
    }

    init(state: DeviceState?) {
        guard let state else { self.init(); return }
        self.init(
            solar: Self.bucket(state.solarInputPower),
            grid: Self.bucket(state.gridInputPower),
            batteryCharge: Self.bucket(max(state.batteryFlow, 0)),
            batteryDischarge: Self.bucket(max(-state.batteryFlow, 0))
        )
    }
}

/// La scène 3D « SunRoad » : sol, boussole, maison, champs de panneaux, arc du
/// soleil du jour et soleil-lumière directionnelle (ombres portées réelles).
/// Phase A du plan v2.0 — le quartier OSM et les flux d'énergie arrivent en
/// phases B/C.
struct SunRoadSceneView: NSViewRepresentable {
    var latitude: Double
    var longitude: Double
    var date: Date
    var arrays: [PanelArray]
    /// Le quartier (Overpass/OSM : bâtiments + routes) — vide tant que non
    /// chargé : la maison placeholder assure l'intérim.
    var neighborhood: SunRoadNeighborhood
    var visibility: SunRoadVisibility
    /// Flux en direct (billes animées) — .init() quand pas de données.
    var flows: SunRoadFlows = SunRoadFlows()
    /// Courbe de production du jour (max 5 min, W) pour le ruban sur l'arc,
    /// et son pic pour l'échelle. Vide ou `showRibbon == false` → pas de ruban.
    var todayCurve: [Double] = []
    var curvePeak: Double = 0
    /// Courbe de consommation maison du jour (même granularité) — tracée en
    /// courbe continue sur le cercle horaire complet (à la Helios).
    var homeCurve: [Double] = []
    var homePeak: Double = 0
    /// Consommation maison instantanée (W) — badge au-dessus de la maison.
    var homeWatts: Double = 0
    var showRibbon: Bool = true
    /// Couverture nuageuse 0…1 — assombrit lumière et ciel (Phase D).
    var cloudCover: Double = 0
    /// Mode « Définir ma maison » : le prochain clic sur un bâtiment le
    /// désigne comme centre exact (Phase E) au lieu d'orbiter.
    var pickingHouse: Bool = false
    var onPickBuilding: ((Int) -> Void)? = nil

    private static let domeRadius = 140.0

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> SCNView {
        let view = PickableSCNView()
        view.installClickRecognizer()
        let scene = SCNScene()
        view.scene = scene
        view.antialiasingMode = .multisampling4X
        view.autoenablesDefaultLighting = false

        // Caméra orbitale native (drag pour tourner, molette pour zoomer).
        // L'orbite est centrée à mi-hauteur : on embrasse d'emblée la maison
        // ET le chemin du soleil, qui culmine vers 120 m sur le dôme.
        view.allowsCameraControl = true
        view.defaultCameraController.interactionMode = .orbitTurntable
        view.defaultCameraController.target = SCNVector3(0, 30, 0)

        let camera = SCNCamera()
        camera.zFar = 900
        let cameraNode = SCNNode()
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(115, 95, 190)   // sud-est, haut et reculé
        cameraNode.look(at: SCNVector3(0, 35, 0))
        scene.rootNode.addChildNode(cameraNode)

        buildStaticNodes(in: scene, coordinator: context.coordinator)
        context.coordinator.view = view
        updateNSView(view, context: context)
        return view
    }

    func updateNSView(_ view: SCNView, context: Context) {
        let coordinator = context.coordinator
        if let pickable = view as? PickableSCNView {
            pickable.pickingEnabled = pickingHouse
            pickable.onPickBuilding = onPickBuilding
        }

        // L'arc du jour ne dépend que du jour et du lieu — reconstruit
        // uniquement quand l'un des deux change.
        let dayKey = "\(Calendar.current.startOfDay(for: date).timeIntervalSince1970)-\(latitude)-\(longitude)"
        if coordinator.arcKey != dayKey {
            coordinator.arcKey = dayKey
            rebuildSunArc(coordinator: coordinator)
        }
        if coordinator.arraysKey != arrays {
            coordinator.arraysKey = arrays
            rebuildPanels(coordinator: coordinator)
            // La courbe de production prévue dépend de l'orientation des
            // champs : la refaire quand un slider bouge.
            coordinator.ribbonKey = ""
        }
        // Reconstruire aussi quand l'ORIGINE change (maison désignée au
        // clic) : les données OSM restent valables, seule la projection
        // bouge — sans ça, le quartier restait projeté sur l'ancien centre.
        let originKey = "\(latitude),\(longitude)"
        if coordinator.neighborhoodKey != neighborhood || coordinator.originKey != originKey {
            coordinator.neighborhoodKey = neighborhood
            coordinator.originKey = originKey
            rebuildBuildings(coordinator: coordinator)
            rebuildRoads(coordinator: coordinator)
        }
        if coordinator.flowsKey != flows {
            coordinator.flowsKey = flows
            rebuildFlows(coordinator: coordinator)
        }
        // dayKey inclus : la prévision se recalcule quand la timeline change
        // de jour (elle se trace aussi hors du jour courant, sans le réel).
        let ribbonKey = "\(dayKey)-\(todayCurve.count)-\(showRibbon)-\(Int(curvePeak))-\(homeCurve.count)-\(Int(homePeak))"
        if coordinator.ribbonKey != ribbonKey {
            coordinator.ribbonKey = ribbonKey
            rebuildRibbon(coordinator: coordinator)
        }
        // Le badge ne se reconstruit que par pas de 10 W — pas de rebuild de
        // texte à chaque poll.
        let badgeKey = Int(homeWatts / 10)
        if coordinator.badgeKey != badgeKey {
            coordinator.badgeKey = badgeKey
            rebuildBadge(coordinator: coordinator)
        }
        // Visibilité par couche (checkboxes du HUD). La maison placeholder
        // ne vaut que sans données OSM ; le soleil-lumière reste toujours là.
        coordinator.buildingsNode?.isHidden = !visibility.buildings
        coordinator.placeholderHouse?.isHidden = !visibility.buildings || !neighborhood.buildings.isEmpty
        coordinator.roadsNode?.isHidden = !visibility.roads
        coordinator.arcNode?.isHidden = !visibility.arc
        coordinator.panelsNode?.isHidden = !visibility.panels
        coordinator.compassNode?.isHidden = !visibility.compass
        coordinator.flowsNode?.isHidden = !visibility.energy
        coordinator.energyPropsNode?.isHidden = !visibility.energy
        coordinator.ribbonNode?.isHidden = !visibility.energy
        coordinator.consumptionNode?.isHidden = !visibility.energy
        coordinator.badgeNode?.isHidden = !visibility.energy
        updateSun(coordinator: coordinator)
    }

    // MARK: - Décor fixe

    private func buildStaticNodes(in scene: SCNScene, coordinator: Coordinator) {
        let root = scene.rootNode
        coordinator.scene = scene

        // Sol : large galette verte, réceptrice d'ombres.
        let ground = SCNCylinder(radius: 150, height: 0.4)
        ground.firstMaterial?.diffuse.contents = NSColor(calibratedRed: 0.36, green: 0.48, blue: 0.32, alpha: 1)
        let groundNode = SCNNode(geometry: ground)
        groundNode.position = SCNVector3(0, -0.2, 0)
        root.addChildNode(groundNode)

        // Anneau de boussole au bord de la voûte + lettres cardinales,
        // regroupés pour être masquables d'un bloc.
        let compass = SCNNode()
        root.addChildNode(compass)
        coordinator.compassNode = compass
        let ring = SCNTorus(ringRadius: Self.domeRadius, pipeRadius: 0.4)
        ring.firstMaterial?.diffuse.contents = NSColor.white.withAlphaComponent(0.35)
        let ringNode = SCNNode(geometry: ring)
        ringNode.position = SCNVector3(0, 0.1, 0)
        compass.addChildNode(ringNode)

        let cardinals: [(String, Double)] = [("N", 0), ("E", 90), ("S", 180), ("O", 270)]
        for (letter, azimuth) in cardinals {
            let text = SCNText(string: letter, extrusionDepth: 0.3)
            text.font = NSFont.systemFont(ofSize: 10, weight: .bold)
            text.firstMaterial?.diffuse.contents = NSColor.white.withAlphaComponent(0.85)
            let node = SCNNode(geometry: text)
            let p = SunRoadGeometry.domePoint(azimuth: azimuth, elevation: 0, radius: Self.domeRadius + 8)
            // Centrer le glyphe sur son point d'ancrage.
            let (minB, maxB) = text.boundingBox
            node.pivot = SCNMatrix4MakeTranslation((minB.x + maxB.x) / 2, minB.y, 0)
            node.position = SCNVector3(p.x, 0.3, p.z)
            node.eulerAngles.y = CGFloat(-azimuth * .pi / 180)
            compass.addChildNode(node)
        }

        // La maison (placeholder Phase A — remplacée par le bâtiment OSM réel
        // en phase B) : murs + toit à deux pentes.
        let house = SCNNode()
        let walls = SCNBox(width: 9, height: 5, length: 7, chamferRadius: 0)
        walls.firstMaterial?.diffuse.contents = NSColor(calibratedWhite: 0.92, alpha: 1)
        let wallsNode = SCNNode(geometry: walls)
        wallsNode.position = SCNVector3(0, 2.5, 0)
        house.addChildNode(wallsNode)
        let roof = SCNPyramid(width: 10, height: 2.6, length: 8)
        roof.firstMaterial?.diffuse.contents = NSColor(calibratedRed: 0.55, green: 0.28, blue: 0.22, alpha: 1)
        let roofNode = SCNNode(geometry: roof)
        roofNode.position = SCNVector3(0, 5, 0)
        house.addChildNode(roofNode)
        house.enumerateChildNodes { node, _ in node.castsShadow = true }
        root.addChildNode(house)
        coordinator.placeholderHouse = house

        // Lumière ambiante (relevée/abaissée selon l'heure dans updateSun).
        let ambient = SCNLight()
        ambient.type = .ambient
        ambient.intensity = 300
        let ambientNode = SCNNode()
        ambientNode.light = ambient
        root.addChildNode(ambientNode)
        coordinator.ambientLight = ambient

        // Le soleil : sphère émissive + lumière directionnelle qui la suit.
        let sunSphere = SCNSphere(radius: 3.5)
        sunSphere.firstMaterial?.diffuse.contents = NSColor.yellow
        sunSphere.firstMaterial?.emission.contents = NSColor(calibratedRed: 1, green: 0.85, blue: 0.3, alpha: 1)
        let sunNode = SCNNode(geometry: sunSphere)
        sunNode.castsShadow = false
        root.addChildNode(sunNode)
        coordinator.sunNode = sunNode

        let sunLight = SCNLight()
        sunLight.type = .directional
        sunLight.castsShadow = true
        sunLight.shadowMapSize = CGSize(width: 2048, height: 2048)
        sunLight.shadowSampleCount = 8
        sunLight.shadowRadius = 3
        sunLight.shadowColor = NSColor.black.withAlphaComponent(0.55)
        let lightNode = SCNNode()
        lightNode.light = sunLight
        lightNode.constraints = [SCNLookAtConstraint(target: house)]
        root.addChildNode(lightNode)
        coordinator.sunLight = sunLight
        coordinator.sunLightNode = lightNode

        // Conteneurs reconstruits à la volée.
        let arc = SCNNode()
        root.addChildNode(arc)
        coordinator.arcNode = arc
        let panels = SCNNode()
        root.addChildNode(panels)
        coordinator.panelsNode = panels
        let buildingsContainer = SCNNode()
        root.addChildNode(buildingsContainer)
        coordinator.buildingsNode = buildingsContainer
        let roadsContainer = SCNNode()
        root.addChildNode(roadsContainer)
        coordinator.roadsNode = roadsContainer

        // Ancres des flux d'énergie : pylône réseau au nord-est, bloc
        // batterie contre la maison. Masquables avec la couche Énergie.
        let props = SCNNode()
        root.addChildNode(props)
        coordinator.energyPropsNode = props

        let pylonMaterial = SCNMaterial()
        pylonMaterial.diffuse.contents = NSColor(calibratedWhite: 0.30, alpha: 1)
        let mast = SCNNode(geometry: SCNBox(width: 0.8, height: 9, length: 0.8, chamferRadius: 0))
        mast.geometry?.materials = [pylonMaterial]
        mast.position = SCNVector3(Self.pylonAnchor.x, 4.5, Self.pylonAnchor.z)
        mast.castsShadow = true
        props.addChildNode(mast)
        let crossarm = SCNNode(geometry: SCNBox(width: 4.5, height: 0.5, length: 0.5, chamferRadius: 0))
        crossarm.geometry?.materials = [pylonMaterial]
        crossarm.position = SCNVector3(Self.pylonAnchor.x, 7.8, Self.pylonAnchor.z)
        crossarm.castsShadow = true
        props.addChildNode(crossarm)

        let batteryGeometry = SCNBox(width: 2.6, height: 1.6, length: 1.6, chamferRadius: 0.15)
        batteryGeometry.firstMaterial?.diffuse.contents = NSColor(calibratedRed: 0.10, green: 0.35, blue: 0.35, alpha: 1)
        let battery = SCNNode(geometry: batteryGeometry)
        battery.position = SCNVector3(Self.batteryAnchor.x, 0.8, Self.batteryAnchor.z)
        battery.castsShadow = true
        props.addChildNode(battery)

        let flowsContainer = SCNNode()
        root.addChildNode(flowsContainer)
        coordinator.flowsNode = flowsContainer
        let ribbonContainer = SCNNode()
        root.addChildNode(ribbonContainer)
        coordinator.ribbonNode = ribbonContainer
        let consumptionContainer = SCNNode()
        root.addChildNode(consumptionContainer)
        coordinator.consumptionNode = consumptionContainer
        let badgeContainer = SCNNode()
        root.addChildNode(badgeContainer)
        coordinator.badgeNode = badgeContainer
    }

    // MARK: - Flux d'énergie (billes animées, à la Helios)

    private static let pylonAnchor = SCNVector3(28, 0, -22)
    private static let batteryAnchor = SCNVector3(8.5, 0, 4)
    /// Rayon du cercle horaire de la courbe de consommation — en retrait de
    /// l'arc pour ne pas se mélanger au ruban de production.
    private static let consumptionRadius = domeRadius - 14

    private func rebuildFlows(coordinator: Coordinator) {
        guard let container = coordinator.flowsNode else { return }
        container.childNodes.forEach { $0.removeFromParentNode() }

        // Panneaux → maison (production solaire).
        addBeads(to: container, count: flows.solar,
                 color: NSColor(calibratedRed: 1, green: 0.82, blue: 0.15, alpha: 1),
                 path: [SCNVector3(0, 1.2, 12), SCNVector3(0, 4.5, 7), SCNVector3(0, 2.2, 3.8)])
        // Pylône → maison (soutirage réseau / charge secteur).
        addBeads(to: container, count: flows.grid,
                 color: NSColor(calibratedRed: 1, green: 0.55, blue: 0.15, alpha: 1),
                 path: [SCNVector3(Self.pylonAnchor.x, 7.5, Self.pylonAnchor.z),
                        SCNVector3(14, 8.5, -10), SCNVector3(4.8, 2.5, 0)])
        // Maison ↔ batterie (charge / décharge).
        addBeads(to: container, count: flows.batteryCharge,
                 color: NSColor(calibratedRed: 0.30, green: 0.85, blue: 0.35, alpha: 1),
                 path: [SCNVector3(4.8, 1.6, 2), SCNVector3(Self.batteryAnchor.x, 1.4, Self.batteryAnchor.z)])
        addBeads(to: container, count: flows.batteryDischarge,
                 color: NSColor(calibratedRed: 1, green: 0.45, blue: 0.25, alpha: 1),
                 path: [SCNVector3(Self.batteryAnchor.x, 1.4, Self.batteryAnchor.z), SCNVector3(4.8, 1.6, 2)])
    }

    /// `count` billes émissives qui parcourent `path` en boucle, décalées
    /// dans le temps pour former un chapelet régulier.
    private func addBeads(to container: SCNNode, count: Int, color: NSColor, path: [SCNVector3]) {
        guard count > 0, path.count >= 2 else { return }
        // Durées proportionnelles aux longueurs de segment (vitesse constante).
        var lengths: [Double] = []
        for (a, b) in zip(path, path.dropFirst()) {
            lengths.append(Double(
                ((b.x - a.x) * (b.x - a.x) + (b.y - a.y) * (b.y - a.y) + (b.z - a.z) * (b.z - a.z))
            ).squareRoot())
        }
        let total = lengths.reduce(0, +)
        guard total > 0 else { return }
        let tripDuration = 2.4

        for index in 0..<count {
            let sphere = SCNSphere(radius: 0.45)
            sphere.firstMaterial?.diffuse.contents = color
            sphere.firstMaterial?.emission.contents = color
            let bead = SCNNode(geometry: sphere)
            bead.castsShadow = false
            bead.position = path[0]
            bead.opacity = 0

            var trip: [SCNAction] = [.fadeIn(duration: 0.1)]
            for (segment, length) in zip(path.dropFirst(), lengths) {
                trip.append(.move(to: segment, duration: tripDuration * length / total))
            }
            trip.append(.fadeOut(duration: 0.1))
            trip.append(.move(to: path[0], duration: 0))
            let loop = SCNAction.repeatForever(.sequence(trip))
            // Décalage initial pour répartir les billes le long du chemin.
            bead.runAction(.sequence([.wait(duration: tripDuration * Double(index) / Double(count)), loop]))
            container.addChildNode(bead)
        }
    }

    // MARK: - Ruban de production sur l'arc

    /// Production sous l'arc, à la Helios : la PRÉVUE (ciel clair,
    /// SolarGeometry sur les champs configurés — suit la timeline et les
    /// sliders d'orientation) en courbe jaune translucide, la RÉELLE en bâtons
    /// turquoise tous les quarts d'heure. Échelle commune (le plus haut des
    /// deux pics) : l'écart réalisé/attendu se lit directement.
    private func rebuildRibbon(coordinator: Coordinator) {
        guard let container = coordinator.ribbonNode else { return }
        container.childNodes.forEach { $0.removeFromParentNode() }
        rebuildConsumptionCurve(coordinator: coordinator)

        let startOfDay = Calendar.current.startOfDay(for: date)
        var forecast: [(anchor: SunRoadGeometry.Point3, watts: Double)] = []
        for index in stride(from: 0, to: 288, by: 3) {  // pas de 15 min
            let instant = startOfDay.addingTimeInterval(Double(index) * 300)
            let sun = SunCalc.compute(at: instant, latitude: latitude, longitude: longitude)
            guard sun.elevation > 0 else { continue }
            let watts = SolarGeometry.clearSkyWatts(for: arrays, sunElevation: sun.elevation,
                                                    sunAzimuth: sun.azimuth)
            forecast.append((SunRoadGeometry.domePoint(azimuth: sun.azimuth, elevation: sun.elevation,
                                                       radius: Self.domeRadius - 5), watts))
        }
        let forecastPeak = forecast.map(\.watts).max() ?? 0
        let scale = max(curvePeak, forecastPeak, 1)

        if forecastPeak > 1 {
            let expected = SCNMaterial()
            expected.diffuse.contents = NSColor(calibratedRed: 1, green: 0.80, blue: 0.30, alpha: 0.55)
            expected.emission.contents = NSColor(calibratedRed: 0.45, green: 0.33, blue: 0.08, alpha: 1)
            let points = forecast.map {
                SunRoadGeometry.Point3(x: $0.anchor.x,
                                       y: $0.anchor.y - (1 + 16 * $0.watts / scale),
                                       z: $0.anchor.z)
            }
            for (a, b) in zip(points, points.dropFirst()) {
                container.addChildNode(Self.segment(from: a, to: b, radius: 0.22, material: expected))
            }
        }

        guard showRibbon, curvePeak > 0, !todayCurve.isEmpty else { return }
        let material = SCNMaterial()
        material.diffuse.contents = NSColor(calibratedRed: 0.15, green: 0.75, blue: 0.70, alpha: 1)
        material.emission.contents = NSColor(calibratedRed: 0.05, green: 0.30, blue: 0.28, alpha: 1)

        for index in stride(from: 0, to: todayCurve.count, by: 3) {  // pas de 15 min
            let watts = todayCurve[index]
            guard watts > 1 else { continue }
            let instant = startOfDay.addingTimeInterval(Double(index) * 300)
            let sun = SunCalc.compute(at: instant, latitude: latitude, longitude: longitude)
            guard sun.elevation > 0 else { continue }
            let p = SunRoadGeometry.domePoint(azimuth: sun.azimuth, elevation: sun.elevation,
                                             radius: Self.domeRadius - 5)
            let height = 1 + 16 * watts / scale
            let bar = SCNCylinder(radius: 0.35, height: height)
            bar.materials = [material]
            let node = SCNNode(geometry: bar)
            node.position = SCNVector3(p.x, p.y - height / 2, p.z)
            node.castsShadow = false
            container.addChildNode(node)
        }
    }

    /// Consommation maison : courbe CONTINUE sur le cercle horaire complet, à
    /// la Helios — chaque tranche de 5 min est placée à l'azimut du soleil de
    /// cet instant (le cercle continue côté nord la nuit), près du sol,
    /// hauteur ∝ watts sur son propre pic. Piquets verticaux tous les quarts
    /// d'heure : la grille qui rend la hauteur lisible (les pointillés
    /// d'Helios).
    private func rebuildConsumptionCurve(coordinator: Coordinator) {
        guard let container = coordinator.consumptionNode else { return }
        container.childNodes.forEach { $0.removeFromParentNode() }
        guard showRibbon, homePeak > 1, homeCurve.count > 1 else { return }

        let lineMaterial = SCNMaterial()
        lineMaterial.diffuse.contents = NSColor(calibratedRed: 0.35, green: 0.62, blue: 0.95, alpha: 1)
        lineMaterial.emission.contents = NSColor(calibratedRed: 0.16, green: 0.32, blue: 0.60, alpha: 1)
        let postMaterial = SCNMaterial()
        postMaterial.diffuse.contents = NSColor(calibratedRed: 0.35, green: 0.62, blue: 0.95, alpha: 0.35)

        let startOfDay = Calendar.current.startOfDay(for: date)
        let points: [SunRoadGeometry.Point3] = homeCurve.enumerated().map { index, watts in
            let instant = startOfDay.addingTimeInterval(Double(index) * 300)
            let sun = SunCalc.compute(at: instant, latitude: latitude, longitude: longitude)
            let ground = SunRoadGeometry.domePoint(azimuth: sun.azimuth, elevation: 0,
                                                   radius: Self.consumptionRadius)
            return SunRoadGeometry.Point3(x: ground.x,
                                          y: 0.5 + 26 * max(watts, 0) / homePeak,
                                          z: ground.z)
        }
        for (a, b) in zip(points, points.dropFirst()) {
            container.addChildNode(Self.segment(from: a, to: b, radius: 0.28, material: lineMaterial))
        }
        for index in stride(from: 0, to: points.count, by: 3) where points[index].y > 0.8 {
            let top = points[index]
            container.addChildNode(Self.segment(
                from: SunRoadGeometry.Point3(x: top.x, y: 0.1, z: top.z),
                to: top, radius: 0.09, material: postMaterial))
        }
    }

    /// « ⌂ n W » face caméra au-dessus de la maison (à la Helios).
    private func rebuildBadge(coordinator: Coordinator) {
        guard let container = coordinator.badgeNode else { return }
        container.childNodes.forEach { $0.removeFromParentNode() }
        guard homeWatts > 0.5 else { return }

        let text = SCNText(string: "⌂ \(Int(homeWatts)) W", extrusionDepth: 0.4)
        text.font = NSFont.systemFont(ofSize: 4.2, weight: .bold)
        text.flatness = 0.05
        text.firstMaterial?.diffuse.contents = NSColor.white
        text.firstMaterial?.emission.contents = NSColor(calibratedRed: 0.45, green: 0.70, blue: 1, alpha: 1)
        let node = SCNNode(geometry: text)
        let (minB, maxB) = text.boundingBox
        node.pivot = SCNMatrix4MakeTranslation((minB.x + maxB.x) / 2, minB.y, 0)
        node.position = SCNVector3(0, 13.5, 0)
        node.constraints = [SCNBillboardConstraint()]
        node.castsShadow = false
        container.addChildNode(node)
    }

    // MARK: - Le quartier (Overpass/OSM)

    private func rebuildBuildings(coordinator: Coordinator) {
        guard let container = coordinator.buildingsNode else { return }
        container.childNodes.forEach { $0.removeFromParentNode() }
        let buildings = neighborhood.buildings
        guard !buildings.isEmpty else { return }

        // La maison = le bâtiment dont le centre est le plus proche de la
        // position configurée (dans un rayon plausible).
        let houseIndex = buildings.indices.min(by: {
            GeoProjection.distance(from: buildings[$0], originLat: latitude, originLon: longitude)
                < GeoProjection.distance(from: buildings[$1], originLat: latitude, originLon: longitude)
        }).flatMap { index in
            GeoProjection.distance(from: buildings[index], originLat: latitude, originLon: longitude) < 25
                ? index : nil
        }

        let neighborMaterial = SCNMaterial()
        neighborMaterial.diffuse.contents = NSColor(calibratedWhite: 0.82, alpha: 1)
        let houseMaterial = SCNMaterial()
        houseMaterial.diffuse.contents = NSColor(calibratedRed: 0.98, green: 0.80, blue: 0.35, alpha: 1)
        houseMaterial.emission.contents = NSColor(calibratedRed: 0.25, green: 0.18, blue: 0.03, alpha: 1)

        for (index, building) in buildings.enumerated() {
            let path = NSBezierPath()
            path.flatness = 0.1
            for (i, point) in building.points.enumerated() {
                let m = GeoProjection.meters(lat: point.lat, lon: point.lon,
                                             originLat: latitude, originLon: longitude)
                let p = NSPoint(x: m.east, y: m.north)
                i == 0 ? path.move(to: p) : path.line(to: p)
            }
            path.close()

            let shape = SCNShape(path: path, extrusionDepth: CGFloat(building.height))
            shape.materials = [index == houseIndex ? houseMaterial : neighborMaterial]
            let node = SCNNode(geometry: shape)
            // L'extrusion SCNShape est le long de Z, centrée : basculer le plan
            // (est, nord) au sol — (e, n, t) → (e, t, -n) — puis poser au sol.
            node.eulerAngles.x = -.pi / 2
            node.position = SCNVector3(0, building.height / 2, 0)
            node.castsShadow = true
            node.name = "building-\(index)"   // hit-testing « Définir ma maison »
            container.addChildNode(node)
        }
    }

    /// Les routes : rubans plats posés juste au-dessus du sol (pas d'ombre
    /// portée), un disque à chaque sommet interne pour arrondir les virages.
    private func rebuildRoads(coordinator: Coordinator) {
        guard let container = coordinator.roadsNode else { return }
        container.childNodes.forEach { $0.removeFromParentNode() }
        guard !neighborhood.roads.isEmpty else { return }

        let asphalt = SCNMaterial()
        asphalt.diffuse.contents = NSColor(calibratedWhite: 0.32, alpha: 1)
        let footpath = SCNMaterial()
        footpath.diffuse.contents = NSColor(calibratedRed: 0.62, green: 0.58, blue: 0.50, alpha: 1)

        for road in neighborhood.roads {
            let material = road.footpath ? footpath : asphalt
            // Les chaussées au ras du sol, les chemins un cheveu au-dessus
            // pour éviter le z-fighting aux croisements.
            let y = road.footpath ? 0.10 : 0.07
            let projected = road.points.map {
                GeoProjection.meters(lat: $0.lat, lon: $0.lon, originLat: latitude, originLon: longitude)
            }
            for (a, b) in zip(projected, projected.dropFirst()) {
                let dx = b.east - a.east
                let dz = -(b.north - a.north)
                let length = (dx * dx + dz * dz).squareRoot()
                guard length > 0.1 else { continue }
                let slab = SCNBox(width: length, height: 0.06, length: road.width, chamferRadius: 0)
                slab.materials = [material]
                let node = SCNNode(geometry: slab)
                node.position = SCNVector3((a.east + b.east) / 2, y, (-a.north - b.north) / 2)
                node.eulerAngles.y = CGFloat(-atan2(dz, dx))
                node.castsShadow = false
                container.addChildNode(node)
            }
            for point in projected.dropFirst().dropLast() {
                let disc = SCNCylinder(radius: road.width / 2, height: 0.06)
                disc.materials = [material]
                let node = SCNNode(geometry: disc)
                node.position = SCNVector3(point.east, y, -point.north)
                node.castsShadow = false
                container.addChildNode(node)
            }
        }
    }

    // MARK: - Arc du jour

    private func rebuildSunArc(coordinator: Coordinator) {
        guard let arc = coordinator.arcNode else { return }
        arc.childNodes.forEach { $0.removeFromParentNode() }

        let track = SunCalc.track(on: date, latitude: latitude, longitude: longitude, stepMinutes: 10)
            .filter { $0.elevation > -1 }
        guard track.count > 1 else { return }

        let material = SCNMaterial()
        material.diffuse.contents = NSColor(calibratedRed: 1, green: 0.75, blue: 0.2, alpha: 1)
        material.emission.contents = NSColor(calibratedRed: 0.9, green: 0.6, blue: 0.1, alpha: 1)

        // Polyline en segments cylindriques (les primitives .line font 1 px).
        var previous = SunRoadGeometry.domePoint(azimuth: track[0].azimuth,
                                                elevation: track[0].elevation,
                                                radius: Self.domeRadius)
        for position in track.dropFirst() {
            let current = SunRoadGeometry.domePoint(azimuth: position.azimuth,
                                                   elevation: position.elevation,
                                                   radius: Self.domeRadius)
            arc.addChildNode(Self.segment(from: previous, to: current, radius: 0.5, material: material))
            previous = current
        }

        // Un repère par heure pleine, pour lire l'échelle du temps.
        let calendar = Calendar.current
        for position in track where calendar.component(.minute, from: position.date) < 10 {
            let dot = SCNSphere(radius: 1.1)
            dot.firstMaterial?.emission.contents = NSColor.white
            let node = SCNNode(geometry: dot)
            let p = SunRoadGeometry.domePoint(azimuth: position.azimuth,
                                             elevation: position.elevation,
                                             radius: Self.domeRadius)
            node.position = SCNVector3(p.x, p.y, p.z)
            node.castsShadow = false
            arc.addChildNode(node)
        }
    }

    private static func segment(from a: SunRoadGeometry.Point3, to b: SunRoadGeometry.Point3,
                                radius: Double, material: SCNMaterial) -> SCNNode {
        let dx = b.x - a.x, dy = b.y - a.y, dz = b.z - a.z
        let length = (dx * dx + dy * dy + dz * dz).squareRoot()
        let cylinder = SCNCylinder(radius: radius, height: length)
        cylinder.materials = [material]
        let node = SCNNode(geometry: cylinder)
        node.position = SCNVector3((a.x + b.x) / 2, (a.y + b.y) / 2, (a.z + b.z) / 2)
        // Orienter l'axe Y du cylindre le long du segment.
        let up = SCNVector3(0, 1, 0)
        let dir = SCNVector3(dx / length, dy / length, dz / length)
        let dot = max(-1, min(1, Double(up.x * dir.x + up.y * dir.y + up.z * dir.z)))
        let axis = SCNVector3(up.y * dir.z - up.z * dir.y,
                              up.z * dir.x - up.x * dir.z,
                              up.x * dir.y - up.y * dir.x)
        let axisLength = Double(axis.x * axis.x + axis.y * axis.y + axis.z * axis.z).squareRoot()
        if axisLength > 1e-6 {
            node.rotation = SCNVector4(axis.x / CGFloat(axisLength),
                                       axis.y / CGFloat(axisLength),
                                       axis.z / CGFloat(axisLength),
                                       CGFloat(acos(dot)))
        }
        node.castsShadow = false
        return node
    }

    // MARK: - Champs de panneaux

    private func rebuildPanels(coordinator: Coordinator) {
        guard let container = coordinator.panelsNode else { return }
        container.childNodes.forEach { $0.removeFromParentNode() }

        // Une rangée au sud de la maison, espacée d'après la taille des champs.
        var offsetX = -Double(arrays.count - 1)
        for array in arrays {
            let area = SunRoadGeometry.panelArea(peakWatts: array.peakWatts)
            let width = (area * 1.7).squareRoot()
            let depth = area / width

            let panel = SCNBox(width: CGFloat(width), height: 0.12, length: CGFloat(depth), chamferRadius: 0.02)
            panel.firstMaterial?.diffuse.contents = NSColor(calibratedRed: 0.10, green: 0.16, blue: 0.32, alpha: 1)
            panel.firstMaterial?.specular.contents = NSColor.white
            let node = SCNNode(geometry: panel)

            // Orientation réelle : posé à plat, penché de `tilt` vers son
            // azimut. Pivot en pied de panneau pour qu'il repose au sol.
            let holder = SCNNode()
            holder.eulerAngles.y = CGFloat(-(array.azimuth - 180) * .pi / 180)
            node.eulerAngles.x = CGFloat(-array.tilt * .pi / 180)
            node.pivot = SCNMatrix4MakeTranslation(0, 0, CGFloat(-depth / 2))
            node.position = SCNVector3(0, 0.4, 0)
            node.castsShadow = true
            holder.addChildNode(node)
            holder.position = SCNVector3(offsetX, 0, 10 + depth / 2)
            container.addChildNode(holder)

            offsetX += width + 1.5
        }
    }

    // MARK: - Position du soleil et lumière

    private func updateSun(coordinator: Coordinator) {
        let ephemeris = SunCalc.compute(at: date, latitude: latitude, longitude: longitude)
        let elevation = ephemeris.elevation
        let factor = SunRoadGeometry.daylightFactor(elevation: elevation)

        let p = SunRoadGeometry.domePoint(azimuth: ephemeris.azimuth,
                                         elevation: max(elevation, 0),
                                         radius: Self.domeRadius)
        coordinator.sunNode?.position = SCNVector3(p.x, p.y, p.z)
        coordinator.sunNode?.isHidden = elevation <= 0
        coordinator.sunLightNode?.position = SCNVector3(p.x, p.y, p.z)
        // Les nuages voilent la lumière directe (ombres plus douces via
        // l'intensité) et grisent légèrement l'ambiance.
        let cloud = min(max(cloudCover, 0), 1)
        coordinator.sunLight?.intensity = elevation > 0 ? (400 + 700 * factor) * (1 - 0.55 * cloud) : 0
        coordinator.ambientLight?.intensity = (120 + 280 * factor) * (1 - 0.20 * cloud)

        // Ciel : nuit → aube/crépuscule → plein jour, interpolation simple.
        let night = (r: 0.05, g: 0.07, b: 0.15)
        let dusk = (r: 0.85, g: 0.55, b: 0.35)
        let day = (r: 0.42, g: 0.65, b: 0.90)
        let sky: (r: Double, g: Double, b: Double)
        if factor < 0.5 {
            let t = factor * 2
            sky = (night.r + (dusk.r - night.r) * t,
                   night.g + (dusk.g - night.g) * t,
                   night.b + (dusk.b - night.b) * t)
        } else {
            let t = (factor - 0.5) * 2
            sky = (dusk.r + (day.r - dusk.r) * t,
                   dusk.g + (day.g - dusk.g) * t,
                   dusk.b + (day.b - dusk.b) * t)
        }
        // Voile gris proportionnel à la couverture nuageuse.
        let gray = (r: 0.55, g: 0.58, b: 0.62)
        let veil = 0.45 * cloud * factor  // la nuit reste la nuit
        coordinator.scene?.background.contents = NSColor(
            calibratedRed: sky.r + (gray.r - sky.r) * veil,
            green: sky.g + (gray.g - sky.g) * veil,
            blue: sky.b + (gray.b - sky.b) * veil,
            alpha: 1
        )
    }

    // MARK: - Coordinator

    final class Coordinator {
        weak var view: SCNView?
        var scene: SCNScene?
        var sunNode: SCNNode?
        var sunLight: SCNLight?
        var sunLightNode: SCNNode?
        var ambientLight: SCNLight?
        var arcNode: SCNNode?
        var panelsNode: SCNNode?
        var buildingsNode: SCNNode?
        var roadsNode: SCNNode?
        var compassNode: SCNNode?
        var placeholderHouse: SCNNode?
        var flowsNode: SCNNode?
        var energyPropsNode: SCNNode?
        var ribbonNode: SCNNode?
        var consumptionNode: SCNNode?
        var badgeNode: SCNNode?
        var badgeKey = Int.min
        var arcKey = ""
        var originKey = ""
        var arraysKey: [PanelArray] = []
        var neighborhoodKey = SunRoadNeighborhood.empty
        var flowsKey = SunRoadFlows()
        var ribbonKey = ""
    }
}

/// SCNView qui sait désigner un bâtiment au clic (mode « Définir ma
/// maison »). Avec `allowsCameraControl`, les gesture recognizers internes
/// de SCNView passent avant `mouseDown` — on ajoute donc notre propre
/// NSClickGestureRecognizer, qui coexiste avec l'orbite (elle utilise le
/// drag, pas le clic).
final class PickableSCNView: SCNView {
    var pickingEnabled = false
    var onPickBuilding: ((Int) -> Void)?
    private var clickInstalled = false

    func installClickRecognizer() {
        guard !clickInstalled else { return }
        clickInstalled = true
        addGestureRecognizer(NSClickGestureRecognizer(target: self, action: #selector(handleClick(_:))))
    }

    @objc private func handleClick(_ recognizer: NSClickGestureRecognizer) {
        guard pickingEnabled else { return }
        let point = recognizer.location(in: self)
        guard let node = hitTest(point, options: [.searchMode: SCNHitTestSearchMode.closest.rawValue]).first?.node,
              let name = buildingName(of: node),
              let index = Int(name.dropFirst("building-".count)) else { return }
        onPickBuilding?(index)
    }

    /// Remonte la hiérarchie jusqu'au nœud nommé `building-<i>`.
    private func buildingName(of node: SCNNode) -> String? {
        var current: SCNNode? = node
        while let candidate = current {
            if let name = candidate.name, name.hasPrefix("building-") { return name }
            current = candidate.parent
        }
        return nil
    }
}
