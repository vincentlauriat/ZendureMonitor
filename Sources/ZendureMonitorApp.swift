import SwiftUI

@main
struct ZendureMonitorApp: App {
    @StateObject private var monitor = Monitor()
    @StateObject private var history = HistoryService()

    var body: some Scene {
        MenuBarExtra {
            MenuView()
                .environmentObject(monitor)
        } label: {
            MenuBarLabel(monitor: monitor)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(monitor)
        }

        Window("Tableau de bord", id: "dashboard") {
            DashboardView()
                .environmentObject(monitor)
        }
        .defaultSize(width: 820, height: 720)

        Window("Soleil", id: "sun") {
            SunView()
                .environmentObject(monitor)
        }
        // Dimensionnée pour que la fenêtre tienne en entier sans défilement sur
        // un portable 13" (1710×1026 points utiles).
        .defaultSize(width: 1400, height: 980)

        Window("Historique", id: "history") {
            HistoryView()
                .environmentObject(history)
        }
        .defaultSize(width: 820, height: 720)

        Window("SunRoad", id: "sunroad") {
            SunRoadView()
        }
        .defaultSize(width: 1100, height: 760)
    }
}

/// L'app est LSUIElement : tant qu'au moins une fenêtre (tableau de bord,
/// Soleil…) est ouverte, elle doit apparaître dans le Dock et Cmd-Tab.
/// Compteur partagé pour ne repasser en .accessory qu'à la dernière fermeture.
@MainActor
enum WindowPolicy {
    private static var openWindows = 0

    static func retain() {
        openWindows += 1
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    static func release() {
        openWindows = max(0, openWindows - 1)
        if openWindows == 0 {
            NSApp.setActivationPolicy(.accessory)
        }
    }
}

struct MenuBarLabel: View {
    @ObservedObject var monitor: Monitor

    var body: some View {
        if monitor.offlineAlert {
            // Appareil injoignable au-delà du seuil : état d'alerte franc,
            // plus visible que le simple grisage du panneau.
            let image = Image(systemName: "exclamationmark.triangle.fill")
            Text("\(image) \(String(localized: "hors ligne"))")
        } else if let state = monitor.state {
            let image = Image(systemName: state.solarInputPower > 0 ? "sun.max.fill" : "sun.min")
            let text = segments(state).joined(separator: "  ")
            Text(text.isEmpty ? "\(image)" : "\(image) \(text)")
        } else {
            let image = Image(systemName: "sun.max.trianglebadge.exclamationmark")
            Text("\(image) — W")
        }
    }

    /// Menu bar segments per the visibility settings ("Barre de menu" section).
    private func segments(_ state: DeviceState) -> [String] {
        var parts: [String] = []
        if monitor.showSolarInBar {
            parts.append(Format.wattsCompact(state.solarInputPower))
        }
        if monitor.showBatteryInBar, let soc = state.electricLevel {
            parts.append("\(Int(soc)) %")
        }
        if monitor.showHomeInBar {
            parts.append("⌂ \(Format.wattsCompact(state.outputHomePower))")
        }
        return parts
    }
}
