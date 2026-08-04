import SwiftUI
import Charts

/// Histogramme de production quotidienne (kWh par jour), même langage visuel
/// que les sparklines : dégradé, coins arrondis, axes discrets.
struct DailyBarChart: View {
    var days: [DayEnergy]
    var color: Color

    var body: some View {
        Chart(days) { day in
            BarMark(
                x: .value("Jour", day.date, unit: .day),
                y: .value("Wh", day.wh)
            )
            .foregroundStyle(
                LinearGradient(
                    colors: [color.opacity(day.day == days.last?.day ? 1.0 : 0.55),
                             color.opacity(day.day == days.last?.day ? 0.5 : 0.25)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .cornerRadius(3)
        }
        .chartYAxis(.hidden)
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: max(1, days.count / 4))) { _ in
                AxisValueLabel(format: .dateTime.day().month(), centered: true)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .chartLegend(.hidden)
    }
}
