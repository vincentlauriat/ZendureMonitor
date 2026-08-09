import SwiftUI

/// Fenêtre « Tableau de bord » : schéma de flux + tous les indicateurs,
/// dans le même langage visuel que MacInside.
struct DashboardView: View {
    var body: some View {
        ScrollView {
            DashboardContent()
        }
        .frame(minWidth: 760, idealWidth: 820, minHeight: 640, idealHeight: 720)
        .navigationTitle(Text("Zendure Monitor — Tableau de bord"))
        .onAppear { WindowPolicy.retain() }
        .onDisappear { WindowPolicy.release() }
    }
}

/// Contenu du tableau de bord, séparé du ScrollView pour rester rendable
/// hors fenêtre (ImageRenderer ne rend pas l'intérieur d'un ScrollView).
struct DashboardContent: View {
    @EnvironmentObject var monitor: Monitor

    private let solarColor = Color.yellow
    private let homeColor = Color.blue
    private let gridColor = Color.orange
    private let chargeColor = Color.green
    private let dischargeColor = Color.orange

    var body: some View {
        Group {
            if let state = monitor.state {
                VStack(spacing: 14) {
                    MetricCard(title: "Flux d'énergie", systemImage: "arrow.triangle.swap") {
                        EnergyFlowView(state: state, ctTotalPower: monitor.ctReport?.totalPower)
                            .frame(height: 310)
                        if let ct = monitor.ctReport {
                            Text("Soutirage réseau mesuré par le Smart CT (\(phasesText(ct))). Consommation totale de la maison = réseau + injection SolarFlow.")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                                .fixedSize(horizontal: false, vertical: true)
                        } else {
                            Text("Flux mesurés par le SolarFlow. Le soutirage direct de la maison sur le réseau public (liaison grise) n'est pas mesuré : renseignez le Smart CT dans Réglages → Réseau pour l'afficher en réel.")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    HStack(alignment: .top, spacing: 14) {
                        productionCard(state)
                        batteryCard(state)
                    }
                    HStack(alignment: .top, spacing: 14) {
                        deviceCard(state)
                        historyCard()
                    }
                }
                .padding(16)
            } else {
                VStack(spacing: 10) {
                    Image(systemName: "sun.max.trianglebadge.exclamationmark")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("Pas de données")
                        .font(.headline)
                    Text(monitor.lastError ?? "Connexion au SolarFlow en cours…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if monitor.localNetworkDenied {
                        LocalNetworkHint { monitor.restart() }
                            .frame(maxWidth: 420)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 400)
                .padding(16)
            }
        }
    }

    // MARK: - Production

    private func productionCard(_ state: DeviceState) -> some View {
        MetricCard(title: "Production solaire", systemImage: "sun.max.fill") {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text(Format.watts(state.solarInputPower))
                        .font(.system(.largeTitle, design: .rounded).weight(.semibold))
                        .monospacedDigit()
                    Spacer()
                    VStack(alignment: .trailing, spacing: 0) {
                        Text(Format.kilowattHours(monitor.energyTodayWh))
                            .font(.title3.monospacedDigit())
                        Text("aujourd'hui")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                SparklineChart(values: monitor.solarHistory, color: solarColor)
                    .frame(height: 56)
                VStack(spacing: 5) {
                    ForEach(Array(state.solarChannels.enumerated()), id: \.offset) { index, watts in
                        LegendRow(color: solarColor.opacity(0.55 + 0.15 * Double(index % 3)),
                                  label: "Entrée PV \(index + 1)",
                                  value: Format.watts(watts))
                    }
                    LegendRow(color: homeColor, label: "Vers la maison", value: Format.watts(state.outputHomePower))
                    LegendRow(color: gridColor, label: "Depuis le réseau", value: Format.watts(state.gridInputPower))
                    LegendRow(color: .green, label: "Économie du jour",
                              value: String(format: "%.2f €", monitor.energyTodayWh / 1000 * monitor.kwhPrice))
                }
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
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Batterie

    private func batteryCard(_ state: DeviceState) -> some View {
        MetricCard(title: "Batterie", systemImage: "battery.100percent") {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 16) {
                    CircularGauge(
                        segments: [GaugeSegment(value: state.electricLevel ?? 0,
                                                color: (state.electricLevel ?? 0) < 15 ? .red : chargeColor)],
                        centerText: "\(Int(state.electricLevel ?? 0)) %",
                        centerSubtext: batterySubtext(state)
                    )
                    .frame(width: 96, height: 96)

                    VStack(spacing: 5) {
                        LegendRow(color: chargeColor, label: "Charge",
                                  value: state.batteryFlow > 5 ? Format.watts(state.batteryFlow) : "—")
                        LegendRow(color: dischargeColor, label: "Décharge",
                                  value: state.batteryFlow < -5 ? Format.watts(-state.batteryFlow) : "—")
                        if let voltage = state.batteryVoltage {
                            LegendRow(color: .teal, label: "Tension", value: String(format: "%.1f V", voltage))
                        }
                        if let minutes = state.remainOutMinutes {
                            LegendRow(color: .purple, label: "Autonomie estimée", value: Format.duration(minutes: minutes))
                        }
                    }
                }
                SparklineChart(values: monitor.flowHistory,
                               color: state.batteryFlow >= 0 ? chargeColor : dischargeColor,
                               baseline: 0)
                    .frame(height: 40)
                VStack(spacing: 5) {
                    ForEach(Array(state.packs.enumerated()), id: \.element.id) { index, pack in
                        LegendRow(color: .teal, label: "Pack \(index + 1)", value: packSummary(pack))
                    }
                    if let socMin = state.socMin, let socMax = state.socMax {
                        LegendRow(color: .gray, label: "Plage SOC configurée",
                                  value: "\(Int(socMin)) % – \(Int(socMax)) %")
                    }
                }
            }
        }
    }

    // MARK: - Appareil

    private func deviceCard(_ state: DeviceState) -> some View {
        MetricCard(title: "Appareil", systemImage: "server.rack") {
            VStack(spacing: 5) {
                if let temp = state.deviceTemperature {
                    LegendRow(color: temp > 45 ? .red : .mint, label: "Température",
                              value: "\(Int(temp.rounded())) °C")
                }
                if let rssi = state.rssi {
                    LegendRow(color: wifiColor(rssi), label: "Signal WiFi",
                              value: "\(Int(rssi)) dBm")
                }
                if let mode = state.acMode {
                    LegendRow(color: .indigo, label: "Mode AC",
                              value: mode == 1 ? String(localized: "Charge (depuis le secteur)")
                                               : String(localized: "Décharge (vers la maison)"))
                }
                if let input = state.inputLimit {
                    LegendRow(color: gridColor, label: "Limite de charge", value: Format.watts(input))
                }
                if let output = state.outputLimit {
                    LegendRow(color: homeColor, label: "Limite de sortie", value: Format.watts(output))
                }
                if let sn = state.serialNumber {
                    LegendRow(color: .gray, label: "Numéro de série", value: sn)
                }
                LegendRow(color: monitor.usingFallback ? .orange : .green,
                          label: "Connexion",
                          value: monitor.usingFallback ? String(localized: "hôte de secours") : String(localized: "réseau local"))
                LegendRow(color: .gray, label: "Mise à jour",
                          value: state.updatedAt.formatted(date: .omitted, time: .standard))
            }
        }
    }

    // MARK: - Historique

    private func historyCard() -> some View {
        MetricCard(title: "Historique", systemImage: "calendar") {
            VStack(alignment: .leading, spacing: 8) {
                if monitor.dailyEnergy.count > 1 {
                    DailyBarChart(days: monitor.dailyEnergy, color: solarColor)
                        .frame(height: 110)
                    HStack {
                        Text("\(monitor.dailyEnergy.count) derniers jours")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        if monitor.historyFromServer {
                            Label("collecteur 24/7", systemImage: "externaldrive.badge.checkmark")
                                .font(.caption2)
                                .foregroundStyle(.green)
                        }
                        Spacer()
                        let total = monitor.dailyEnergy.reduce(0) { $0 + $1.wh }
                        Text("Total : \(Format.kilowattHours(total))")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.secondary)
                        if let best = monitor.dailyEnergy.max(by: { $0.wh < $1.wh }) {
                            Text("Record : \(Format.kilowattHours(best.wh))")
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                    HStack(spacing: 10) {
                        if monitor.peakTodayW > 0 {
                            Text("Pic aujourd'hui : \(Format.watts(monitor.peakTodayW))")
                        }
                        if let yesterday = monitor.yesterdayWh, yesterday > 0 {
                            let delta = Int(((monitor.energyTodayWh - yesterday) / yesterday * 100).rounded())
                            Text("vs hier : \(delta >= 0 ? "+" : "")\(delta) %")
                        }
                        Spacer()
                        let totalWh = monitor.dailyEnergy.reduce(0) { $0 + $1.wh }
                        Text(verbatim: String(format: String(localized: "≈ %.2f € · %.1f kg CO₂ évités"),
                                              totalWh / 1000 * monitor.kwhPrice,
                                              totalWh / 1000 * monitor.co2Factor / 1000))
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

    // MARK: - Helpers

    /// « ph. A 0 W · B 0 W · C 2,09 kW » — seulement les phases publiées.
    private func phasesText(_ ct: CTReport) -> String {
        guard ct.phases.count == 3 else { return Format.watts(ct.totalPower) }
        let names = ["A", "B", "C"]
        return "ph. " + zip(names, ct.phases)
            .map { "\($0) \(Format.watts($1))" }
            .joined(separator: " · ")
    }

    private func batterySubtext(_ state: DeviceState) -> String? {
        if state.batteryFlow > 5 { return String(localized: "charge") }
        if state.batteryFlow < -5 { return String(localized: "décharge") }
        return nil
    }

    private func packSummary(_ pack: PackInfo) -> String {
        var parts: [String] = []
        if let soc = pack.socLevel { parts.append("\(Int(soc)) %") }
        if let temp = pack.temperature { parts.append("\(Int(temp.rounded())) °C") }
        if let power = pack.power, abs(power) > 5 { parts.append(Format.watts(power)) }
        return parts.isEmpty ? "—" : parts.joined(separator: " · ")
    }

    private func wifiColor(_ rssi: Double) -> Color {
        if rssi >= -60 { return .green }
        if rssi >= -75 { return .orange }
        return .red
    }
}
