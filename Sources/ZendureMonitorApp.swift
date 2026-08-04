import SwiftUI

@main
struct ZendureMonitorApp: App {
    @StateObject private var monitor = Monitor()

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
    }
}

struct MenuBarLabel: View {
    @ObservedObject var monitor: Monitor

    var body: some View {
        if let state = monitor.state {
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
