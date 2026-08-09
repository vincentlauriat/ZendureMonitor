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
    /// True après la fin d'un scan (permet d'afficher « aucun appareil trouvé »).
    @Published var hasSearched = false

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
        if isSearching { hasSearched = true }
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
        // Préférer l'adresse IPv4 résolue au nom d'hôte : la résolution
        // getaddrinfo des noms `.local` peut prendre ~5 s (requête AAAA
        // muette sur certains réseaux) — au-delà du timeout de 5 s de l'app,
        // un hôte détecté par son nom était ensuite inutilisable.
        var host = Self.ipv4Address(from: sender.addresses)
        if host == nil, var name = sender.hostName {
            if name.hasSuffix(".") { name.removeLast() }
            host = name
        }
        guard let host else { return }
        let found = Found(name: sender.name, host: host)
        DispatchQueue.main.async { [weak self] in
            guard let self, !self.devices.contains(where: { $0.name == found.name }) else { return }
            self.devices.append(found)
        }
    }

    /// Première adresse IPv4 d'une liste de `sockaddr` bruts (Bonjour).
    static func ipv4Address(from addresses: [Data]?) -> String? {
        for data in addresses ?? [] {
            let ip: String? = data.withUnsafeBytes { raw -> String? in
                guard let base = raw.baseAddress,
                      raw.count >= MemoryLayout<sockaddr_in>.size else { return nil }
                let family = base.assumingMemoryBound(to: sockaddr.self).pointee.sa_family
                guard family == sa_family_t(AF_INET) else { return nil }
                var addr = base.assumingMemoryBound(to: sockaddr_in.self).pointee.sin_addr
                var buffer = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
                guard inet_ntop(AF_INET, &addr, &buffer, socklen_t(INET_ADDRSTRLEN)) != nil else { return nil }
                return String(cString: buffer)
            }
            if let ip { return ip }
        }
        return nil
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didNotSearch errorDict: [String: NSNumber]) {
        DispatchQueue.main.async { [weak self] in self?.isSearching = false }
    }
}
