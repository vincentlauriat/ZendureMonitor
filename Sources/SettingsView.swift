import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var monitor: Monitor
    @StateObject private var discovery = DeviceDiscovery()
    @State private var testResult: String?
    @State private var testOK = false
    @State private var testing = false

    var body: some View {
        Form {
            Section("Appareil SolarFlow") {
                TextField("Adresse IP ou nom d'hôte", text: $monitor.host, prompt: Text("192.168.1.xx ou Zendure-….local"))
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()

                HStack {
                    Button(discovery.isSearching ? "Recherche…" : "Rechercher sur le réseau") {
                        discovery.start()
                    }
                    .disabled(discovery.isSearching)

                    Button(testing ? "Test…" : "Tester la connexion") {
                        runTest()
                    }
                    .disabled(testing || monitor.host.isEmpty)
                }

                if let testResult {
                    Label(testResult, systemImage: testOK ? "checkmark.circle" : "xmark.circle")
                        .foregroundStyle(testOK ? .green : .red)
                        .font(.callout)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if !discovery.devices.isEmpty {
                    ForEach(discovery.devices) { device in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(device.name).font(.callout)
                                Text(device.host).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Utiliser") { monitor.host = device.host }
                        }
                    }
                } else if !discovery.isSearching, discovery.devices.isEmpty {
                    Text("Astuce : l'API locale s'active dans l'app Zendure (ajouter un HEMS puis quitter). Le device apparaît alors en Bonjour (_zendure._tcp).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Section("Rafraîchissement") {
                Slider(value: $monitor.pollInterval, in: 2...60, step: 1) {
                    Text("Intervalle")
                } minimumValueLabel: {
                    Text("2 s")
                } maximumValueLabel: {
                    Text("60 s")
                }
                Text("Toutes les \(Int(monitor.pollInterval)) secondes")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 420)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func runTest() {
        testing = true
        testResult = nil
        let host = monitor.host
        Task {
            let result = await monitor.test(host: host)
            switch result {
            case .success(let state):
                testOK = true
                var parts = ["Connecté", Format.watts(state.solarInputPower) + " solaire"]
                if let soc = state.electricLevel { parts.append("\(Int(soc)) % batterie") }
                if let sn = state.serialNumber { parts.append("SN \(sn)") }
                testResult = parts.joined(separator: " — ")
            case .failure(let error):
                testOK = false
                testResult = error.localizedDescription
            }
            testing = false
        }
    }
}
