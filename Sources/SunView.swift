import SwiftUI

/// Fenêtre « Soleil » : dôme céleste animé en héros — course réelle du jour,
/// arcs des solstices, production mesurée et orientation de chaque champ de
/// panneaux — puis compas solaire, détail par orientation, éphémérides,
/// lumière, productible et météo. Séparée du tableau de bord, qui reste un
/// tableau de bord.
struct SunView: View {
    var body: some View {
        ScrollView {
            SunContent()
        }
        .frame(minWidth: 820, idealWidth: 900, maxWidth: .infinity,
               minHeight: 560, idealHeight: 780, maxHeight: .infinity)
        .navigationTitle(Text("Zendure Monitor — Soleil"))
        .onAppear { WindowPolicy.retain() }
        .onDisappear { WindowPolicy.release() }
    }
}

/// Contenu de la fenêtre Soleil, séparé de la scène pour rester rendable
/// par ImageRenderer (captures d'écran de la doc). Les animations sont
/// déclaratives : la vue au repos est déjà complète.
struct SunContent: View {
    @EnvironmentObject var monitor: Monitor
    @StateObject private var weatherService = WeatherService()
    @AppStorage("sunLatitude") private var latitude: Double = 0
    @AppStorage("sunLongitude") private var longitude: Double = 0
    @AppStorage("sunPeakWatts") private var legacyPeakWatts: Double = 0
    @AppStorage(PanelArrayStore.key) private var arraysJSON: String = ""

    private var configured: Bool { latitude != 0 || longitude != 0 }

    /// Champs de panneaux configurés, avec la même migration douce que
    /// `PanelArrayStore` — l'ancienne puissance crête seule reste exploitée.
    private var arrays: [PanelArray] {
        let stored = PanelArrayStore.decode(arraysJSON)
        if stored.isEmpty == false { return stored }
        return legacyPeakWatts > 0 ? [PanelArray(peakWatts: legacyPeakWatts, azimuth: 180, tilt: 30)] : []
    }

    private var installedPeak: Double { arrays.reduce(0) { $0 + $1.peakWatts } }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { timeline in
            let now = timeline.date
            let sun = SunCalc.compute(at: now, latitude: latitude, longitude: longitude)
            VStack(spacing: 14) {
                if configured {
                    let track = SunCalc.track(on: now, latitude: latitude, longitude: longitude)
                    let twilight = SunCalc.twilight(on: now, latitude: latitude, longitude: longitude)
                    heroCard(sun, track: track, now: now)
                    HStack(alignment: .top, spacing: 14) {
                        compassCard(sun, track: track, now: now)
                        orientationsCard(sun, track: track)
                    }
                    HStack(alignment: .top, spacing: 14) {
                        ephemeridesCard(sun, now: now)
                        lightCard(sun, twilight: twilight)
                    }
                    HStack(alignment: .top, spacing: 14) {
                        yieldCard(sun, track: track)
                        weatherCard(sun)
                    }
                } else {
                    SunCard()
                }
            }
            .padding(16)
            .onAppear { weatherService.refresh(latitude: latitude, longitude: longitude) }
            .onChange(of: timeline.date) {
                weatherService.refresh(latitude: latitude, longitude: longitude)
            }
        }
    }

    // MARK: - Héros : dôme céleste

    private func heroCard(_ sun: SunCalc.Ephemeris, track: [SunCalc.Position], now: Date) -> some View {
        MetricCard(title: "Le soleil et vos orientations", systemImage: "sun.max.fill") {
            VStack(alignment: .leading, spacing: 10) {
                statStrip(sun, now: now)
                SkyDomeView(sun: sun,
                            todayTrack: track,
                            solsticeTracks: solsticeTracks(now: now),
                            arrays: arrays,
                            curve: monitor.todayCurve,
                            peakW: max(monitor.peakTodayW, installedPeak),
                            now: now)
                    .frame(height: 252)
                Text("Hauteur = élévation, largeur = azimut. Trait plein : la course du jour, heure par heure. Pointillés : les solstices, bornes de l'année. Zone jaune : production mesurée, posée là où était le soleil à cet instant. Losanges : la direction que vise chaque champ de panneaux, avec l'écart d'incidence actuel — quand le soleil l'atteint, ce champ est à son maximum.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func statStrip(_ sun: SunCalc.Ephemeris, now: Date) -> some View {
        let clearSky = SolarGeometry.clearSkyWatts(for: arrays,
                                                   sunElevation: sun.elevation,
                                                   sunAzimuth: sun.azimuth)
        let measured = monitor.state?.solarInputPower
        return HStack(spacing: 10) {
            SunStatTile(symbol: "arrow.up.right", tint: .yellow, label: "Élévation",
                        value: String(format: "%.1f°", sun.elevation),
                        detail: String(format: String(localized: "max %.0f°"), sun.maxElevation))
            SunStatTile(symbol: "location.north.line.fill", tint: .mint, label: "Azimut",
                        value: String(format: "%.0f°", sun.azimuth),
                        detail: Cardinal.label(azimuth: sun.azimuth))
            SunStatTile(symbol: "bolt.fill", tint: .green, label: "Production",
                        value: measured.map(Format.watts) ?? "—",
                        detail: measured != nil && clearSky > 10
                            ? String(format: String(localized: "%d %% du ciel clair"),
                                     Int(((measured ?? 0) / clearSky * 100).rounded()))
                            : nil)
            SunStatTile(symbol: "gauge.with.needle", tint: .orange, label: "Ciel clair",
                        value: arrays.isEmpty ? "—" : Format.watts(clearSky),
                        detail: arrays.isEmpty ? nil : Format.watts(installedPeak) + " " + String(localized: "crête"))
            SunStatTile(symbol: sun.elevation > 0 ? "sunset.fill" : "sunrise.fill",
                        tint: .indigo,
                        label: sun.elevation > 0 ? "Coucher dans" : "Lever dans",
                        value: countdown(sun, now: now),
                        detail: time(sun.elevation > 0 ? sun.sunset : sun.sunrise))
        }
    }

    // MARK: - Compas solaire

    private func compassCard(_ sun: SunCalc.Ephemeris, track: [SunCalc.Position], now: Date) -> some View {
        MetricCard(title: "Compas solaire", systemImage: "location.circle") {
            VStack(spacing: 8) {
                SunCompassView(sun: sun, todayTrack: track,
                               solsticeTracks: solsticeTracks(now: now),
                               arrays: arrays, now: now)
                    .frame(width: 250, height: 250)
                Text("Vu du dessus : centre = zénith, cercle = horizon. Les boucles marquent 25° et 50° d'écart d'incidence autour de chaque champ.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
        }
        .frame(width: 300)
    }

    // MARK: - Détail par orientation

    @ViewBuilder
    private func orientationsCard(_ sun: SunCalc.Ephemeris, track: [SunCalc.Position]) -> some View {
        MetricCard(title: "Champs de panneaux", systemImage: "square.stack.3d.up") {
            if arrays.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Décrivez vos champs de panneaux dans Réglages → Soleil (puissance crête, azimut, inclinaison) pour voir l'incidence du soleil sur chacun, son productible et sa meilleure heure.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Azimut : 90° = est, 180° = plein sud, 270° = ouest. Inclinaison : 0° à plat, 30° pour une toiture courante.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                let clearSkyTotal = SolarGeometry.clearSkyWatts(for: arrays,
                                                                sunElevation: sun.elevation,
                                                                sunAzimuth: sun.azimuth)
                VStack(spacing: 10) {
                    ForEach(Array(arrays.enumerated()), id: \.element.id) { index, array in
                        if index > 0 { Divider() }
                        PanelArrayRow(array: array, index: index, sun: sun,
                                      best: SolarGeometry.bestMoment(for: array, track: track),
                                      dailyWh: SolarGeometry.clearSkyEnergyWh(for: [array], track: track))
                    }
                    Divider()
                    VStack(spacing: 5) {
                        LegendRow(color: .orange, label: "Total ciel clair maintenant",
                                  value: Format.watts(clearSkyTotal))
                        if let measured = monitor.state?.solarInputPower {
                            LegendRow(color: .green, label: "Production mesurée", value: Format.watts(measured))
                        }
                        LegendRow(color: .gray, label: "Puissance crête installée",
                                  value: Format.watts(installedPeak))
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Éphémérides

    private func ephemeridesCard(_ sun: SunCalc.Ephemeris, now: Date) -> some View {
        let yesterday = SunCalc.compute(at: now.addingTimeInterval(-86400),
                                        latitude: latitude, longitude: longitude)
        return MetricCard(title: "Éphémérides", systemImage: "sun.horizon.fill") {
            VStack(spacing: 5) {
                LegendRow(color: .orange, label: "Lever", value: time(sun.sunrise))
                LegendRow(color: .yellow, label: "Midi solaire",
                          value: time(sun.solarNoon) + " · " + relative(to: sun.solarNoon, from: now))
                LegendRow(color: .indigo, label: "Coucher", value: time(sun.sunset))
                LegendRow(color: .teal, label: "Durée du jour",
                          value: Format.duration(minutes: sun.daylight / 60))
                LegendRow(color: .mint, label: "Depuis hier",
                          value: signedSeconds(sun.daylight - yesterday.daylight))
                LegendRow(color: .gray, label: "Élévation actuelle",
                          value: String(format: "%.1f° (max %.1f°)", sun.elevation, sun.maxElevation))
                if let event = SunCalc.nextSolarEvent(after: now) {
                    LegendRow(color: .purple, label: label(for: event.kind),
                              value: event.date.formatted(date: .abbreviated, time: .omitted)
                                  + " · " + relative(to: event.date, from: now))
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Lumière

    private func lightCard(_ sun: SunCalc.Ephemeris, twilight: SunCalc.Twilight) -> some View {
        MetricCard(title: "Lumière et crépuscules", systemImage: "sparkles") {
            VStack(alignment: .leading, spacing: 8) {
                VStack(spacing: 5) {
                    LegendRow(color: .indigo.opacity(0.6), label: "Aube astronomique",
                              value: time(twilight.astronomicalDawn))
                    LegendRow(color: .blue.opacity(0.7), label: "Aube nautique",
                              value: time(twilight.nauticalDawn))
                    LegendRow(color: .cyan, label: "Aube civile", value: time(twilight.civilDawn))
                    LegendRow(color: .yellow, label: "Heure dorée du matin",
                              value: range(sun.sunrise, twilight.goldenHourMorningEnd))
                    LegendRow(color: .orange, label: "Heure dorée du soir",
                              value: range(twilight.goldenHourEveningStart, sun.sunset))
                    LegendRow(color: .cyan.opacity(0.8), label: "Crépuscule civil",
                              value: time(twilight.civilDusk))
                    LegendRow(color: .blue.opacity(0.7), label: "Crépuscule nautique",
                              value: time(twilight.nauticalDusk))
                    LegendRow(color: .indigo.opacity(0.6), label: "Crépuscule astronomique",
                              value: time(twilight.astronomicalDusk))
                }
                Text("Heure dorée : soleil sous 6° d'élévation. Aube civile −6°, nautique −12°, astronomique −18°.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Productible théorique

    @ViewBuilder
    private func yieldCard(_ sun: SunCalc.Ephemeris, track: [SunCalc.Position]) -> some View {
        MetricCard(title: "Productible théorique", systemImage: "gauge.with.needle") {
            if arrays.isEmpty {
                Text("Renseignez au moins un champ de panneaux dans Réglages → Soleil pour estimer le productible et le rendement.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                let clearSky = SolarGeometry.clearSkyWatts(for: arrays,
                                                           sunElevation: sun.elevation,
                                                           sunAzimuth: sun.azimuth)
                let dailyWh = SolarGeometry.clearSkyEnergyWh(for: arrays, track: track)
                VStack(alignment: .leading, spacing: 8) {
                    VStack(spacing: 5) {
                        LegendRow(color: .yellow, label: "Ciel clair maintenant", value: Format.watts(clearSky))
                        if let measured = monitor.state?.solarInputPower {
                            LegendRow(color: .green, label: "Production mesurée", value: Format.watts(measured))
                            if clearSky > 10 {
                                LegendRow(color: .teal, label: "Rendement estimé",
                                          value: "\(Int((measured / clearSky * 100).rounded())) %")
                            }
                        }
                        LegendRow(color: .orange, label: "Énergie ciel clair du jour",
                                  value: Format.kilowattHours(dailyWh))
                        LegendRow(color: .green, label: "Énergie mesurée du jour",
                                  value: Format.kilowattHours(monitor.energyTodayWh))
                        if dailyWh > 100 {
                            LegendRow(color: .teal, label: "Part du potentiel du jour",
                                      value: "\(Int((monitor.energyTodayWh / dailyWh * 100).rounded())) %")
                        }
                        if let airMass = SolarGeometry.airMass(sunElevation: sun.elevation) {
                            LegendRow(color: .gray, label: "Masse d'air",
                                      value: String(format: "%.2f", airMass))
                        }
                        if let shadow = SolarGeometry.shadowRatio(sunElevation: sun.elevation) {
                            LegendRow(color: .gray, label: "Longueur d'ombre",
                                      value: String(format: String(localized: "%.1f × la hauteur"), shadow))
                        }
                    }
                    Text("Modèle ciel clair : 85 % de direct, pondéré par l'incidence sur chaque champ et par la traversée d'atmosphère, 15 % de diffus selon la part de ciel vue, moins 10 % de pertes onduleur et câblage. Sans météo ni ombrage.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Météo locale (Open-Meteo)

    @ViewBuilder
    private func weatherCard(_ sun: SunCalc.Ephemeris) -> some View {
        MetricCard(title: "Météo locale", systemImage: "cloud.sun.fill") {
            if let weather = weatherService.weather {
                VStack(alignment: .leading, spacing: 8) {
                    let wmo = WMOCode.describe(weather.weatherCode)
                    HStack(spacing: 8) {
                        Image(systemName: wmo.symbol)
                            .font(.title3)
                            .foregroundStyle(.yellow, .secondary)
                        Text(wmo.label)
                        Spacer()
                        Text("\(Int(weather.temperature.rounded())) °C")
                            .font(.title3.monospacedDigit())
                    }
                    VStack(spacing: 5) {
                        LegendRow(color: .gray, label: "Couverture nuageuse",
                                  value: "\(Int(weather.cloudCover)) %")
                        LegendRow(color: .teal, label: "Facteur nuages",
                                  value: "× \(String(format: "%.2f", EnergyMath.cloudFactor(coverPercent: weather.cloudCover)))")
                        if let sunshine = weather.sunshineForecastSec {
                            LegendRow(color: .yellow, label: "Ensoleillement prévu",
                                      value: Format.duration(minutes: sunshine / 60))
                        }
                        if arrays.isEmpty == false, sun.elevation > 0 {
                            let clearSky = SolarGeometry.clearSkyWatts(for: arrays,
                                                                       sunElevation: sun.elevation,
                                                                       sunAzimuth: sun.azimuth)
                            LegendRow(color: .orange, label: "Productible ajusté nuages",
                                      value: Format.watts(clearSky * EnergyMath.cloudFactor(coverPercent: weather.cloudCover)))
                        }
                    }
                    Text("Source : Open-Meteo, rafraîchie toutes les 30 min. Atténuation nuageuse de Kasten–Czeplak.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else if let error = weatherService.lastError {
                Text("Météo indisponible : \(error)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Chargement de la météo…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Helpers

    /// Courses des deux solstices, repères fixes de l'année en cours.
    private func solsticeTracks(now: Date) -> [SkyDomeView.SolsticeTrack] {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: now)
        return [(6, 21), (12, 21)].compactMap { month, day in
            guard let date = calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12)) else {
                return nil
            }
            return SkyDomeView.SolsticeTrack(
                label: date.formatted(.dateTime.day().month(.abbreviated)),
                track: SunCalc.track(on: date, latitude: latitude, longitude: longitude, stepMinutes: 12))
        }
    }

    private func time(_ date: Date?) -> String {
        date?.formatted(date: .omitted, time: .shortened) ?? "—"
    }

    private func range(_ start: Date?, _ end: Date?) -> String {
        guard let start, let end else { return "—" }
        return time(start) + " – " + time(end)
    }

    /// « dans 1 h 12 », « il y a 24 min », « dans 46 j » — au-delà de deux
    /// jours, un compte en heures ne dit plus rien.
    private func relative(to date: Date, from now: Date) -> String {
        let interval = date.timeIntervalSince(now)
        let magnitude = abs(interval)
        let quantity = magnitude >= 172_800
            ? String(format: String(localized: "%d j"), Int((magnitude / 86400).rounded()))
            : Format.duration(minutes: magnitude / 60)
        return interval >= 0 ? String(localized: "dans \(quantity)")
                             : String(localized: "il y a \(quantity)")
    }

    /// Écart de durée du jour, à la seconde — c'est là qu'on voit tourner l'année.
    private func signedSeconds(_ seconds: TimeInterval) -> String {
        let rounded = Int(seconds.rounded())
        let sign = rounded >= 0 ? "+" : "−"
        let absolute = abs(rounded)
        if absolute >= 60 {
            return "\(sign)\(absolute / 60) min \(String(format: "%02d", absolute % 60)) s"
        }
        return "\(sign)\(absolute) s"
    }

    private func countdown(_ sun: SunCalc.Ephemeris, now: Date) -> String {
        let target = sun.elevation > 0 ? sun.sunset : sun.sunrise
        guard let target else { return "—" }
        let minutes = target.timeIntervalSince(now) / 60
        guard minutes > 0 else { return "—" }
        return Format.duration(minutes: minutes)
    }

    private func label(for kind: SunCalc.SolarEventKind) -> LocalizedStringKey {
        switch kind {
        case .springEquinox: return "Équinoxe de printemps"
        case .summerSolstice: return "Solstice d'été"
        case .autumnEquinox: return "Équinoxe d'automne"
        case .winterSolstice: return "Solstice d'hiver"
        }
    }
}

// MARK: - Tuile d'indicateur

/// Tuile compacte du bandeau du héros.
private struct SunStatTile: View {
    var symbol: String
    var tint: Color
    var label: LocalizedStringKey
    var value: String
    var detail: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: symbol)
                    .font(.caption2)
                    .foregroundStyle(tint)
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Text(value)
                .font(.system(.title3, design: .rounded).weight(.medium))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(detail ?? " ")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background(tint.opacity(0.09), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
    }
}

// MARK: - Ligne de champ de panneaux

/// Un champ : orientation, incidence courante, productible ciel clair, part de
/// l'irradiance crête captée, meilleure heure et énergie potentielle du jour.
private struct PanelArrayRow: View {
    var array: PanelArray
    var index: Int
    var sun: SunCalc.Ephemeris
    var best: (date: Date, watts: Double)?
    var dailyWh: Double

    private var color: Color { ArrayPalette.color(index) }

    private var factor: Double {
        SolarGeometry.planeOfArrayFactor(for: array,
                                         sunElevation: sun.elevation,
                                         sunAzimuth: sun.azimuth)
    }

    private var incidence: Double {
        SolarGeometry.incidenceAngle(sunElevation: sun.elevation, sunAzimuth: sun.azimuth,
                                     tilt: array.tilt, azimuth: array.azimuth)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                PanelGlyph(color: color)
                    .frame(width: 18, height: 14)
                VStack(alignment: .leading, spacing: 1) {
                    Text(array.name.isEmpty ? String(localized: "Champ \(index + 1)") : array.name)
                        .font(.callout.weight(.medium))
                        .lineLimit(1)
                    Text(verbatim: "\(Cardinal.label(azimuth: array.azimuth)) · \(Int(array.azimuth.rounded()))° · \(Int(array.tilt.rounded()))° "
                         + String(localized: "d'inclinaison") + " · \(Format.watts(array.peakWatts))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 1) {
                    Text(Format.watts(SolarGeometry.clearSkyWatts(for: array,
                                                                  sunElevation: sun.elevation,
                                                                  sunAzimuth: sun.azimuth)))
                        .font(.callout.monospacedDigit())
                    Text(sun.elevation > 0
                         ? String(localized: "incidence \(Int(incidence.rounded()))°")
                         : String(localized: "sous l'horizon"))
                        .font(.caption2)
                        .foregroundStyle(sun.elevation > 0 && incidence < 25 ? color : .secondary)
                }
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.primary.opacity(0.07))
                    Capsule()
                        .fill(LinearGradient(colors: [color.opacity(0.55), color],
                                             startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * CGFloat(min(1, max(0, factor))))
                }
                .animation(.easeInOut(duration: 0.6), value: factor)
            }
            .frame(height: 5)
            HStack(spacing: 8) {
                if let best {
                    Text(verbatim: String(localized: "meilleure heure") + " " + best.date.formatted(date: .omitted, time: .shortened)
                         + " · " + Format.watts(best.watts))
                }
                Spacer()
                if dailyWh > 1 {
                    Text(verbatim: String(localized: "potentiel du jour") + " " + Format.kilowattHours(dailyWh))
                }
            }
            .font(.caption2.monospacedDigit())
            .foregroundStyle(.secondary)
        }
    }
}
