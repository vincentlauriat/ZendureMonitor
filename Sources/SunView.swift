import SwiftUI

/// Fenêtre « Soleil » : éphémérides (SunCard), course du soleil superposée à
/// la production du jour, et productible théorique ciel clair. Séparée du
/// tableau de bord — qui reste un tableau de bord.
struct SunView: View {
    var body: some View {
        ScrollView {
            SunContent()
        }
        .frame(minWidth: 480, idealWidth: 540, minHeight: 560, idealHeight: 680)
        .navigationTitle(Text("Zendure Monitor — Soleil"))
        .onAppear { WindowPolicy.retain() }
        .onDisappear { WindowPolicy.release() }
    }
}

/// Contenu de la fenêtre Soleil, séparé du ScrollView pour rester rendable
/// hors fenêtre (ImageRenderer ne rend pas l'intérieur d'un ScrollView).
struct SunContent: View {
    @EnvironmentObject var monitor: Monitor
    @AppStorage("sunLatitude") private var latitude: Double = 0
    @AppStorage("sunLongitude") private var longitude: Double = 0
    @AppStorage("sunPeakWatts") private var peakWatts: Double = 0

    private var configured: Bool { latitude != 0 || longitude != 0 }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { timeline in
            let sun = SunCalc.compute(at: timeline.date, latitude: latitude, longitude: longitude)
            VStack(spacing: 14) {
                SunCard()
                if configured {
                    sunProductionCard(sun, now: timeline.date)
                    theoreticalCard(sun)
                }
            }
            .padding(16)
        }
    }

    // MARK: - Course du soleil × production

    private func sunProductionCard(_ sun: SunCalc.Ephemeris, now: Date) -> some View {
        MetricCard(title: "Course du soleil et production", systemImage: "chart.xyaxis.line") {
            VStack(alignment: .leading, spacing: 8) {
                SunProductionChart(sun: sun, curve: monitor.todayCurve,
                                   peakW: max(monitor.peakTodayW, peakWatts), now: now)
                    .frame(height: 150)
                Text("Arc pointillé : trajectoire du soleil entre lever et coucher. Zone jaune : production mesurée aujourd'hui (max par tranche de 5 min).")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Productible théorique

    @ViewBuilder
    private func theoreticalCard(_ sun: SunCalc.Ephemeris) -> some View {
        MetricCard(title: "Productible théorique", systemImage: "gauge.with.needle") {
            if peakWatts > 0 {
                VStack(alignment: .leading, spacing: 8) {
                    let theoretical = peakWatts * max(0, sin(sun.elevation * .pi / 180)) * 0.9
                    VStack(spacing: 5) {
                        LegendRow(color: .yellow, label: "Théorique ciel clair (maintenant)",
                                  value: Format.watts(theoretical))
                        if let solar = monitor.state?.solarInputPower {
                            LegendRow(color: .green, label: "Production mesurée", value: Format.watts(solar))
                            if theoretical > 10 {
                                LegendRow(color: .teal, label: "Rendement estimé",
                                          value: "\(Int((solar / theoretical * 100).rounded())) %")
                            }
                        }
                    }
                    Text("Estimation indicative : puissance crête × sin(élévation) × 0,9 — sans météo ni orientation des panneaux.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                Text("Renseignez la puissance crête de vos panneaux (Wc) dans Réglages → Général pour estimer le productible ciel clair et le rendement.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
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
