import Charts
import SwiftUI

/// Fenêtre « Historique » : énergie par jour (barres) sur 7/30/90/365 jours +
/// totaux vie entière, via l'API privée de l'app Zendure (tdengine). Nécessite
/// les identifiants du compte Zendure (e-mail/mot de passe), stockés dans le
/// Keychain — chemin totalement séparé du Cloud Key et de l'API locale.
struct HistoryView: View {
    @EnvironmentObject private var history: HistoryService
    @State private var rangeDays = 30
    /// Affichage de la carte Débogage (échanges HTTP), masquée par défaut.
    @AppStorage("historyShowDebug") private var showDebug = false
    /// Métrique choisie par appareil (id → clé) — chaque source renvoie sa
    /// propre liste de champs (Hub 2000 : 4, Hyper : 5…).
    @State private var metricByDevice: [String: String] = [:]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if history.isConfigured {
                    controls
                    statusBanner
                    ForEach(history.devices.filter { !history.unsupported.contains($0.id) }) { device in
                        deviceSection(device)
                    }
                    if !history.unsupported.isEmpty {
                        Text("\(history.unsupported.count) appareil(s) du compte sans historique d'énergie (SmartMeter…) masqué(s).")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    disclaimer
                } else {
                    HistorySetupCard()
                }
                if !history.exchanges.isEmpty {
                    Toggle("Afficher le débogage (échanges HTTP)", isOn: $showDebug)
                        .toggleStyle(.checkbox)
                        .font(.caption)
                    if showDebug {
                        HistoryDebugCard()
                    }
                }
            }
            .padding(20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            WindowPolicy.retain()
            loadIfNeeded()
        }
        .onDisappear { WindowPolicy.release() }
    }

    // MARK: - Contrôles

    private var controls: some View {
        HStack(spacing: 12) {
            Picker("Période", selection: $rangeDays) {
                Text("7 j").tag(7)
                Text("30 j").tag(30)
                Text("90 j").tag(90)
                Text("365 j").tag(365)
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 260)
            .onChange(of: rangeDays) { loadIfNeeded() }

            Spacer()

            Button {
                Task { await history.load(rangeDays: rangeDays) }
            } label: {
                Label("Actualiser", systemImage: "arrow.clockwise")
            }
            .disabled(isLoading)

            Button("Déconnecter le compte") {
                history.forgetCredentials()
            }
            .controlSize(.small)
        }
    }

    /// Clés vues dans les données de CET appareil, sinon les métriques
    /// usuelles — chaque source a sa propre liste.
    private func availableMetrics(for device: ZendureAppAPI.AppDevice) -> [String] {
        var keys = Set<String>()
        for day in history.days[device.id] ?? [] { keys.formUnion(day.fields.keys) }
        if keys.isEmpty { return ["solar", "home", "batteryInput", "batteryOutput"] }
        return keys.sorted { EnergyMetricCatalog.label(for: $0) < EnergyMetricCatalog.label(for: $1) }
    }

    /// Métrique effective pour un appareil : le choix mémorisé s'il est
    /// toujours proposé par cette source, sinon « solar », sinon la première.
    private func selectedMetric(for device: ZendureAppAPI.AppDevice) -> String {
        let available = availableMetrics(for: device)
        if let chosen = metricByDevice[device.id], available.contains(chosen) { return chosen }
        return available.contains("solar") ? "solar" : (available.first ?? "solar")
    }

    private func metricBinding(for device: ZendureAppAPI.AppDevice) -> Binding<String> {
        Binding(
            get: { selectedMetric(for: device) },
            set: { metricByDevice[device.id] = $0 }
        )
    }

    private var isLoading: Bool {
        if case .loading = history.phase { return true }
        if history.phase == .connecting { return true }
        return false
    }

    @ViewBuilder
    private var statusBanner: some View {
        switch history.phase {
        case .connecting:
            banner(icon: "person.badge.key", color: .blue, text: Text("Connexion au compte Zendure…"), progress: true)
        case .loading(let done, let total):
            banner(icon: "clock.arrow.circlepath", color: .blue,
                   text: Text("Récupération de l'historique… \(done)/\(total)"), progress: true)
        case .failed(let message):
            banner(icon: "exclamationmark.triangle.fill", color: .orange, text: Text(message), progress: false)
        case .idle, .notConfigured:
            EmptyView()
        }
    }

    private func banner(icon: String, color: Color, text: Text, progress: Bool) -> some View {
        HStack(spacing: 8) {
            if progress {
                ProgressView().controlSize(.small)
            } else {
                Image(systemName: icon).foregroundStyle(color)
            }
            text.font(.caption).foregroundStyle(.secondary)
            Spacer()
        }
        .padding(10)
        .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Section par appareil

    private func deviceSection(_ device: ZendureAppAPI.AppDevice) -> some View {
        let days = history.range(rangeDays, deviceId: device.id)
        let totals = history.lifetime[device.id]
        let metric = selectedMetric(for: device)
        return MetricCard(title: "\(device.displayName)", systemImage: "chart.bar.fill") {
            VStack(alignment: .leading, spacing: 12) {
                Picker("Métrique", selection: metricBinding(for: device)) {
                    ForEach(availableMetrics(for: device), id: \.self) { key in
                        Text(EnergyMetricCatalog.label(for: key)).tag(key)
                    }
                }
                .frame(maxWidth: 320, alignment: .leading)

                if days.isEmpty {
                    Text("Pas encore de données — lance une actualisation.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    chart(days, metric: metric)
                    summaryRow(days, metric: metric)
                }
                if let totals, !totals.isEmpty {
                    lifetimeRow(totals)
                }
            }
        }
    }

    private func chart(_ days: [EnergyDay], metric: String) -> some View {
        Chart(days) { day in
            if let date = day.dateValue {
                BarMark(
                    x: .value("Jour", date, unit: .day),
                    y: .value("Énergie", (day.fields[metric] ?? 0) / 1000)
                )
                .foregroundStyle(.teal)
            }
        }
        .chartYAxisLabel("kWh")
        .frame(height: 220)
    }

    private func summaryRow(_ days: [EnergyDay], metric: String) -> some View {
        let values = days.compactMap { $0.fields[metric] }
        let total = values.reduce(0, +)
        let average = values.isEmpty ? 0 : total / Double(values.count)
        let best = values.max() ?? 0
        return HStack(spacing: 18) {
            stat("Total période", Format.kilowattHours(total))
            stat("Moyenne / jour", Format.kilowattHours(average))
            stat("Meilleur jour", Format.kilowattHours(best))
            Spacer()
        }
    }

    private func lifetimeRow(_ totals: [String: Double]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Totaux vie entière")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(totals.sorted { $0.key < $1.key }
                .map { "\(EnergyMetricCatalog.label(for: $0.key)) \(Format.kilowattHours($0.value))" }
                .joined(separator: " · "))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func stat(_ label: LocalizedStringKey, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption2).foregroundStyle(.secondary)
            Text(value).font(.caption.monospacedDigit().weight(.semibold))
        }
    }

    private var disclaimer: some View {
        Text("Source : API privée de l'app Zendure (endpoints tdengine, non contractuels). Unités supposées en Wh. Les jours déjà récupérés sont mis en cache localement ; seul le jour courant est re-téléchargé.")
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func loadIfNeeded() {
        guard history.isConfigured, !isLoading else { return }
        Task { await history.load(rangeDays: rangeDays) }
    }
}

/// Débogage : les derniers échanges HTTP avec l'API app (mot de passe
/// masqué) — statut, requête et réponse brute, dépliables et copiables.
private struct HistoryDebugCard: View {
    @EnvironmentObject private var history: HistoryService
    @State private var expandedIds: Set<Int> = []

    var body: some View {
        MetricCard(title: "Débogage — échanges avec l'API app", systemImage: "stethoscope") {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("\(history.exchanges.count) échange(s) — cliquer pour déplier requête/réponse.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Vider") { history.clearDebugLog() }
                        .controlSize(.small)
                }
                .padding(.bottom, 6)

                ForEach(history.exchanges.reversed()) { exchange in
                    row(exchange)
                    Divider()
                }
            }
        }
    }

    private func row(_ exchange: ZendureAppAPI.Exchange) -> some View {
        let expanded = expandedIds.contains(exchange.id)
        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Circle()
                    .fill(statusColor(exchange.status))
                    .frame(width: 8, height: 8)
                Text(exchange.label)
                    .font(.caption.weight(.medium))
                Text(exchange.status == 0 ? "—" : "HTTP \(exchange.status)")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
                Text(exchange.url)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                Text(exchange.date, format: .dateTime.hour().minute().second())
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
                Image(systemName: expanded ? "chevron.down" : "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            if expanded {
                VStack(alignment: .leading, spacing: 6) {
                    if !exchange.requestBody.isEmpty {
                        payloadBlock(title: "Requête", content: exchange.requestBody)
                    }
                    payloadBlock(title: "Réponse", content: exchange.responseBody.isEmpty ? "(vide)" : exchange.responseBody)
                }
            }
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onTapGesture {
            if expanded { expandedIds.remove(exchange.id) } else { expandedIds.insert(exchange.id) }
        }
    }

    private func payloadBlock(title: LocalizedStringKey, content: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            ScrollView(.horizontal) {
                Text(content)
                    .font(.caption2.monospaced())
                    .textSelection(.enabled)
                    .padding(6)
            }
            .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
        }
    }

    private func statusColor(_ status: Int) -> Color {
        switch status {
        case 200..<300: .green
        case 0: .red
        default: .orange
        }
    }
}

/// Saisie des identifiants du compte Zendure (compte principal) pour
/// l'historique. Stockés uniquement dans le Keychain.
private struct HistorySetupCard: View {
    @EnvironmentObject private var history: HistoryService
    @State private var account = ""
    @State private var password = ""

    var body: some View {
        MetricCard(title: "Compte Zendure (historique)", systemImage: "person.badge.key") {
            VStack(alignment: .leading, spacing: 12) {
                Text("L'historique (jusqu'à 365 jours) passe par l'API privée de l'app mobile : elle exige l'e-mail et le mot de passe du **compte principal** Zendure — le Cloud Key ne suffit pas. Identifiants stockés uniquement dans le trousseau macOS.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                TextField("E-mail du compte Zendure", text: $account)
                    .textFieldStyle(.roundedBorder)
                SecureField("Mot de passe", text: $password)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(apply)

                HStack {
                    Spacer()
                    Button("Se connecter", action: apply)
                        .keyboardShortcut(.defaultAction)
                        .disabled(account.trimmingCharacters(in: .whitespaces).isEmpty || password.isEmpty)
                }
            }
        }
        .frame(maxWidth: 480)
    }

    private func apply() {
        history.saveCredentials(account: account, password: password)
        password = ""
        Task { await history.load(rangeDays: 30) }
    }
}
