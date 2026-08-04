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
    }
}

struct MenuBarLabel: View {
    @ObservedObject var monitor: Monitor

    var body: some View {
        if let state = monitor.state {
            let image = Image(systemName: state.solarInputPower > 0 ? "sun.max.fill" : "sun.min")
            Text("\(image) \(Format.wattsCompact(state.solarInputPower))")
        } else {
            let image = Image(systemName: "sun.max.trianglebadge.exclamationmark")
            Text("\(image) — W")
        }
    }
}
