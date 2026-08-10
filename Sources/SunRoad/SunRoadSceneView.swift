import SceneKit
import SwiftUI

/// Ce que la scène SunRoad affiche — piloté par les checkboxes du HUD.
struct SunRoadVisibility: Equatable {
    var buildings = true
    var roads = true
    var arc = true
    var panels = true
    var compass = true
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

    private static let domeRadius = 140.0

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> SCNView {
        let view = SCNView()
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
        }
        if coordinator.neighborhoodKey != neighborhood {
            coordinator.neighborhoodKey = neighborhood
            rebuildBuildings(coordinator: coordinator)
            rebuildRoads(coordinator: coordinator)
        }
        // Visibilité par couche (checkboxes du HUD). La maison placeholder
        // ne vaut que sans données OSM ; le soleil-lumière reste toujours là.
        coordinator.buildingsNode?.isHidden = !visibility.buildings
        coordinator.placeholderHouse?.isHidden = !visibility.buildings || !neighborhood.buildings.isEmpty
        coordinator.roadsNode?.isHidden = !visibility.roads
        coordinator.arcNode?.isHidden = !visibility.arc
        coordinator.panelsNode?.isHidden = !visibility.panels
        coordinator.compassNode?.isHidden = !visibility.compass
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
        coordinator.sunLight?.intensity = elevation > 0 ? 400 + 700 * factor : 0
        coordinator.ambientLight?.intensity = 120 + 280 * factor

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
        coordinator.scene?.background.contents = NSColor(calibratedRed: sky.r, green: sky.g, blue: sky.b, alpha: 1)
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
        var arcKey = ""
        var arraysKey: [PanelArray] = []
        var neighborhoodKey = SunRoadNeighborhood.empty
    }
}
