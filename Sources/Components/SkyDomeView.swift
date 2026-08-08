import SwiftUI

/// Dôme céleste : la course réelle du soleil (élévation × azimut) sur un ciel
/// dont la couleur suit la hauteur du soleil, avec les arcs des solstices en
/// repère, la production mesurée du jour en pied, et la normale de chaque champ
/// de panneaux projetée dans le même repère — quand le soleil rejoint un
/// marqueur, ce champ est à son incidence idéale.
///
/// Les animations (halo, rayons, scintillement) sont déclaratives et sans
/// `TimelineView` : elles tournent côté Core Animation, et la vue au repos —
/// celle que rend `ImageRenderer` pour la documentation — est complète.
struct SkyDomeView: View {
    var sun: SunCalc.Ephemeris
    var todayTrack: [SunCalc.Position]
    var solsticeTracks: [SolsticeTrack]
    var arrays: [PanelArray]
    var curve: [Double]
    var peakW: Double
    var now: Date

    struct SolsticeTrack {
        var label: String
        var track: [SunCalc.Position]
    }

    var body: some View {
        GeometryReader { geo in
            let layout = SkyLayout(size: geo.size, todayTrack: todayTrack,
                                   solsticeTracks: solsticeTracks, arrays: arrays)
            ZStack {
                SkyBackground(elevation: sun.elevation)
                Canvas { context, _ in draw(in: context, layout: layout) }
                panelMarkers(layout)
                sunMarker(layout)
            }
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    // MARK: - Calques statiques (Canvas)

    private func draw(in context: GraphicsContext, layout: SkyLayout) {
        drawProduction(in: context, layout: layout)
        drawPanelAim(in: context, layout: layout)
        for solstice in layout.solstices {
            drawTrack(solstice.points, in: context, layout: layout,
                      shading: .color(.white.opacity(0.28)),
                      style: StrokeStyle(lineWidth: 1, dash: [2, 4]))
            if let apex = solstice.points.max(by: { $0.elevation < $1.elevation }) {
                let point = layout.point(azimuth: apex.azimuth, elevation: apex.elevation)
                context.draw(Text(solstice.label).font(.system(size: 9)).foregroundStyle(.white.opacity(0.5)),
                             at: CGPoint(x: point.x, y: point.y - 9), anchor: .center)
            }
        }
        // Course déjà parcourue en vif, reste du jour en atténué.
        let split = SunTrack.split(layout.today, at: now)
        drawTrack(split.remaining, in: context, layout: layout,
                  shading: .color(.white.opacity(0.45)),
                  style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
        drawTrack(split.traveled, in: context, layout: layout,
                  shading: .linearGradient(Gradient(colors: [.orange, .yellow, .white]),
                                           startPoint: CGPoint(x: layout.plot.minX, y: 0),
                                           endPoint: CGPoint(x: layout.plot.maxX, y: 0)),
                  style: StrokeStyle(lineWidth: 2.6, lineCap: .round))
        drawHourTicks(in: context, layout: layout)
        drawHorizon(in: context, layout: layout)
    }

    private func drawTrack(_ points: [SunCalc.Position], in context: GraphicsContext,
                           layout: SkyLayout, shading: GraphicsContext.Shading,
                           style: StrokeStyle) {
        var path = Path()
        var started = false
        for position in points where position.elevation > 0 {
            let point = layout.point(azimuth: position.azimuth, elevation: position.elevation)
            if started { path.addLine(to: point) } else { path.move(to: point); started = true }
        }
        guard started else { return }
        context.stroke(path, with: shading, style: style)
    }

    /// Production mesurée du jour, posée sur l'axe des azimuts : chaque tranche
    /// de 5 min est placée là où le soleil se trouvait à ce moment-là.
    private func drawProduction(in context: GraphicsContext, layout: SkyLayout) {
        guard let sampler = layout.sampler, curve.isEmpty == false else { return }
        let maxValue = max(peakW, curve.max() ?? 1, 1)
        let height = layout.plot.height * 0.42
        let dayStart = Calendar.current.startOfDay(for: now)

        var path = Path()
        var first: CGPoint?
        var last: CGPoint?
        for (index, value) in curve.enumerated() {
            let instant = dayStart.addingTimeInterval(Double(index) * 300)
            guard let sample = sampler.sample(at: instant), sample.elevation > 0 else { continue }
            let x = layout.x(azimuth: sample.azimuth)
            let y = layout.baseline - CGFloat(value / maxValue) * height
            let point = CGPoint(x: x, y: y)
            if first == nil {
                path.move(to: CGPoint(x: x, y: layout.baseline))
                first = point
            }
            path.addLine(to: point)
            last = point
        }
        guard let last else { return }
        path.addLine(to: CGPoint(x: last.x, y: layout.baseline))
        path.closeSubpath()

        context.fill(path, with: .linearGradient(
            Gradient(colors: [Color.yellow.opacity(0.55), Color.yellow.opacity(0.06)]),
            startPoint: CGPoint(x: 0, y: layout.baseline - height),
            endPoint: CGPoint(x: 0, y: layout.baseline)))
        context.stroke(path, with: .color(.yellow.opacity(0.65)), lineWidth: 1)
    }

    /// Verticale d'azimut de chaque champ, du marqueur jusqu'à l'horizon : elle
    /// dit vers quel point du tour d'horizon il est tourné. Les contours
    /// d'iso-incidence, eux, passent près du zénith où cette projection les
    /// étalerait sur tout le cadran — le compas s'en charge.
    private func drawPanelAim(in context: GraphicsContext, layout: SkyLayout) {
        for (index, panel) in layout.panels.enumerated() {
            var aim = Path()
            aim.move(to: layout.point(azimuth: panel.azimuth, elevation: panel.normalElevation))
            aim.addLine(to: CGPoint(x: layout.x(azimuth: panel.azimuth), y: layout.baseline))
            context.stroke(aim, with: .color(ArrayPalette.color(index).opacity(0.35)),
                           style: StrokeStyle(lineWidth: 1, dash: [2, 4]))
        }
    }

    private func drawHourTicks(in context: GraphicsContext, layout: SkyLayout) {
        let calendar = Calendar.current
        // Le soleil et les marqueurs de champ masqueraient le libellé : on le saute.
        var markers = layout.panels.map {
            layout.point(azimuth: $0.azimuth, elevation: $0.normalElevation)
        }
        if sun.elevation > 0 {
            markers.append(layout.point(azimuth: layout.azimuthInDomain(sun.azimuth),
                                        elevation: sun.elevation))
        }
        for position in layout.today where position.elevation > 0 {
            let minute = calendar.component(.minute, from: position.date)
            guard minute < 6 else { continue }   // pas d'échantillon pile à l'heure : le premier de l'heure
            let point = layout.point(azimuth: position.azimuth, elevation: position.elevation)
            context.fill(Path(ellipseIn: CGRect(x: point.x - 1.6, y: point.y - 1.6, width: 3.2, height: 3.2)),
                         with: .color(.white.opacity(0.55)))
            let hour = calendar.component(.hour, from: position.date)
            let label = CGPoint(x: point.x, y: point.y - 11)
            let crowded = markers.contains { hypot($0.x - label.x, $0.y - label.y) < 24 }
            if hour.isMultiple(of: 2), crowded == false {
                context.draw(Text(position.date.formatted(.dateTime.hour()))
                    .font(.system(size: 9, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55)),
                             at: label, anchor: .center)
            }
        }
    }

    private func drawHorizon(in context: GraphicsContext, layout: SkyLayout) {
        var horizon = Path()
        horizon.move(to: CGPoint(x: layout.plot.minX - 6, y: layout.baseline))
        horizon.addLine(to: CGPoint(x: layout.plot.maxX + 6, y: layout.baseline))
        context.stroke(horizon, with: .color(.white.opacity(0.35)), lineWidth: 1)

        for cardinal in layout.cardinals {
            let x = layout.x(azimuth: cardinal.azimuth)
            var tick = Path()
            tick.move(to: CGPoint(x: x, y: layout.baseline))
            tick.addLine(to: CGPoint(x: x, y: layout.baseline + 4))
            context.stroke(tick, with: .color(.white.opacity(0.35)), lineWidth: 1)
            context.draw(Text(cardinal.label)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.7)),
                         at: CGPoint(x: x, y: layout.baseline + 12), anchor: .center)
        }
    }

    // MARK: - Calques animés

    /// Le soleil n'est dessiné que dans la portion de ciel tracée : la nuit, il
    /// passe au nord, hors cadre — mieux vaut ne rien montrer que le coller au
    /// bord comme s'il était là.
    @ViewBuilder
    private func sunMarker(_ layout: SkyLayout) -> some View {
        let azimuth = layout.azimuthInDomain(sun.azimuth)
        if azimuth >= layout.azMin, azimuth <= layout.azMax {
            let point = layout.point(azimuth: azimuth, elevation: sun.elevation)
            let below = sun.elevation <= 0
            AnimatedSun(dimmed: below)
                .position(x: point.x, y: below ? layout.baseline + 6 : point.y)
                .opacity(below ? 0.45 : 1)
        }
    }

    private func panelMarkers(_ layout: SkyLayout) -> some View {
        ZStack {
            ForEach(Array(layout.panels.enumerated()), id: \.element.array.id) { index, panel in
                let point = layout.point(azimuth: panel.azimuth, elevation: panel.normalElevation)
                let incidence = SolarGeometry.incidenceAngle(sunElevation: sun.elevation,
                                                             sunAzimuth: sun.azimuth,
                                                             tilt: panel.array.tilt,
                                                             azimuth: panel.array.azimuth)
                PanelNormalMarker(color: ArrayPalette.color(index),
                                  aligned: sun.elevation > 0 && incidence < 25,
                                  incidence: sun.elevation > 0 ? incidence : nil)
                    .position(point)
            }
        }
    }
}

// MARK: - Ciel

/// Dégradé de ciel + étoiles, pilotés par la hauteur du soleil : nuit,
/// crépuscule astronomique, aube, heure dorée, plein jour.
private struct SkyBackground: View {
    var elevation: Double

    var body: some View {
        let palette = SkyPalette.interpolated(elevation: elevation)
        ZStack {
            LinearGradient(colors: palette.colors, startPoint: .top, endPoint: .bottom)
            StarField()
                .opacity(max(0, min(1, (2 - elevation) / 10)))
        }
        .animation(.easeInOut(duration: 1.5), value: (elevation * 2).rounded())
    }
}

/// Paliers de couleur du ciel selon l'élévation du soleil, interpolés entre eux.
enum SkyPalette {
    struct Palette {
        var colors: [Color]
    }

    private static let stops: [(elevation: Double, rgb: [(Double, Double, Double)])] = [
        (-18, [(0.02, 0.03, 0.10), (0.03, 0.05, 0.16), (0.05, 0.07, 0.22)]),   // nuit
        (-6,  [(0.05, 0.07, 0.22), (0.13, 0.11, 0.33), (0.28, 0.18, 0.36)]),   // crépuscule
        (0,   [(0.11, 0.18, 0.42), (0.42, 0.28, 0.44), (0.86, 0.46, 0.30)]),   // horizon
        (8,   [(0.13, 0.34, 0.66), (0.35, 0.55, 0.79), (0.90, 0.71, 0.44)]),   // heure dorée
        (30,  [(0.09, 0.35, 0.72), (0.29, 0.58, 0.86), (0.66, 0.83, 0.95)]),   // matinée
        (65,  [(0.05, 0.31, 0.72), (0.20, 0.55, 0.90), (0.74, 0.90, 0.99)]),   // plein jour
    ]

    static func interpolated(elevation: Double) -> Palette {
        guard let last = stops.last else { return Palette(colors: [.black]) }
        if elevation <= stops[0].elevation { return Palette(colors: colors(stops[0].rgb)) }
        if elevation >= last.elevation { return Palette(colors: colors(last.rgb)) }
        for index in 1..<stops.count where elevation < stops[index].elevation {
            let low = stops[index - 1]
            let high = stops[index]
            let ratio = (elevation - low.elevation) / (high.elevation - low.elevation)
            let mixed = zip(low.rgb, high.rgb).map { lowRGB, highRGB in
                (lowRGB.0 + (highRGB.0 - lowRGB.0) * ratio,
                 lowRGB.1 + (highRGB.1 - lowRGB.1) * ratio,
                 lowRGB.2 + (highRGB.2 - lowRGB.2) * ratio)
            }
            return Palette(colors: colors(mixed))
        }
        return Palette(colors: colors(last.rgb))
    }

    private static func colors(_ rgb: [(Double, Double, Double)]) -> [Color] {
        rgb.map { Color(red: $0.0, green: $0.1, blue: $0.2) }
    }
}

/// Champ d'étoiles déterministe (mêmes positions d'un lancement à l'autre),
/// avec deux vagues de scintillement décalées.
private struct StarField: View {
    private static let stars: [(x: Double, y: Double, size: Double)] = {
        var seed: UInt64 = 0x5EED_50_1A
        func random() -> Double {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            return Double((seed >> 11) % 100_000) / 100_000
        }
        return (0..<70).map { _ in (random(), random() * 0.78, 0.8 + random() * 1.6) }
    }()

    @State private var twinkle = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(Array(Self.stars.enumerated()), id: \.offset) { index, star in
                    Circle()
                        .fill(.white)
                        .frame(width: star.size, height: star.size)
                        .position(x: star.x * geo.size.width, y: star.y * geo.size.height)
                        .opacity(index.isMultiple(of: 2)
                                 ? (twinkle ? 0.85 : 0.35)
                                 : (twinkle ? 0.30 : 0.80))
                }
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 3.2).repeatForever(autoreverses: true)) {
                twinkle = true
            }
        }
    }
}

// MARK: - Soleil animé

/// Soleil : cœur net, halo pulsé, couronne de rayons en rotation lente.
struct AnimatedSun: View {
    var dimmed = false

    @State private var pulse = false
    @State private var spin = false

    var body: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [Color.yellow.opacity(0.55), .clear],
                                     center: .center, startRadius: 2, endRadius: 30))
                .frame(width: 64, height: 64)
                .blur(radius: 6)
                .scaleEffect(pulse ? 1.12 : 0.92)

            rays
                .rotationEffect(.degrees(spin ? 360 : 0))
                .opacity(dimmed ? 0.3 : 0.75)

            Circle()
                .fill(RadialGradient(colors: [.white, Color(red: 1, green: 0.87, blue: 0.42)],
                                     center: .init(x: 0.38, y: 0.34), startRadius: 0, endRadius: 11))
                .frame(width: 17, height: 17)
                .shadow(color: .yellow.opacity(0.9), radius: pulse ? 9 : 5)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.8).repeatForever(autoreverses: true)) { pulse = true }
            withAnimation(.linear(duration: 90).repeatForever(autoreverses: false)) { spin = true }
        }
    }

    private var rays: some View {
        ZStack {
            ForEach(0..<12, id: \.self) { index in
                Capsule()
                    .fill(LinearGradient(colors: [.yellow.opacity(0.9), .yellow.opacity(0)],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(width: 1.6, height: index.isMultiple(of: 2) ? 14 : 9)
                    .offset(y: index.isMultiple(of: 2) ? -18 : -15)
                    .rotationEffect(.degrees(Double(index) * 30))
            }
        }
        .frame(width: 44, height: 44)
    }
}

// MARK: - Marqueur d'orientation

/// Normale d'un champ de panneaux projetée dans le ciel : le losange figure le
/// panneau vu de face, au centre de ses contours d'iso-incidence. Quand le
/// soleil entre dans le contour intérieur, le champ est à son maximum.
private struct PanelNormalMarker: View {
    var color: Color
    var aligned: Bool
    var incidence: Double?

    @State private var halo = false

    var body: some View {
        ZStack {
            if aligned {
                Circle()
                    .fill(color.opacity(0.30))
                    .frame(width: 30, height: 30)
                    .blur(radius: 6)
                    .scaleEffect(halo ? 1.35 : 0.9)
            }
            PanelGlyph(color: color)
                .frame(width: 17, height: 13)
                .shadow(color: aligned ? color.opacity(0.9) : .clear, radius: 5)
            if let incidence {
                Text(verbatim: "\(Int(incidence.rounded()))°")
                    .font(.system(size: 9, weight: .medium, design: .rounded).monospacedDigit())
                    .foregroundStyle(.white.opacity(aligned ? 0.95 : 0.6))
                    .offset(y: 15)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) { halo = true }
        }
    }
}

/// Petit panneau photovoltaïque en losange, avec ses cellules.
struct PanelGlyph: View {
    var color: Color

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let skew = w * 0.22
            let shape = Path { path in
                path.move(to: CGPoint(x: skew, y: 0))
                path.addLine(to: CGPoint(x: w, y: 0))
                path.addLine(to: CGPoint(x: w - skew, y: h))
                path.addLine(to: CGPoint(x: 0, y: h))
                path.closeSubpath()
            }
            ZStack {
                shape.fill(LinearGradient(colors: [color.opacity(0.95), color.opacity(0.55)],
                                          startPoint: .topLeading, endPoint: .bottomTrailing))
                shape.stroke(.white.opacity(0.8), lineWidth: 0.8)
                Path { path in
                    for fraction in [0.33, 0.66] {
                        path.move(to: CGPoint(x: skew + w * fraction * 0.78, y: 0))
                        path.addLine(to: CGPoint(x: w * fraction * 0.78, y: h))
                    }
                    path.move(to: CGPoint(x: skew / 2, y: h / 2))
                    path.addLine(to: CGPoint(x: w - skew / 2, y: h / 2))
                }
                .stroke(.white.opacity(0.45), lineWidth: 0.5)
            }
        }
    }
}

// MARK: - Palette des champs

/// Couleur stable par champ de panneaux, partagée entre le dôme, le compas et
/// les listes de la fenêtre Soleil.
enum ArrayPalette {
    static let colors: [Color] = [.orange, .teal, .purple, .pink, .green, .blue]

    static func color(_ index: Int) -> Color { colors[index % colors.count] }
}

// MARK: - Projection

/// Mise en page du dôme : domaine d'azimut (rendu continu même quand le soleil
/// passe au nord), plafond d'élévation, échantillonneur de course.
struct SkyLayout {
    struct Solstice {
        var label: String
        var points: [SunCalc.Position]
    }

    struct Panel {
        var array: PanelArray
        var azimuth: Double         // azimut ramené dans le domaine tracé
        var normalElevation: Double // 90 − inclinaison
    }

    var plot: CGRect
    var baseline: CGFloat
    var azMin: Double
    var azMax: Double
    var elMax: Double
    var today: [SunCalc.Position]
    var solstices: [Solstice]
    var panels: [Panel]
    var cardinals: [(azimuth: Double, label: String)]
    var sampler: TrackSampler?

    init(size: CGSize, todayTrack: [SunCalc.Position],
         solsticeTracks: [SkyDomeView.SolsticeTrack], arrays: [PanelArray]) {
        let inset: CGFloat = 26
        baseline = size.height - 22
        plot = CGRect(x: inset, y: 22, width: max(1, size.width - inset * 2),
                      height: max(1, baseline - 22))

        // Toutes les courses doivent vivre dans le même repère d'azimut : on
        // les rend continues, puis on recale chacune sur celle du jour à 360°
        // près — sinon les arcs des solstices atterrissent hors du cadre.
        today = SkyLayout.normalized(SkyLayout.unwrapped(todayTrack))
        let reference = SkyLayout.daylightCenter(today) ?? 180
        solstices = solsticeTracks.map {
            Solstice(label: $0.label,
                     points: SkyLayout.aligned(SkyLayout.unwrapped($0.track), to: reference))
        }

        let daylight = ([today] + solstices.map(\.points)).flatMap { $0.filter { $0.elevation > 0 } }
        let azimuths = daylight.map(\.azimuth)
        let low = azimuths.min() ?? 60
        let high = azimuths.max() ?? 300
        azMin = low - 14
        azMax = max(low + 60, high + 14)
        elMax = min(92, max(50, (daylight.map(\.elevation).max() ?? 60) + 14))

        let center = (azMin + azMax) / 2
        let elevationCeiling = elMax - 4
        panels = arrays.map { array in
            Panel(array: array,
                  azimuth: SkyLayout.representation(of: array.azimuth, near: center),
                  normalElevation: min(elevationCeiling, 90 - array.tilt))
        }

        let (lowBound, highBound) = (azMin + 6, azMax - 6)
        cardinals = [(0, String(localized: "N")), (45, String(localized: "NE")),
                     (90, String(localized: "E")), (135, String(localized: "SE")),
                     (180, String(localized: "S")), (225, String(localized: "SO")),
                     (270, String(localized: "O")), (315, String(localized: "NO"))]
            .flatMap { base -> [(azimuth: Double, label: String)] in
                [-360.0, 0, 360].map { (azimuth: base.0 + $0, label: base.1) }
            }
            .filter { $0.azimuth >= lowBound && $0.azimuth <= highBound }

        sampler = TrackSampler(today)
    }

    func point(azimuth: Double, elevation: Double) -> CGPoint {
        CGPoint(x: x(azimuth: azimuth), y: y(elevation: elevation))
    }

    func x(azimuth: Double) -> CGFloat {
        let ratio = (azimuth - azMin) / max(1, azMax - azMin)
        return plot.minX + CGFloat(min(1, max(0, ratio))) * plot.width
    }

    func y(elevation: Double) -> CGFloat {
        let ratio = min(1, max(0, elevation / elMax))
        return baseline - CGFloat(ratio) * plot.height
    }

    /// L'azimut du soleil peut franchir le nord (hémisphère sud) : on rend la
    /// suite continue pour qu'un axe linéaire reste lisible.
    private static func unwrapped(_ track: [SunCalc.Position]) -> [SunCalc.Position] {
        var result: [SunCalc.Position] = []
        result.reserveCapacity(track.count)
        var offset = 0.0
        var previous: Double?
        for position in track {
            if let previous {
                let delta = position.azimuth + offset - previous
                if delta > 180 { offset -= 360 } else if delta < -180 { offset += 360 }
            }
            var shifted = position
            shifted.azimuth = position.azimuth + offset
            previous = shifted.azimuth
            result.append(shifted)
        }
        return result
    }

    /// Représentation d'un azimut (± 360°) la plus proche du centre du domaine.
    static func representation(of azimuth: Double, near center: Double) -> Double {
        [azimuth - 360, azimuth, azimuth + 360]
            .min { abs($0 - center) < abs($1 - center) } ?? azimuth
    }

    /// Azimut d'un point du ciel ramené dans le domaine tracé.
    func azimuthInDomain(_ azimuth: Double) -> Double {
        SkyLayout.representation(of: azimuth, near: (azMin + azMax) / 2)
    }

    /// Milieu du parcours diurne, repère de recalage entre deux courses.
    private static func daylightCenter(_ track: [SunCalc.Position]) -> Double? {
        let azimuths = track.filter { $0.elevation > 0 }.map(\.azimuth)
        guard azimuths.isEmpty == false else { return nil }
        return (azimuths.min()! + azimuths.max()!) / 2
    }

    /// Course ramenée dans le tour de cadran habituel (milieu du jour vers 180°).
    private static func normalized(_ track: [SunCalc.Position]) -> [SunCalc.Position] {
        guard let center = daylightCenter(track) else { return track }
        return shifted(track, by: -360 * ((center - 180) / 360).rounded())
    }

    /// Course recalée sur un repère donné, à 360° près.
    private static func aligned(_ track: [SunCalc.Position], to reference: Double) -> [SunCalc.Position] {
        guard let center = daylightCenter(track) else { return track }
        return shifted(track, by: -360 * ((center - reference) / 360).rounded())
    }

    private static func shifted(_ track: [SunCalc.Position], by offset: Double) -> [SunCalc.Position] {
        guard offset != 0 else { return track }
        return track.map { position in
            var shifted = position
            shifted.azimuth += offset
            return shifted
        }
    }
}

/// Découpage d'une course en « déjà parcourue » / « reste du jour ».
enum SunTrack {
    static func split(_ track: [SunCalc.Position],
                      at date: Date) -> (traveled: [SunCalc.Position], remaining: [SunCalc.Position]) {
        guard let index = track.lastIndex(where: { $0.date <= date }) else { return ([], track) }
        // L'échantillon charnière appartient aux deux tronçons : pas de trou.
        return (Array(track[...index]), Array(track[index...]))
    }
}

/// Interpolation linéaire de la course du soleil : donne l'azimut et
/// l'élévation à un instant quelconque de la journée.
struct TrackSampler {
    private let positions: [SunCalc.Position]

    init?(_ positions: [SunCalc.Position]) {
        guard positions.count > 1 else { return nil }
        self.positions = positions
    }

    func sample(at date: Date) -> (azimuth: Double, elevation: Double)? {
        guard let first = positions.first, let last = positions.last,
              date >= first.date, date <= last.date else { return nil }
        let step = positions[1].date.timeIntervalSince(first.date)
        let offset = date.timeIntervalSince(first.date) / step
        let index = min(positions.count - 2, max(0, Int(offset)))
        let ratio = min(1, max(0, offset - Double(index)))
        let low = positions[index]
        let high = positions[index + 1]
        return (low.azimuth + (high.azimuth - low.azimuth) * ratio,
                low.elevation + (high.elevation - low.elevation) * ratio)
    }
}

/// Libellé cardinal d'un azimut (0 = nord), pour les réglages et les listes.
enum Cardinal {
    static func label(azimuth: Double) -> String {
        let names = [String(localized: "Nord"), String(localized: "Nord-Est"),
                     String(localized: "Est"), String(localized: "Sud-Est"),
                     String(localized: "Sud"), String(localized: "Sud-Ouest"),
                     String(localized: "Ouest"), String(localized: "Nord-Ouest")]
        var normalized = azimuth.truncatingRemainder(dividingBy: 360)
        if normalized < 0 { normalized += 360 }
        let index = Int((normalized / 45).rounded()) % names.count
        return names[index]
    }
}
