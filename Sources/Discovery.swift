import Foundation

/// Bonjour discovery of Zendure devices, resolving each service to its
/// `.local` hostname so it can be used directly over HTTP.
///
/// The zenSDK docs announce `_zendure._tcp`, but the SolarFlow 2400 Pro
/// firmware actually advertises under `_http._tcp` with an instance name of
/// `Zendure-<model>-<sn>` — so both types are browsed, and `_http._tcp`
/// results are kept only when the name starts with "Zendure".
/// NetService is deprecated but remains the simplest way to get a hostname.
final class DeviceDiscovery: NSObject, ObservableObject {
    struct Found: Identifiable, Equatable {
        var id: String { name }
        let name: String
        let host: String
    }

    @Published var devices: [Found] = []
    @Published var isSearching = false

    private var browsers: [NetServiceBrowser] = []
    private var pending: [NetService] = []

    func start() {
        stop()
        devices = []
        isSearching = true
        for type in ["_zendure._tcp.", "_http._tcp."] {
            let browser = NetServiceBrowser()
            browser.delegate = self
            browser.searchForServices(ofType: type, inDomain: "local.")
            browsers.append(browser)
        }
        // Bonjour browsing never "finishes"; give it a bounded window.
        DispatchQueue.main.asyncAfter(deadline: .now() + 8) { [weak self] in
            self?.stop()
        }
    }

    func stop() {
        browsers.forEach { $0.stop() }
        browsers = []
        pending = []
        isSearching = false
    }
}

extension DeviceDiscovery: NetServiceBrowserDelegate, NetServiceDelegate {
    func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        guard service.name.lowercased().hasPrefix("zendure") || service.type.hasPrefix("_zendure") else { return }
        pending.append(service)
        service.delegate = self
        service.resolve(withTimeout: 5)
    }

    func netServiceDidResolveAddress(_ sender: NetService) {
        guard var host = sender.hostName else { return }
        if host.hasSuffix(".") { host.removeLast() }
        let found = Found(name: sender.name, host: host)
        DispatchQueue.main.async { [weak self] in
            guard let self, !self.devices.contains(where: { $0.name == found.name }) else { return }
            self.devices.append(found)
        }
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didNotSearch errorDict: [String: NSNumber]) {
        DispatchQueue.main.async { [weak self] in self?.isSearching = false }
    }
}
