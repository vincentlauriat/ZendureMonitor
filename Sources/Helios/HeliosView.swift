import SwiftUI

/// Fenêtre « Hélios » : la maison, les panneaux et la course du soleil en
/// vraie 3D (Phase A du plan v2.0). Reprend la localisation et les champs de
/// panneaux configurés dans la fenêtre Soleil.
struct HeliosView: View {
    @Environment(\.openWindow) private var openWindow
    @AppStorage("sunLatitude") private var latitude: Double = 0
    @AppStorage("sunLongitude") private var longitude: Double = 0
    @AppStorage(PanelArrayStore.key) private var arraysJSON: String = ""

    /// L'heure courante, rafraîchie chaque minute (le soleil bouge d'~0,25°/min).
    @State private var now = Date()
    private let clock = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    private var configured: Bool { latitude != 0 || longitude != 0 }
    private var arrays: [PanelArray] { PanelArrayStore.decode(arraysJSON) }

    var body: some View {
        Group {
            if configured {
                ZStack(alignment: .topLeading) {
                    HeliosSceneView(latitude: latitude, longitude: longitude,
                                    date: now, arrays: arrays)
                        .ignoresSafeArea()
                    hud
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
        let sun = SunCalc.compute(at: now, latitude: latitude, longitude: longitude)
        return VStack(alignment: .leading, spacing: 6) {
            Text(now, format: .dateTime.weekday(.wide).day().month(.wide).hour().minute())
                .font(.headline)
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
            Text("Glisser pour orbiter · molette pour zoomer")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .padding(16)
    }

    private var notConfigured: some View {
        VStack(spacing: 14) {
            Image(systemName: "cube.transparent")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text("Hélios a besoin de la position de la maison")
                .font(.headline)
            Text("Renseigne la latitude et la longitude dans la fenêtre Soleil — Hélios réutilise la même localisation et les mêmes champs de panneaux.")
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
