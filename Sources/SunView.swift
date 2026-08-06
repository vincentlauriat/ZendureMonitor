import SwiftUI

/// Fenêtre « Soleil » : course du soleil × production en héros, puis
/// éphémérides, productible théorique et météo côte à côte — tout tient
/// sans scroll. Séparée du tableau de bord — qui reste un tableau de bord.
struct SunView: View {
    var body: some View {
        SunContent()
            .frame(minWidth: 760, idealWidth: 820, maxWidth: .infinity,
                   minHeight: 480, idealHeight: 540, maxHeight: .infinity)
            .navigationTitle(Text("Zendure Monitor — Soleil"))
            .onAppear { WindowPolicy.retain() }
            .onDisappear { WindowPolicy.release() }
    }
}

/// Contenu de la fenêtre Soleil, séparé de la scène pour rester rendable
/// par ImageRenderer (captures d'écran de la doc).
struct SunContent: View {
    @EnvironmentObject var monitor: Monitor
    @StateObject private var weatherService = WeatherService()
    @AppStorage("sunLatitude") private var latitude: Double = 0
    @AppStorage("sunLongitude") private var longitude: Double = 0
    @AppStorage("sunPeakWatts") private var peakWatts: Double = 0

    private var configured: Bool { latitude != 0 || longitude != 0 }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { timeline in
            let sun = SunCalc.compute(at: timeline.date, latitude: latitude, longitude: longitude)
            VStack(spacing: 14) {
                if configured {
                    sunProductionCard(sun, now: timeline.date)
                    HStack(alignment: .top, spacing: 14) {
                        ephemeridesCard(sun)
                        theoreticalCard(sun)
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

    // MARK: - Héros : course du soleil × production

    private func sunProductionCard(_ sun: SunCalc.Ephemeris, now: Date) -> some View {
        MetricCard(title: "Course du soleil et production", systemImage: "chart.xyaxis.line") {
            VStack(alignment: .leading, spacing: 8) {
                SunProductionChart(sun: sun, curve: monitor.todayCurve,
                                   peakW: max(monitor.peakTodayW, peakWatts), now: now)
                    .frame(minHeight: 170, maxHeight: .infinity)
                Text("Arc pointillé : trajectoire du soleil entre lever et coucher. Zone jaune : production mesurée aujourd'hui (max par tranche de 5 min).")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Éphémérides (colonne 1)

    private func ephemeridesCard(_ sun: SunCalc.Ephemeris) -> some View {
        MetricCard(title: "Éphémérides", systemImage: "sun.horizon.fill") {
            VStack(spacing: 5) {
                if let sunrise = sun.sunrise, let sunset = sun.sunset {
                    LegendRow(color: .orange, label: "Lever",
                              value: sunrise.formatted(date: .omitted, time: .shortened))
                    LegendRow(color: .indigo, label: "Coucher",
                              value: sunset.formatted(date: .omitted, time: .shortened))
                }
                LegendRow(color: .yellow, label: "Midi solaire",
                          value: sun.solarNoon.formatted(date: .omitted, time: .shortened))
                LegendRow(color: .teal, label: "Durée du jour",
                          value: Format.duration(minutes: sun.daylight / 60))
                LegendRow(color: .mint, label: "Élévation",
                          value: String(format: "%.0f° (max %.0f°)", sun.elevation, sun.maxElevation))
                LegendRow(color: .gray, label: "Azimut",
                          value: String(format: "%.0f°", sun.azimuth))
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Productible théorique (colonne 2)

    @ViewBuilder
    private func theoreticalCard(_ sun: SunCalc.Ephemeris) -> some View {
        MetricCard(title: "Productible théorique", systemImage: "gauge.with.needle") {
            if peakWatts > 0 {
                VStack(alignment: .leading, spacing: 8) {
                    let theoretical = peakWatts * max(0, sin(sun.elevation * .pi / 180)) * 0.9
                    VStack(spacing: 5) {
                        LegendRow(color: .yellow, label: "Théorique ciel clair",
                                  value: Format.watts(theoretical))
                        if let solar = monitor.state?.solarInputPower {
                            LegendRow(color: .green, label: "Production mesurée", value: Format.watts(solar))
                            if theoretical > 10 {
                                LegendRow(color: .teal, label: "Rendement estimé",
                                          value: "\(Int((solar / theoretical * 100).rounded())) %")
                            }
                        }
                    }
                    Text("Puissance crête × sin(élévation) × 0,9 — sans météo ni orientation.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                Text("Renseignez la puissance crête de vos panneaux (Wc) dans Réglages → Soleil pour estimer le productible et le rendement.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Météo locale (colonne 3, Open-Meteo)

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
                        if let sunshine = weather.sunshineForecastSec {
                            LegendRow(color: .yellow, label: "Ensoleillement prévu",
                                      value: Format.duration(minutes: sunshine / 60))
                        }
                        if peakWatts > 0, sun.elevation > 0 {
                            // Théorique ciel clair × (1 − 0,75 × nuages^3), formule
                            // de Kasten-Czeplak — indicatif, sans orientation.
                            let clearSky = peakWatts * max(0, sin(sun.elevation * .pi / 180)) * 0.9
                            let factor = 1 - 0.75 * pow(weather.cloudCover / 100, 3)
                            LegendRow(color: .teal, label: "Productible ajusté nuages",
                                      value: Format.watts(clearSky * factor))
                        }
                    }
                    Text("Source : Open-Meteo, rafraîchie toutes les 30 min.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
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
}

/// Arc de course du soleil + aire de production du jour, sur le même axe
/// temporel (lever → coucher).
private struct SunProductionChart: View {
    var sun: SunCalc.Ephemeris
    var curve: [Double]
    var peakW: Double
    var now: Date

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let baseline = h - 16
            let radius = min(w / 2 - 10, baseline - 10)
            let center = CGPoint(x: w / 2, y: baseline)
            let calendar = Calendar.current
            let start = sun.sunrise ?? calendar.startOfDay(for: now)
            let end = sun.sunset ?? calendar.startOfDay(for: now).addingTimeInterval(86400)
            let span = max(1, end.timeIntervalSince(start))

            ZStack {
                // Production du jour (aire jaune), un point par 5 min.
                Path { path in
                    let dayStart = calendar.startOfDay(for: now)
                    let maxY = max(peakW, curve.max() ?? 1, 1)
                    var started = false
                    var lastX: CGFloat = 0
                    for (index, value) in curve.enumerated() {
                        let t = dayStart.addingTimeInterval(Double(index) * 300)
                        let x = CGFloat(t.timeIntervalSince(start) / span) * (w - 16) + 8
                        guard x >= 8, x <= w - 8 else { continue }
                        let y = baseline - CGFloat(value / maxY) * (baseline - 18)
                        if !started {
                            path.move(to: CGPoint(x: x, y: baseline))
                            started = true
                        }
                        path.addLine(to: CGPoint(x: x, y: y))
                        lastX = x
                    }
                    if started {
                        path.addLine(to: CGPoint(x: lastX, y: baseline))
                        path.closeSubpath()
                    }
                }
                .fill(Color.yellow.opacity(0.28))

                // Trajectoire du soleil.
                Path { path in
                    path.addArc(center: center, radius: radius,
                                startAngle: .degrees(180), endAngle: .degrees(0),
                                clockwise: false)
                }
                .stroke(Color.secondary.opacity(0.3),
                        style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [3, 5]))

                // Horizon.
                Path { path in
                    path.move(to: CGPoint(x: 8, y: baseline))
                    path.addLine(to: CGPoint(x: w - 8, y: baseline))
                }
                .stroke(Color.secondary.opacity(0.4), lineWidth: 1)

                // Soleil à sa position actuelle.
                if sun.elevation > 0 {
                    let progress = min(1, max(0, now.timeIntervalSince(start) / span))
                    let angle = Double.pi * (1 - progress)
                    Image(systemName: "sun.max.fill")
                        .foregroundStyle(.yellow)
                        .position(CGPoint(x: center.x + radius * cos(angle),
                                          y: center.y - radius * sin(angle)))
                }

                Text(start.formatted(date: .omitted, time: .shortened))
                    .font(.caption2).foregroundStyle(.secondary)
                    .position(CGPoint(x: 26, y: h - 6))
                Text(end.formatted(date: .omitted, time: .shortened))
                    .font(.caption2).foregroundStyle(.secondary)
                    .position(CGPoint(x: w - 26, y: h - 6))
            }
        }
    }
}
