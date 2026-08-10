import SwiftUI

/// Panneau latéral de la fenêtre SunRoad — hérite des cartes de l'ancienne
/// fenêtre Soleil (fusion Phase E) : la scène 3D remplace le dôme céleste et
/// le compas solaire, tout le reste vit ici en cartes repliables. Les sliders
/// d'orientation écrivent `sunArrays` : les panneaux pivotent dans la scène
/// pendant le geste.
struct SunRoadSidebar: View {
    @EnvironmentObject private var monitor: Monitor
    @ObservedObject var weather: WeatherService
    var latitude: Double
    var longitude: Double
    var date: Date

    @AppStorage("sunPeakWatts") private var legacyPeakWatts: Double = 0
    @AppStorage(PanelArrayStore.key) private var arraysJSON: String = ""

    private var arrays: [PanelArray] { PanelArrayStore.decode(arraysJSON) }
    private var installedPeak: Double { arrays.reduce(0) { $0 + $1.peakWatts } }

    var body: some View {
        let sun = SunCalc.compute(at: date, latitude: latitude, longitude: longitude)
        let track = SunCalc.track(on: date, latitude: latitude, longitude: longitude)
        let twilight = SunCalc.twilight(on: date, latitude: latitude, longitude: longitude)
        ScrollView {
            VStack(spacing: 10) {
                orientationsCard(sun, track: track)
                productionCard()
                ephemeridesCard(sun)
                lightCard(sun, twilight: twilight)
                yieldCard(sun, track: track)
                weatherCard(sun)
            }
            .padding(10)
        }
        .frame(width: 332)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear { materializeLegacyArray() }
    }

    /// L'ancien réglage « puissance crête » seul devient un champ plein sud
    /// 30° tant qu'aucun champ n'a été décrit (comme dans l'ancienne fenêtre).
    private func materializeLegacyArray() {
        guard PanelArrayStore.decode(arraysJSON).isEmpty, legacyPeakWatts > 0 else { return }
        arraysJSON = PanelArrayStore.encode([PanelArray(peakWatts: legacyPeakWatts,
                                                        azimuth: 180, tilt: 30)])
    }

    private func binding(for id: UUID) -> Binding<PanelArray> {
        Binding(
            get: { arrays.first { $0.id == id } ?? PanelArray(peakWatts: 0) },
            set: { updated in
                var list = arrays
                guard let index = list.firstIndex(where: { $0.id == id }) else { return }
                list[index] = updated
                arraysJSON = PanelArrayStore.encode(list)
            }
        )
    }

    // MARK: - Champs de panneaux (sliders branchés sur la 3D)

    private func orientationsCard(_ sun: SunCalc.Ephemeris, track: [SunCalc.Position]) -> some View {
        MetricCard(title: "Champs de panneaux", systemImage: "square.stack.3d.up",
                   collapseKey: "sunroadCollapseArrays",
                   collapsedSummary: Format.watts(SolarGeometry.clearSkyWatts(for: arrays, sunElevation: sun.elevation, sunAzimuth: sun.azimuth))) {
            if arrays.isEmpty {
                Text("Décrivez vos champs de panneaux dans Réglages → Soleil (puissance crête, azimut, inclinaison) : ils apparaîtront dans la scène et ici, avec leurs curseurs d'orientation.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                let clearSkyTotal = SolarGeometry.clearSkyWatts(for: arrays,
                                                                sunElevation: sun.elevation,
                                                                sunAzimuth: sun.azimuth)
                VStack(spacing: 10) {
                    ForEach(Array(arrays.enumerated()), id: \.element.id) { index, array in
                        if index > 0 { Divider() }
                        SunRoadArrayRow(array: binding(for: array.id), index: index, sun: sun,
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
    }

    // MARK: - Production (l'histogramme hérité)

    private func productionCard() -> some View {
        MetricCard(title: "Production", systemImage: "chart.bar.fill",
                   collapseKey: "sunroadCollapseProduction",
                   collapsedSummary: Format.kilowattHours(monitor.energyTodayWh)) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text(Format.kilowattHours(monitor.energyTodayWh))
                        .font(.title3.monospacedDigit().weight(.semibold))
                    Text("aujourd'hui")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    if monitor.peakTodayW > 0 {
                        Text("pic \(Format.watts(monitor.peakTodayW))")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
                DailyBarChart(days: monitor.dailyEnergy, color: .yellow)
                    .frame(height: 64)
                if monitor.historyFromServer {
                    Text("Historique complet via le collecteur 24/7.")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    // MARK: - Éphémérides

    private func ephemeridesCard(_ sun: SunCalc.Ephemeris) -> some View {
        let yesterday = SunCalc.compute(at: date.addingTimeInterval(-86400),
                                        latitude: latitude, longitude: longitude)
        return MetricCard(title: "Éphémérides", systemImage: "sun.horizon.fill",
                          collapseKey: "sunroadCollapseEphemeris",
                          collapsedSummary: time(sun.sunset)) {
            VStack(spacing: 5) {
                LegendRow(color: .orange, label: "Lever", value: time(sun.sunrise))
                LegendRow(color: .yellow, label: "Midi solaire",
                          value: time(sun.solarNoon) + " · " + relative(to: sun.solarNoon, from: date))
                LegendRow(color: .indigo, label: "Coucher", value: time(sun.sunset))
                LegendRow(color: .teal, label: "Durée du jour",
                          value: Format.duration(minutes: sun.daylight / 60))
                LegendRow(color: .mint, label: "Depuis hier",
                          value: signedSeconds(sun.daylight - yesterday.daylight))
                LegendRow(color: .gray, label: "Élévation actuelle",
                          value: String(format: "%.1f° (max %.1f°)", sun.elevation, sun.maxElevation))
                if let event = SunCalc.nextSolarEvent(after: date) {
                    LegendRow(color: .purple, label: label(for: event.kind),
                              value: event.date.formatted(date: .abbreviated, time: .omitted)
                                  + " · " + relative(to: event.date, from: date))
                }
            }
        }
    }

    // MARK: - Lumière et crépuscules

    private func lightCard(_ sun: SunCalc.Ephemeris, twilight: SunCalc.Twilight) -> some View {
        MetricCard(title: "Lumière et crépuscules", systemImage: "sparkles",
                   collapseKey: "sunroadCollapseLight",
                   collapsedSummary: range(sun.sunrise, sun.sunset)) {
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
                Text("Heure dorée : soleil sous 6° d'élévation.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .help(Text("Heure dorée : soleil sous 6° d'élévation. Aube civile −6°, nautique −12°, astronomique −18°."))
            }
        }
    }

    // MARK: - Productible théorique

    @ViewBuilder
    private func yieldCard(_ sun: SunCalc.Ephemeris, track: [SunCalc.Position]) -> some View {
        MetricCard(title: "Productible théorique", systemImage: "gauge.with.needle",
                   collapseKey: "sunroadCollapseYield") {
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
                    Text("Ciel clair : direct pondéré par l'incidence et l'atmosphère, plus le diffus. Sans météo ni ombrage.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .help(Text("Modèle ciel clair : 85 % de direct, pondéré par l'incidence sur chaque champ et par la traversée d'atmosphère, 15 % de diffus selon la part de ciel vue, moins 10 % de pertes onduleur et câblage. Sans météo ni ombrage."))
                }
            }
        }
    }

    // MARK: - Météo locale

    @ViewBuilder
    private func weatherCard(_ sun: SunCalc.Ephemeris) -> some View {
        MetricCard(title: "Météo locale", systemImage: "cloud.sun.fill",
                   collapseKey: "sunroadCollapseWeather",
                   collapsedSummary: weather.weather.map { "\(Int($0.temperature.rounded())) °C" }) {
            if let current = weather.weather {
                VStack(alignment: .leading, spacing: 8) {
                    let wmo = WMOCode.describe(current.weatherCode)
                    HStack(spacing: 8) {
                        Image(systemName: wmo.symbol)
                            .font(.title3)
                            .foregroundStyle(.yellow, .secondary)
                        Text(wmo.label)
                        Spacer()
                        Text("\(Int(current.temperature.rounded())) °C")
                            .font(.title3.monospacedDigit())
                    }
                    VStack(spacing: 5) {
                        LegendRow(color: .gray, label: "Couverture nuageuse",
                                  value: "\(Int(current.cloudCover)) %")
                        LegendRow(color: .teal, label: "Facteur nuages",
                                  value: "× \(String(format: "%.2f", EnergyMath.cloudFactor(coverPercent: current.cloudCover)))")
                        if let sunshine = current.sunshineForecastSec {
                            LegendRow(color: .yellow, label: "Ensoleillement prévu",
                                      value: Format.duration(minutes: sunshine / 60))
                        }
                        if arrays.isEmpty == false, sun.elevation > 0 {
                            let clearSky = SolarGeometry.clearSkyWatts(for: arrays,
                                                                       sunElevation: sun.elevation,
                                                                       sunAzimuth: sun.azimuth)
                            LegendRow(color: .orange, label: "Productible ajusté nuages",
                                      value: Format.watts(clearSky * EnergyMath.cloudFactor(coverPercent: current.cloudCover)))
                        }
                    }
                    Text("Source : Open-Meteo, rafraîchie toutes les 30 min.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .help(Text("Source : Open-Meteo, rafraîchie toutes les 30 min. Atténuation nuageuse de Kasten–Czeplak."))
                }
            } else if let error = weather.lastError {
                Text("Météo indisponible : \(error)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Chargement de la météo…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Helpers (portés de SunView)

    private func time(_ date: Date?) -> String {
        date?.formatted(date: .omitted, time: .shortened) ?? "—"
    }

    private func range(_ start: Date?, _ end: Date?) -> String {
        guard let start, let end else { return "—" }
        return time(start) + " – " + time(end)
    }

    /// « dans 1 h 12 », « il y a 24 min », « dans 46 j » — au-delà de deux
    /// jours, un compte en heures ne dit plus rien.
    private func relative(to target: Date, from now: Date) -> String {
        let interval = target.timeIntervalSince(now)
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

    private func label(for kind: SunCalc.SolarEventKind) -> LocalizedStringKey {
        switch kind {
        case .springEquinox: return "Équinoxe de printemps"
        case .summerSolstice: return "Solstice d'été"
        case .autumnEquinox: return "Équinoxe d'automne"
        case .winterSolstice: return "Solstice d'hiver"
        }
    }
}

// MARK: - Ligne de champ (sliders) — portée de SunView

private struct SunRoadArrayRow: View {
    @Binding var array: PanelArray
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
                    Text(verbatim: Cardinal.label(azimuth: array.azimuth) + " · "
                         + Format.watts(array.peakWatts) + " " + String(localized: "crête"))
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
            // Réglage direct : la scène 3D suit le geste (les panneaux
            // pivotent en direct), le productible aussi.
            HStack(spacing: 12) {
                SunRoadAngleSlider(symbol: "location.north.line.fill", value: $array.azimuth,
                                   range: 0...360, step: 5, tint: color,
                                   hint: "Azimut du champ : 0° = nord, 90° = est, 180° = plein sud, 270° = ouest.")
                SunRoadAngleSlider(symbol: "angle", value: $array.tilt,
                                   range: 0...90, step: 1, tint: color,
                                   hint: "Inclinaison du champ : 0° à plat, 30° pour une toiture courante, 90° en façade.")
            }
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

/// Curseur d'angle compact : un symbole, la piste, la valeur en degrés.
private struct SunRoadAngleSlider: View {
    var symbol: String
    @Binding var value: Double
    var range: ClosedRange<Double>
    var step: Double
    var tint: Color
    var hint: LocalizedStringKey

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(width: 12)
            Slider(value: $value, in: range, step: step)
                .controlSize(.mini)
                .tint(tint)
            Text(verbatim: "\(Int(value.rounded()))°")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 30, alignment: .trailing)
        }
        .help(Text(hint))
    }
}
