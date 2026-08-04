import SwiftUI
import Charts

/// Mini-graphique de tendance (aire + ligne) pour un historique de valeurs.
/// Composant repris de MacInside pour un style commun entre les apps.
struct SparklineChart: View {
    var values: [Double]
    var color: Color

    var body: some View {
        if values.count < 2 {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.secondary.opacity(0.08))
                .overlay {
                    Text("Pas encore de données")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
        } else {
            Chart {
                ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                    AreaMark(
                        x: .value("Index", index),
                        y: .value("Valeur", value)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [color.opacity(0.35), color.opacity(0.02)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)

                    LineMark(
                        x: .value("Index", index),
                        y: .value("Valeur", value)
                    )
                    .foregroundStyle(color)
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                    .interpolationMethod(.catmullRom)
                }
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .chartLegend(.hidden)
        }
    }
}
