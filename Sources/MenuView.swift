import SwiftUI
import UniformTypeIdentifiers

/// Panneau principal, style MacInside : cartes MetricCard avec jauge circulaire
/// pour la batterie et sparklines pour les tendances.
struct MenuView: View {
    @EnvironmentObject var monitor: Monitor
    @Environment(\.openSettings) private var openSettings
    @Environment(\.openWindow) private var openWindow
    /// Période du graphe principal : "recent" (15 min), "today", "14d".
    @AppStorage("chartPeriod") private var chartPeriod = "recent"
    /// Visibilité des cartes du panneau (Réglages → Affichage → Cartes du panneau).
    @AppStorage("showSolarCard") private var showSolarCard = true
    @AppStorage("showBatteryCard") private var showBatteryCard = true
    @AppStorage("showFlowsCard") private var showFlowsCard = true
    @AppStorage("showConsumptionCard") private var showConsumptionCard = true
    @AppStorage("showHistoryCard") private var showHistoryCard = true

    private let solarColor = Color.yellow
    private let homeColor = Color.blue
    private let gridColor = Color.orange
    private let chargeColor = Color.green
    private let dischargeColor = Color.orange

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            if let state = monitor.state {
                Group {
                    if showSolarCard { solarCard(state) }
                    if showBatteryCard { batteryCard(state) }
                    if showFlowsCard { flowsCard(state) }
                    if showConsumptionCard { consumptionCard(state) }
                    if showHistoryCard { historyCard() }
                }
                .opacity(isStale ? 0.55 : 1)
            } else {
                MetricCard(title: "Pas de données", systemImage: "sun.max.trianglebadge.exclamationmark") {
                    Text(monitor.lastError ?? "Connexion au SolarFlow en cours…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            warnings
            Divider()
            connectionFooter
        }
        .padding(12)
        .frame(width: 320)
    }

    // MARK: - Cartes

    private func solarCard(_ state: DeviceState) -> some View {
        MetricCard(title: "Production solaire", systemImage: "sun.max.fill",
                   collapseKey: "collapseSolarCard",
                   collapsedSummary: Format.watts(state.solarInputPower)) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text(Format.watts(state.solarInputPower))
                        .font(.system(.title, design: .rounded).weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(state.solarInputPower > 0 ? .primary : .secondary)
                    Spacer()
                    VStack(alignment: .trailing, spacing: 0) {
                        Text(Format.kilowattHours(monitor.energyTodayWh))
                            .font(.callout.monospacedDigit())
                        Text("aujourd'hui")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Group {
                    switch chartPeriod {
                    case "today":
                        SparklineChart(values: monitor.todayCurve, color: solarColor)
                    case "14d":
                        DailyBarChart(days: monitor.dailyEnergy, color: solarColor)
                    default:
                        SparklineChart(values: monitor.solarHistory, color: solarColor)
                    }
                }
                .frame(height: 36)
                .openDashboardOnDoubleClick(openWindow)

                Picker("", selection: $chartPeriod) {
                    Text("15 min").tag("recent")
                    Text("Jour").tag("today")
                    Text("14 j").tag("14d")
                }
                .pickerStyle(.segmented)
                .controlSize(.mini)
                .labelsHidden()

                if state.solarChannels.count > 1 {
                    VStack(spacing: 4) {
                        ForEach(Array(state.solarChannels.enumerated()), id: \.offset) { index, watts in
                            LegendRow(color: solarColor.opacity(0.55 + 0.15 * Double(index % 3)),
                                      label: "Entrée PV \(index + 1)",
                                      value: Format.watts(watts))
                        }
                    }
                }
            }
        }
    }

    private func batteryCard(_ state: DeviceState) -> some View {
        MetricCard(title: "Batterie", systemImage: "battery.100percent",
                   collapseKey: "collapseBatteryCard",
                   collapsedSummary: "\(Int(state.electricLevel ?? 0)) %") {
            HStack(alignment: .center, spacing: 16) {
                let soc = state.electricLevel ?? 0
                CircularGauge(
                    segments: [GaugeSegment(value: soc, color: socColor(soc))],
                    centerText: "\(Int(soc)) %",
                    centerSubtext: flowSubtext(state)
                )
                .frame(width: 88, height: 88)

                VStack(spacing: 6) {
                    LegendRow(color: chargeColor, label: "Charge",
                              value: state.batteryFlow > 5 ? Format.watts(state.batteryFlow) : "—")
                    LegendRow(color: dischargeColor, label: "Décharge",
                              value: state.batteryFlow < -5 ? Format.watts(-state.batteryFlow) : "—")
                    SparklineChart(values: monitor.flowHistory, color: state.batteryFlow >= 0 ? chargeColor : dischargeColor, baseline: 0)
                        .frame(height: 26)
                        .openDashboardOnDoubleClick(openWindow)
                }
            }
            if !state.packs.isEmpty {
                VStack(spacing: 4) {
                    ForEach(Array(state.packs.enumerated()), id: \.element.id) { index, pack in
                        LegendRow(color: .teal,
                                  label: "Pack \(index + 1)",
                                  value: packSummary(pack))
                    }
                }
                .padding(.top, 6)
            }
        }
    }

    private func packSummary(_ pack: PackInfo) -> String {
        var parts: [String] = []
        if let soc = pack.socLevel { parts.append("\(Int(soc)) %") }
        if let temp = pack.temperature { parts.append("\(Int(temp.rounded())) °C") }
        if let power = pack.power, abs(power) > 5 { parts.append(Format.watts(power)) }
        return parts.isEmpty ? "—" : parts.joined(separator: " · ")
    }

    private func flowsCard(_ state: DeviceState) -> some View {
        MetricCard(title: "Flux", systemImage: "arrow.left.arrow.right",
                   collapseKey: "collapseFlowsCard",
                   collapsedSummary: Format.watts(state.outputHomePower)) {
            VStack(alignment: .leading, spacing: 8) {
                LegendRow(color: homeColor, label: "Vers la maison", value: Format.watts(state.outputHomePower))
                LegendRow(color: gridColor, label: "Depuis le réseau", value: Format.watts(state.gridInputPower))
                SparklineChart(values: monitor.homeHistory, color: homeColor)
                    .frame(height: 36)
                    .openDashboardOnDoubleClick(openWindow)
                if let stored = EnergyMath.storedShare(storedWh: monitor.storedTodayWh,
                                                       solarWh: monitor.energyTodayWh) {
                    let storedPct = Int((stored * 100).rounded())
                    HStack(spacing: 10) {
                        Text("Solaire du jour : \(100 - storedPct) % direct · \(storedPct) % stocké")
                        Spacer()
                        if monitor.gridTodayWh >= 10 {
                            Text("Réseau : \(Format.kilowattHours(monitor.gridTodayWh))")
                        }
                    }
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
                }
            }
        }
    }

    /// Consommation totale de la maison. Avec un Smart CT configuré, c'est le
    /// soutirage réseau (hors charge secteur du SolarFlow) + l'injection du
    /// SolarFlow ; sans compteur, seule l'injection est connue.
    private func consumptionCard(_ state: DeviceState) -> some View {
        let summary: Double = monitor.ctReport.map {
            EnergyMath.homeTotal(ctTotal: $0.totalPower,
                                 gridIn: state.gridInputPower,
                                 outputHome: state.outputHomePower)
        } ?? state.outputHomePower
        return MetricCard(title: "Consommation maison", systemImage: "house.fill",
                          collapseKey: "collapseConsumptionCard",
                          collapsedSummary: Format.watts(summary)) {
            VStack(alignment: .leading, spacing: 8) {
                if let ct = monitor.ctReport {
                    let gridToHome = EnergyMath.gridToHome(ctTotal: ct.totalPower,
                                                           gridIn: state.gridInputPower)
                    HStack(alignment: .firstTextBaseline) {
                        Text(Format.watts(gridToHome + state.outputHomePower))
                            .font(.system(.title, design: .rounded).weight(.semibold))
                            .monospacedDigit()
                        Spacer()
                        Text("totale")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    LegendRow(color: homeColor, label: "Depuis le SolarFlow",
                              value: Format.watts(state.outputHomePower))
                    LegendRow(color: gridColor, label: "Depuis le réseau",
                              value: Format.watts(gridToHome))
                } else {
                    HStack(alignment: .firstTextBaseline) {
                        Text(Format.watts(state.outputHomePower))
                            .font(.system(.title, design: .rounded).weight(.semibold))
                            .monospacedDigit()
                        Spacer()
                        Text("via SolarFlow seulement")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    if monitor.ctConfigured {
                        Label("Smart CT injoignable — il n'est lisible que depuis le réseau local, pas via le cloud. Le soutirage réseau de la maison n'est pas compté : cette valeur est partielle.",
                              systemImage: "wifi.slash")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        Text("Soutirage réseau direct non mesuré — renseignez le Smart CT dans Réglages → Réseau pour la consommation totale.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    private func historyCard() -> some View {
        MetricCard(title: "Historique", systemImage: "calendar",
                   collapseKey: "collapseHistoryCard",
                   collapsedSummary: Format.kilowattHours(monitor.dailyEnergy.reduce(0) { $0 + $1.wh })) {
            VStack(alignment: .leading, spacing: 8) {
                if monitor.dailyEnergy.count > 1 {
                    DailyBarChart(days: monitor.dailyEnergy, color: solarColor)
                        .frame(height: 72)
                        .openDashboardOnDoubleClick(openWindow)
                    HStack {
                        Text("\(monitor.dailyEnergy.count) derniers jours")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Spacer()
                        let total = monitor.dailyEnergy.reduce(0) { $0 + $1.wh }
                        Text("Total : \(Format.kilowattHours(total))")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.secondary)
                        Button {
                            exportCSV()
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                        }
                        .buttonStyle(.borderless)
                        .font(.caption)
                        .help(Text("Exporter l'historique en CSV"))
                    }
                    HStack(spacing: 10) {
                        if monitor.peakTodayW > 0 {
                            Text("Pic : \(Format.watts(monitor.peakTodayW))")
                        }
                        if let yesterday = monitor.yesterdayWh, yesterday > 0 {
                            let delta = Int(((monitor.energyTodayWh - yesterday) / yesterday * 100).rounded())
                            Text("vs hier : \(delta >= 0 ? "+" : "")\(delta) %")
                        }
                        Spacer()
                    }
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
                } else {
                    Text("L'historique se construira jour après jour.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func exportCSV() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.nameFieldStringValue = "zendure-production.csv"
        NSApp.activate(ignoringOtherApps: true)
        if panel.runModal() == .OK, let url = panel.url {
            try? monitor.historyCSV().write(to: url, atomically: true, encoding: .utf8)
        }
    }

    // MARK: - En-tete (style Juicy : actions en icones, pas de rangee de boutons)

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "sun.max.fill")
                .font(.title3)
                .foregroundStyle(.yellow)
            VStack(alignment: .leading, spacing: 1) {
                Text(verbatim: "Zendure Monitor")
                    .font(.headline)
                if let updatedAt = monitor.state?.updatedAt {
                    if isStale {
                        Text("Hors ligne \u{2014} derni\u{00e8}res donn\u{00e9}es \u{00e0} \(updatedAt.formatted(date: .omitted, time: .standard))")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    } else {
                        Text("Mis \u{00e0} jour \u{00e0} \(updatedAt.formatted(date: .omitted, time: .standard))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("Connexion au SolarFlow en cours\u{2026}")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            headerButton("gauge.with.dots.needle.67percent", color: .blue, help: "Tableau de bord") {
                openWindow(id: "dashboard")
                NSApp.activate(ignoringOtherApps: true)
            }
            headerButton("sun.horizon.fill", color: .orange, help: "Soleil") {
                openWindow(id: "sun")
                NSApp.activate(ignoringOtherApps: true)
            }
            headerButton("clock.arrow.circlepath", color: .purple, help: "Historique") {
                openWindow(id: "history")
                NSApp.activate(ignoringOtherApps: true)
            }
            headerButton("gearshape.fill", color: .teal, help: "R\u{00e9}glages") {
                openSettings()
                NSApp.activate(ignoringOtherApps: true)
            }
            Menu {
                Button("Rechercher des mises \u{00e0} jour\u{2026}") { Updater.checkForUpdates() }
                Divider()
                Button("Quitter Zendure Monitor") { NSApplication.shared.terminate(nil) }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.primary)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
        }
        .padding(.horizontal, 2)
    }

    private func headerButton(_ icon: String, color: Color, help: LocalizedStringKey,
                              action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(color)
                .frame(width: 24, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .help(Text(help))
    }

    // MARK: - Avertissements

    @ViewBuilder
    private var warnings: some View {
        if monitor.state != nil, let error = monitor.lastError {
            Label(error, systemImage: "exclamationmark.triangle")
                .font(.caption)
                .foregroundStyle(.orange)
                .fixedSize(horizontal: false, vertical: true)
        }
        if monitor.localNetworkDenied {
            LocalNetworkHint { monitor.restart() }
        }
        if monitor.notificationsDenied {
            HStack(spacing: 6) {
                Label("Notifications refus\u{00e9}es \u{2014} l'alerte batterie faible ne s'affichera pas.", systemImage: "bell.slash")
                    .font(.caption2)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
                Button("Autoriser\u{2026}") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .buttonStyle(.borderless)
                .font(.caption)
            }
        }
    }

    // MARK: - Pied : mode de connexion

    /// Ligne permanente en bas du panneau : par où arrivent les données
    /// (cloud, hôte local principal ou hôte local de secours), avec une
    /// pastille verte/orange selon que le dernier cycle a réussi.
    private var connectionFooter: some View {
        HStack(spacing: 5) {
            Image(systemName: connectionIcon)
                .font(.caption2)
            Text(connectionText)
                .font(.caption2)
            Spacer()
            Circle()
                .fill(monitor.lastError == nil ? Color.green : Color.orange)
                .frame(width: 6, height: 6)
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 2)
    }

    private var connectionIcon: String {
        if monitor.connectionMode == .cloud { return "icloud" }
        return monitor.usingFallback ? "network" : "house"
    }

    private var connectionText: String {
        if monitor.connectionMode == .cloud {
            return monitor.autoSwitchedToCloud
                ? String(localized: "Connexion : Cloud Zendure — bascule auto")
                : String(localized: "Connexion : Cloud Zendure")
        }
        return monitor.usingFallback
            ? String(localized: "Connexion : locale — hôte de secours")
            : String(localized: "Connexion : locale — hôte principal")
    }

    // MARK: - Helpers

    /// Données périmées : le poll échoue et le dernier état a plus de 60 s.
    /// Le panneau garde alors les dernières valeurs, grisées, avec l'heure.
    private var isStale: Bool {
        guard let state = monitor.state, monitor.lastError != nil else { return false }
        return Date.now.timeIntervalSince(state.updatedAt) > 60
    }

    private func socColor(_ soc: Double) -> Color {
        switch soc {
        case ..<15: return .red
        case ..<40: return .orange
        default: return .green
        }
    }

    private func flowSubtext(_ state: DeviceState) -> String? {
        if state.batteryFlow > 5 { return String(localized: "charge") }
        if state.batteryFlow < -5 { return String(localized: "décharge") }
        return nil
    }
}

/// Double-clic sur un graphique du panneau → fenêtre Tableau de bord.
private extension View {
    func openDashboardOnDoubleClick(_ openWindow: OpenWindowAction) -> some View {
        contentShape(Rectangle())
            .onTapGesture(count: 2) {
                openWindow(id: "dashboard")
                NSApp.activate(ignoringOtherApps: true)
            }
            .help(Text("Double-clic : ouvrir le tableau de bord"))
    }
}

