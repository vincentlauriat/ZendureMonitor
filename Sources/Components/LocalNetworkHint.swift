import SwiftUI

/// Bandeau d'aide affiché quand les échecs de connexion ressemblent à un
/// refus TCC « réseau local » (TN3179 : ENETDOWN / -1009, ou hôte local
/// injoignable). Guide l'utilisateur vers le réglage macOS au lieu de
/// laisser l'app échouer en silence — le grant se perd notamment à chaque
/// remplacement de l'app dans /Applications.
struct LocalNetworkHint: View {
    var retry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Accès au réseau local bloqué ?", systemImage: "wifi.exclamationmark")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.orange)
            Text("macOS semble empêcher Zendure Monitor d'atteindre le réseau local. Si la batterie est bien allumée, vérifiez que l'app est autorisée dans Réglages → Confidentialité et sécurité → Réseau local (désactivez puis réactivez l'interrupteur), puis réessayez. Si le blocage persiste, redémarrez le Mac.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                Button("Ouvrir les réglages…") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocalNetwork") {
                        NSWorkspace.shared.open(url)
                    }
                }
                Button("Réessayer") { retry() }
            }
            .buttonStyle(.borderless)
            .font(.caption)
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.orange.opacity(0.08)))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.orange.opacity(0.35), lineWidth: 1))
    }
}
