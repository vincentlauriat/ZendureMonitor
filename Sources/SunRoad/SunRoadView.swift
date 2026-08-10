import SwiftUI

/// Fenêtre « SunRoad » : la maison, les panneaux et la course du soleil en
/// vraie 3D (Phase A du plan v2.0). Reprend la localisation et les champs de
/// panneaux configurés dans la fenêtre Soleil.
struct SunRoadView: View {
    @EnvironmentObject private var monitor: Monitor
    @Environment(\.openWindow) private var openWindow
    @AppStorage("sunLatitude") private var latitude: Double = 0
    @AppStorage("sunLongitude") private var longitude: Double = 0
    @AppStorage(PanelArrayStore.key) private var arraysJSON: String = ""
    /// Météo locale (Open-Meteo) : les nuages voilent la scène.
    @StateObject private var weather = WeatherService()
    /// Timeline ±48 h : 0 = maintenant (la scène suit alors l'horloge).
    @State private var scrubHours: Double = 0
    /// Mode « mur » : l'interface s'efface, seule la scène reste.
    @State private var hudHidden = false

    /// L'heure courante, rafraîchie chaque minute (le soleil bouge d'~0,25°/min).
    @State private var now = Date()
    private let clock = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    /// Le quartier (Overpass/OSM) — cache disque d'abord, réseau sinon.
    enum NeighborhoodState: Equatable {
        case idle, loading
        case loaded(buildings: Int, roads: Int)
        case failed(String)
    }
    @State private var district: SunRoadNeighborhood = .empty
    @State private var neighborhood: NeighborhoodState = .idle

    /// Couches visibles de la scène (checkboxes du HUD, persistées).
    @AppStorage("sunroadShowBuildings") private var showBuildings = true
    @AppStorage("sunroadShowRoads") private var showRoads = true
    @AppStorage("sunroadShowArc") private var showArc = true
    @AppStorage("sunroadShowPanels") private var showPanels = true
    @AppStorage("sunroadShowCompass") private var showCompass = true
    @AppStorage("sunroadShowEnergy") private var showEnergy = true

    private var visibility: SunRoadVisibility {
        SunRoadVisibility(buildings: showBuildings, roads: showRoads,
                          arc: showArc, panels: showPanels, compass: showCompass,
                          energy: showEnergy)
    }

    /// L'instant affiché par la scène — l'horloge, décalée par la timeline.
    private var sceneDate: Date {
        scrubHours == 0 ? now : now.addingTimeInterval(scrubHours * 3600)
    }

    private var configured: Bool { latitude != 0 || longitude != 0 }
    private var arrays: [PanelArray] { PanelArrayStore.decode(arraysJSON) }

    var body: some View {
        Group {
            if configured {
                ZStack(alignment: .topLeading) {
                    SunRoadSceneView(latitude: latitude, longitude: longitude,
                                    date: sceneDate, arrays: arrays, neighborhood: district,
                                    visibility: visibility,
                                    flows: SunRoadFlows(state: monitor.state),
                                    todayCurve: monitor.todayCurve,
                                    curvePeak: max(monitor.peakTodayW, 1),
                                    showRibbon: Calendar.current.isDate(sceneDate, inSameDayAs: now),
                                    cloudCover: (weather.weather?.cloudCover ?? 0) / 100)
                        .ignoresSafeArea()
                    if hudHidden {
                        // Mode mur : un seul bouton discret pour revenir.
                        Button {
                            hudHidden = false
                        } label: {
                            Image(systemName: "eye")
                                .padding(8)
                                .background(.ultraThinMaterial, in: Circle())
                        }
                        .buttonStyle(.borderless)
                        .opacity(0.4)
                        .padding(16)
                        .help("Réafficher l'interface")
                    } else {
                        hud
                    }
                }
                .overlay(alignment: .bottom) {
                    if !hudHidden { timelineBar }
                }
                .task(id: "\(latitude),\(longitude)") {
                    weather.refresh(latitude: latitude, longitude: longitude)
                    await loadNeighborhood(force: false)
                }
            } else {
                notConfigured
            }
        }
        .frame(minWidth: 700, minHeight: 500)
        .onReceive(clock) { now = $0 }
        .onAppear { WindowPolicy.retain() }
        .onDisappear { WindowPolicy.release() }
    }

    // MARK: - HUD

    private var hud: some View {
        let sun = SunCalc.compute(at: sceneDate, latitude: latitude, longitude: longitude)
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(sceneDate, format: .dateTime.weekday(.wide).day().month(.wide).hour().minute())
                    .font(.headline)
                Spacer(minLength: 20)
                Button {
                    hudHidden = true
                } label: {
                    Image(systemName: "eye.slash")
                }
                .buttonStyle(.borderless)
                .help("Mode mur : masquer l'interface, ne garder que la scène")
            }
            HStack(spacing: 14) {
                Label(String(format: "%.1f°", sun.elevation), systemImage: "arrow.up.to.line")
                    .help("Élévation du soleil")
                Label(String(format: "%.0f°", sun.azimuth), systemImage: "safari")
                    .help("Azimut (0° = nord)")
                if let sunrise = sun.sunrise, let sunset = sun.sunset {
                    Label {
                        Text("\(sunrise, format: .dateTime.hour().minute()) – \(sunset, format: .dateTime.hour().minute())")
                    } icon: {
                        Image(systemName: "sunrise")
                    }
                    .help("Lever et coucher")
                }
            }
            .font(.callout.monospacedDigit())
            energyRow
            neighborhoodRow
            visibilityRow
            Text("Glisser pour orbiter · molette pour zoomer")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .padding(16)
    }

    /// État du quartier OSM + rechargement forcé (les bâtiments ne bougent
    /// pas : le cache disque suffit en temps normal).
    private var neighborhoodRow: some View {
        HStack(spacing: 8) {
            switch neighborhood {
            case .idle:
                EmptyView()
            case .loading:
                ProgressView().controlSize(.mini)
                Text("Chargement du quartier (OpenStreetMap)…")
            case .loaded(let buildings, let roads):
                Image(systemName: "building.2")
                Text("\(buildings) bâtiment(s) · \(roads) route(s)")
            case .failed(let message):
                Image(systemName: "wifi.exclamationmark")
                    .foregroundStyle(.orange)
                Text("Quartier indisponible : \(message)")
                    .lineLimit(1)
            }
            Button {
                Task { await loadNeighborhood(force: true) }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .help("Recharger le quartier depuis OpenStreetMap")
            .disabled(neighborhood == .loading)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    /// Les couches affichables de la scène, à cocher/décocher.
    private var visibilityRow: some View {
        HStack(spacing: 10) {
            Toggle("Bâtiments", isOn: $showBuildings)
            Toggle("Routes", isOn: $showRoads)
            Toggle("Arc du soleil", isOn: $showArc)
            Toggle("Panneaux", isOn: $showPanels)
            Toggle("Boussole", isOn: $showCompass)
            Toggle("Énergie", isOn: $showEnergy)
        }
        .toggleStyle(.checkbox)
        .controlSize(.small)
        .font(.caption)
    }

    /// Les watts en direct qui animent les billes — et la météo qui voile la
    /// scène. Absent tant que le SolarFlow n'a pas répondu.
    @ViewBuilder
    private var energyRow: some View {
        if let state = monitor.state {
            HStack(spacing: 14) {
                Label(Format.watts(state.solarInputPower), systemImage: "sun.max.fill")
                    .help("Production solaire en direct")
                Label(Format.watts(state.outputHomePower), systemImage: "house")
                    .help("Vers la maison")
                if let soc = state.electricLevel {
                    Label("\(Int(soc)) %", systemImage: "battery.100percent")
                        .help("Batterie")
                }
                if let w = weather.weather {
                    Label("\(Int(w.cloudCover)) %", systemImage: "cloud")
                        .help("Couverture nuageuse (voile la lumière de la scène)")
                }
            }
            .font(.caption.monospacedDigit())
        }
    }

    /// Timeline ±48 h : le soleil, les ombres et le ciel suivent le curseur.
    private var timelineBar: some View {
        VStack(spacing: 4) {
            HStack(spacing: 10) {
                Image(systemName: "clock")
                    .foregroundStyle(.secondary)
                Text(sceneDate, format: .dateTime.weekday(.abbreviated).day().hour().minute())
                    .font(.caption.monospacedDigit().weight(scrubHours == 0 ? .regular : .semibold))
                if scrubHours != 0 {
                    Button("Maintenant") { scrubHours = 0 }
                        .controlSize(.small)
                }
            }
            Slider(value: $scrubHours, in: -48...48, step: 0.25) {
                EmptyView()
            } minimumValueLabel: {
                Text("-48 h").font(.caption2).foregroundStyle(.secondary)
            } maximumValueLabel: {
                Text("+48 h").font(.caption2).foregroundStyle(.secondary)
            }
            .frame(maxWidth: 520)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .padding(.bottom, 14)
    }

    private func loadNeighborhood(force: Bool) async {
        guard configured else { return }
        neighborhood = .loading
        do {
            let result = try await OverpassService.neighborhood(latitude: latitude,
                                                                longitude: longitude,
                                                                force: force)
            district = result
            neighborhood = .loaded(buildings: result.buildings.count, roads: result.roads.count)
        } catch {
            // La scène reste utilisable avec la maison placeholder.
            neighborhood = .failed(error.localizedDescription)
        }
    }

    private var notConfigured: some View {
        VStack(spacing: 14) {
            Image(systemName: "cube.transparent")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text("SunRoad a besoin de la position de la maison")
                .font(.headline)
            Text("Renseigne la latitude et la longitude dans la fenêtre Soleil — SunRoad réutilise la même localisation et les mêmes champs de panneaux.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
            Button("Ouvrir la fenêtre Soleil") {
                openWindow(id: "sun")
            }
        }
        .padding(40)
    }
}
