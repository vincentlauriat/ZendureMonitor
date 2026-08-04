import SwiftUI

struct GaugeSegment: Identifiable {
    let id = UUID()
    var value: Double
    var color: Color
}

/// Anneau de charge empilable (plusieurs segments colorés) avec texte au centre.
/// Composant repris de MacInside pour un style commun entre les apps.
struct CircularGauge: View {
    var segments: [GaugeSegment]
    var lineWidth: CGFloat = 11
    var centerText: String
    var centerSubtext: String? = nil

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.15), lineWidth: lineWidth)

            ForEach(stackedSegments) { seg in
                Circle()
                    .trim(from: seg.start, to: seg.end)
                    .stroke(seg.color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }

            VStack(spacing: 2) {
                Text(centerText)
                    .font(.system(.title2, design: .rounded).weight(.semibold))
                    .monospacedDigit()
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                if let centerSubtext {
                    Text(centerSubtext)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, lineWidth * 1.5)
        }
        .animation(.easeInOut(duration: 0.4), value: segments.map(\.value))
    }

    private struct StackedSegment: Identifiable {
        var id: UUID
        var start: Double
        var end: Double
        var color: Color
    }

    private var stackedSegments: [StackedSegment] {
        var cursor = 0.0
        var result: [StackedSegment] = []
        for seg in segments where seg.value > 0 {
            let fraction = min(max(seg.value, 0), 100) / 100
            let end = min(cursor + fraction, 1.0)
            result.append(StackedSegment(id: seg.id, start: cursor, end: end, color: seg.color))
            cursor = end
        }
        return result
    }
}
