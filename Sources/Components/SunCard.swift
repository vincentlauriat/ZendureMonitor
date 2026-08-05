import SwiftUI

/// Carte « Soleil » du tableau de bord : éphémérides locales (SunCalc) pour
/// la position configurée dans Réglages → Général. Arc de course du soleil
/// avec sa position actuelle, lever/coucher, midi solaire, durée du jour,
/// élévation. Recalculée toutes les minutes.
struct SunCard: View {
    @AppStorage("sunLatitude") private var latitude: Double = 0
    @AppStorage("sunLongitude") private var longitude: Double = 0

    private var configured: Bool { latitude != 0 || longitude != 0 }

    var body: some View {
        MetricCard(title: "Soleil", systemImage: "sun.horizon.fill") {
            if configured {
                TimelineView(.periodic(from: .now, by: 60)) { timeline in
                    content(SunCalc.compute(at: timeline.date,
                                            latitude: latitude, longitude: longitude),
                            now: timeline.date)
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Renseignez votre position (latitude/longitude) dans Réglages → Général pour afficher les éphémérides du soleil.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    UseMacLocationButton()
                }
            }
        }
    }

    @ViewBuilder
    private func content(_ sun: SunCalc.Ephemeris, now: Date) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SunArc(progress: dayProgress(sun, now: now), aboveHorizon: sun.elevation > 0)
                .frame(height: 56)
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
    }

    /// Position du soleil sur l'arc : 0 = lever, 1 = coucher.
    private func dayProgress(_ sun: SunCalc.Ephemeris, now: Date) -> Double {
        guard let sunrise = sun.sunrise, let sunset = sun.sunset,
              sunset > sunrise else { return 0 }
        return min(1, max(0, now.timeIntervalSince(sunrise) / sunset.timeIntervalSince(sunrise)))
    }
}

/// Demi-arc « course du soleil » avec point à la position actuelle.
private struct SunArc: View {
    var progress: Double        // 0 → 1 entre lever et coucher
    var aboveHorizon: Bool

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let radius = min(w / 2 - 8, h - 10)
            let center = CGPoint(x: w / 2, y: h - 4)
            let angle = Double.pi * (1 - progress)   // π = lever (gauche), 0 = coucher (droite)
            let sunPoint = CGPoint(x: center.x + radius * cos(angle),
                                   y: center.y - radius * sin(angle))
            ZStack {
                Path { path in
                    path.addArc(center: center, radius: radius,
                                startAngle: .degrees(180), endAngle: .degrees(0),
                                clockwise: false)
                }
                .stroke(Color.secondary.opacity(0.25),
                        style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [3, 5]))
                Path { path in
                    path.move(to: CGPoint(x: 4, y: center.y))
                    path.addLine(to: CGPoint(x: w - 4, y: center.y))
                }
                .stroke(Color.secondary.opacity(0.35), lineWidth: 1)
                if aboveHorizon {
                    Image(systemName: "sun.max.fill")
                        .font(.callout)
                        .foregroundStyle(.yellow)
                        .position(sunPoint)
                } else {
                    Image(systemName: "moon.fill")
                        .font(.caption)
                        .foregroundStyle(.indigo)
                        .position(CGPoint(x: center.x, y: center.y - radius * 0.35))
                }
            }
        }
    }
}
