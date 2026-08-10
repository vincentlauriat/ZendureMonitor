import SwiftUI

/// Conteneur de carte réutilisable : titre, fond matériel, coins arrondis.
/// Composant repris de MacInside pour un style commun entre les apps.
/// Avec `collapseKey`, la carte devient repliable d'un clic sur son en-tête
/// (chevron, état persisté sous cette clé UserDefaults — style Juicy) ;
/// repliée, elle n'affiche que l'en-tête et un résumé compact optionnel.
struct MetricCard<Content: View>: View {
    var title: LocalizedStringKey
    var systemImage: String? = nil
    var collapseKey: String? = nil
    /// Valeur compacte affichée à droite de l'en-tête quand la carte est repliée.
    var collapsedSummary: String? = nil
    @ViewBuilder var content: () -> Content
    @State private var collapsed: Bool

    init(title: LocalizedStringKey,
         systemImage: String? = nil,
         collapseKey: String? = nil,
         collapsedSummary: String? = nil,
         @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.systemImage = systemImage
        self.collapseKey = collapseKey
        self.collapsedSummary = collapsedSummary
        self.content = content
        _collapsed = State(initialValue: collapseKey.map { UserDefaults.standard.bool(forKey: $0) } ?? false)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            if !collapsed { content() }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06))
        )
    }

    private var header: some View {
        HStack(spacing: 6) {
            if let systemImage {
                Image(systemName: systemImage)
                    .foregroundStyle(.secondary)
            }
            Text(title)
                .font(.headline)
                .lineLimit(1)
            Spacer()
            if let collapseKey {
                if collapsed, let collapsedSummary {
                    Text(collapsedSummary)
                        .font(.callout.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                Image(systemName: "chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .rotationEffect(.degrees(collapsed ? -90 : 0))
                    .accessibilityHidden(true)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            guard let collapseKey else { return }
            withAnimation(.easeInOut(duration: 0.18)) { collapsed.toggle() }
            UserDefaults.standard.set(collapsed, forKey: collapseKey)
        }
        .help(collapseKey != nil ? Text("Replier / déployer la carte") : Text(verbatim: ""))
    }
}

/// Ligne libellé/valeur avec pastille de couleur, pour les légendes de jauges.
struct LegendRow: View {
    var color: Color
    var label: LocalizedStringKey
    var value: String

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.caption.monospacedDigit())
        }
    }
}
