import WidgetKit
import SwiftUI

@main
struct ZendureWidgetBundle: WidgetBundle {
    var body: some Widget {
        SolarProductionWidget()
    }
}

struct SolarEntry: TimelineEntry {
    let date: Date
    let result: WidgetSnapshotStore.ReadResult
}

struct SolarProvider: TimelineProvider {
    func placeholder(in context: Context) -> SolarEntry {
        SolarEntry(date: .now, result: .available(.sample))
    }

    func getSnapshot(in context: Context, completion: @escaping (SolarEntry) -> Void) {
        completion(SolarEntry(date: .now, result: context.isPreview ? .available(.sample) : WidgetSnapshotStore.read()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SolarEntry>) -> Void) {
        let entry = SolarEntry(date: .now, result: WidgetSnapshotStore.read())
        let refresh = Calendar.current.date(byAdding: .minute, value: 10, to: .now)!
        completion(Timeline(entries: [entry], policy: .after(refresh)))
    }
}

struct SolarProductionWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "SolarProduction", provider: SolarProvider()) { entry in
            SolarWidgetView(entry: entry)
                .containerBackground(for: .widget) { Color.clear }
        }
        .configurationDisplayName("Production solaire")
        .description(String(localized: "Production, batterie et énergie du jour."))
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct SolarWidgetView: View {
    @Environment(\.widgetFamily) private var family
    var entry: SolarEntry

    var body: some View {
        switch entry.result {
        case .available(let snapshot):
            content(snapshot)
        case .notYetPublished:
            message("Ouvrez Zendure Monitor")
        case .containerUnavailable:
            message("Conteneur partagé indisponible")
        }
    }

    private func message(_ key: LocalizedStringKey) -> some View {
        VStack(spacing: 6) {
            Image(systemName: "sun.max.trianglebadge.exclamationmark")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text(key)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    @ViewBuilder
    private func content(_ snapshot: WidgetSnapshot) -> some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "sun.max.fill")
                        .foregroundStyle(.yellow)
                    Text(WidgetFormat.watts(snapshot.solarInputPower))
                        .font(.system(.title3, design: .rounded).weight(.semibold))
                        .monospacedDigit()
                        .minimumScaleFactor(0.7)
                }
                if let soc = snapshot.electricLevel {
                    Label("\(Int(soc)) %", systemImage: "battery.100percent")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(soc <= 15 ? .red : .secondary)
                }
                Label(WidgetFormat.watts(snapshot.outputHomePower), systemImage: "house")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                HStack(spacing: 4) {
                    Text(WidgetFormat.kilowattHours(snapshot.energyTodayWh))
                        .font(.caption2.monospacedDigit())
                    Text("aujourd'hui")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Text(snapshot.capturedAt, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            if family == .systemMedium {
                MiniSparkline(values: snapshot.solarHistory)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

/// Mini-courbe sans dépendance Charts : un simple Path lissé suffit ici.
struct MiniSparkline: View {
    var values: [Double]

    var body: some View {
        GeometryReader { geo in
            if values.count > 1, let maxValue = values.max(), maxValue > 0 {
                let points = values.enumerated().map { index, value in
                    CGPoint(
                        x: geo.size.width * CGFloat(index) / CGFloat(values.count - 1),
                        y: geo.size.height * (1 - CGFloat(value / maxValue) * 0.9)
                    )
                }
                ZStack {
                    Path { path in
                        path.move(to: CGPoint(x: points[0].x, y: geo.size.height))
                        points.forEach { path.addLine(to: $0) }
                        path.addLine(to: CGPoint(x: points[points.count - 1].x, y: geo.size.height))
                        path.closeSubpath()
                    }
                    .fill(LinearGradient(colors: [.yellow.opacity(0.35), .yellow.opacity(0.02)],
                                         startPoint: .top, endPoint: .bottom))
                    Path { path in
                        path.move(to: points[0])
                        points.dropFirst().forEach { path.addLine(to: $0) }
                    }
                    .stroke(.yellow, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                }
            }
        }
    }
}

/// Copie locale minimale du formateur de l'app (l'extension ne compile pas Monitor.swift).
enum WidgetFormat {
    static func watts(_ value: Double) -> String {
        abs(value) >= 1000 ? String(format: "%.1f kW", locale: .current, value / 1000)
                           : "\(Int(value.rounded())) W"
    }
    static func kilowattHours(_ wh: Double) -> String {
        wh >= 1000 ? String(format: "%.2f kWh", locale: .current, wh / 1000)
                   : "\(Int(wh.rounded())) Wh"
    }
}
