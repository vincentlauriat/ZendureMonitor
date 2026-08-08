import SwiftUI

/// Compas solaire vu du dessus : l'azimut fait le tour du cadran, l'élévation
/// va de l'horizon (cercle extérieur) au zénith (centre). On y lit d'un coup
/// d'œil vers quelle partie du ciel chaque champ de panneaux est tourné — les
/// courbes d'iso-incidence à 25° et 50° autour de sa normale — et où le soleil
/// se trouve par rapport à elles.
struct SunCompassView: View {
    var sun: SunCalc.Ephemeris
    var todayTrack: [SunCalc.Position]
    var solsticeTracks: [SkyDomeView.SolsticeTrack]
    var arrays: [PanelArray]
    var now: Date

    var body: some View {
        GeometryReader { geo in
            let layout = PolarLayout(size: geo.size)
            ZStack {
                Circle()
                    .fill(RadialGradient(colors: [Color.primary.opacity(0.03), Color.primary.opacity(0.09)],
                                         center: .center, startRadius: 0, endRadius: layout.radius))
                    .frame(width: layout.radius * 2, height: layout.radius * 2)
                    .position(layout.center)

                Canvas { context, _ in
                    drawGrid(in: context, layout: layout)
                    drawTracks(in: context, layout: layout)
                    drawArrays(in: context, layout: layout)
                }

                markers(layout)
            }
        }
    }

    // MARK: - Cadran

    private func drawGrid(in context: GraphicsContext, layout: PolarLayout) {
        for elevation in [0.0, 30, 60] {
            let radius = layout.radius(elevation: elevation)
            let rect = CGRect(x: layout.center.x - radius, y: layout.center.y - radius,
                              width: radius * 2, height: radius * 2)
            context.stroke(Path(ellipseIn: rect),
                           with: .color(.secondary.opacity(elevation == 0 ? 0.45 : 0.22)),
                           style: StrokeStyle(lineWidth: 1, dash: elevation == 0 ? [] : [2, 4]))
            if elevation > 0 {
                context.draw(Text(verbatim: "\(Int(elevation))°")
                    .font(.system(size: 8, design: .rounded))
                    .foregroundStyle(.secondary),
                             at: CGPoint(x: layout.center.x + 1, y: layout.center.y - radius - 5),
                             anchor: .leading)
            }
        }

        for azimuth in stride(from: 0.0, to: 360, by: 30) {
            let outer = layout.point(azimuth: azimuth, elevation: 0)
            let inner = layout.point(azimuth: azimuth, elevation: azimuth.truncatingRemainder(dividingBy: 90) == 0 ? 90 : 5)
            var tick = Path()
            tick.move(to: outer)
            tick.addLine(to: inner)
            context.stroke(tick, with: .color(.secondary.opacity(azimuth.truncatingRemainder(dividingBy: 90) == 0 ? 0.16 : 0.22)),
                           style: StrokeStyle(lineWidth: azimuth.truncatingRemainder(dividingBy: 90) == 0 ? 1 : 1,
                                              dash: azimuth.truncatingRemainder(dividingBy: 90) == 0 ? [1, 5] : []))
        }

        let cardinals: [(Double, String)] = [(0, String(localized: "N")), (90, String(localized: "E")),
                                             (180, String(localized: "S")), (270, String(localized: "O"))]
        for (azimuth, label) in cardinals {
            let base = layout.point(azimuth: azimuth, elevation: 0)
            let offset = CGPoint(x: (base.x - layout.center.x) * 0.13, y: (base.y - layout.center.y) * 0.13)
            context.draw(Text(label).font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(azimuth == 180 ? Color.orange : Color.secondary),
                         at: CGPoint(x: base.x + offset.x, y: base.y + offset.y), anchor: .center)
        }
    }

    // MARK: - Courses

    private func drawTracks(in context: GraphicsContext, layout: PolarLayout) {
        for solstice in solsticeTracks {
            context.stroke(path(for: solstice.track, layout: layout),
                           with: .color(.secondary.opacity(0.35)),
                           style: StrokeStyle(lineWidth: 1, dash: [2, 4]))
        }
        // Course déjà parcourue en vif, reste du jour en atténué : on voit d'un
        // coup d'œil où l'on en est dans la journée.
        let split = SunTrack.split(todayTrack, at: now)
        context.stroke(path(for: split.remaining, layout: layout),
                       with: .color(.orange.opacity(0.3)),
                       style: StrokeStyle(lineWidth: 2, lineCap: .round))
        context.stroke(path(for: split.traveled, layout: layout),
                       with: .linearGradient(Gradient(colors: [.orange, .yellow]),
                                             startPoint: CGPoint(x: layout.center.x - layout.radius, y: 0),
                                             endPoint: CGPoint(x: layout.center.x + layout.radius, y: 0)),
                       style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
    }

    private func path(for track: [SunCalc.Position], layout: PolarLayout) -> Path {
        var path = Path()
        var started = false
        for position in track {
            guard position.elevation > 0 else { started = false; continue }
            let point = layout.point(azimuth: position.azimuth, elevation: position.elevation)
            if started { path.addLine(to: point) } else { path.move(to: point); started = true }
        }
        return path
    }

    // MARK: - Champs de panneaux

    private func drawArrays(in context: GraphicsContext, layout: PolarLayout) {
        for (index, array) in arrays.enumerated() {
            let color = ArrayPalette.color(index)

            // Direction visée par le panneau, du zénith vers l'horizon.
            var aim = Path()
            aim.move(to: layout.point(azimuth: array.azimuth, elevation: 88))
            aim.addLine(to: layout.point(azimuth: array.azimuth, elevation: 0))
            context.stroke(aim, with: .color(color.opacity(0.25)),
                           style: StrokeStyle(lineWidth: 1, dash: [3, 4]))

            for (angle, opacity) in [(25.0, 0.55), (50.0, 0.28)] {
                let locus = SolarGeometry.incidenceLocus(tilt: array.tilt, azimuth: array.azimuth,
                                                         angle: angle)
                var path = Path()
                var started = false
                for direction in locus {
                    guard direction.elevation > 0 else { started = false; continue }
                    let point = layout.point(azimuth: direction.azimuth, elevation: direction.elevation)
                    if started { path.addLine(to: point) } else { path.move(to: point); started = true }
                }
                context.stroke(path, with: .color(color.opacity(opacity)),
                               style: StrokeStyle(lineWidth: 1.2, lineCap: .round,
                                                  dash: angle > 30 ? [3, 3] : []))
            }
        }
    }

    // MARK: - Marqueurs animés

    private func markers(_ layout: PolarLayout) -> some View {
        ZStack {
            ForEach(Array(arrays.enumerated()), id: \.element.id) { index, array in
                let incidence = SolarGeometry.incidenceAngle(sunElevation: sun.elevation,
                                                             sunAzimuth: sun.azimuth,
                                                             tilt: array.tilt, azimuth: array.azimuth)
                PanelGlyph(color: ArrayPalette.color(index))
                    .frame(width: 16, height: 12)
                    .shadow(color: sun.elevation > 0 && incidence < 25
                            ? ArrayPalette.color(index).opacity(0.9) : .clear, radius: 6)
                    .position(layout.point(azimuth: array.azimuth, elevation: 90 - array.tilt))
            }

            if sun.elevation > 0 {
                AnimatedSun()
                    .scaleEffect(0.62)
                    .position(layout.point(azimuth: sun.azimuth, elevation: sun.elevation))
            } else {
                Circle()
                    .fill(.indigo.opacity(0.5))
                    .frame(width: 9, height: 9)
                    .position(layout.point(azimuth: sun.azimuth, elevation: 0))
            }
        }
    }
}

/// Projection polaire du ciel : centre = zénith, cercle extérieur = horizon,
/// nord en haut et azimuts dans le sens des aiguilles d'une montre.
private struct PolarLayout {
    var center: CGPoint
    var radius: CGFloat

    init(size: CGSize) {
        center = CGPoint(x: size.width / 2, y: size.height / 2)
        // La marge laisse la place aux lettres cardinales, posées 13 % au-delà
        // du cercle d'horizon : trop serré, elles sont rognées par le cadre.
        radius = max(10, min(size.width, size.height) / 2 - 22)
    }

    func radius(elevation: Double) -> CGFloat {
        radius * CGFloat(1 - min(90, max(0, elevation)) / 90)
    }

    func point(azimuth: Double, elevation: Double) -> CGPoint {
        let distance = radius(elevation: elevation)
        let angle = azimuth * .pi / 180
        return CGPoint(x: center.x + distance * CGFloat(sin(angle)),
                       y: center.y - distance * CGFloat(cos(angle)))
    }
}
