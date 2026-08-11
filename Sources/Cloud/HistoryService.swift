import Foundation

/// Orchestration de l'historique d'énergie : login app Zendure (identifiants
/// dans le Keychain), cache disque des jours déjà connus, récupération
/// séquentielle des jours manquants (l'API est privée et le cloud Zendure
/// fragile — on le ménage : un appel à la fois, petite pause entre deux).
///
/// Contrairement au chemin Cloud Key, ce service tient sa propre liste
/// d'appareils (celle du compte app) : l'historique fonctionne donc aussi
/// bien en mode local qu'en mode cloud.
@MainActor
final class HistoryService: ObservableObject {
    enum Phase: Equatable {
        case notConfigured          // pas d'identifiants app saisis
        case idle                   // prêt (ou terminé)
        case connecting             // login en cours
        case loading(done: Int, total: Int)
        case failed(String)
    }

    @Published private(set) var phase: Phase = .notConfigured
    /// Appareils du compte app, connus après le premier login.
    @Published private(set) var devices: [ZendureAppAPI.AppDevice] = []
    /// Jours triés par date croissante, par id d'appareil app.
    @Published private(set) var days: [String: [EnergyDay]] = [:]
    /// Totaux vie entière, par id d'appareil app.
    @Published private(set) var lifetime: [String: [String: Double]] = [:]
    /// Journal de débogage : les derniers échanges HTTP avec l'API app
    /// (mot de passe masqué), affiché dans la fenêtre Historique.
    @Published private(set) var exchanges: [ZendureAppAPI.Exchange] = []
    /// Appareils du compte sans historique d'énergie (ex. SmartMeter 3CT :
    /// l'endpoint tdengine solarFlow lui répond la structure complète mais
    /// avec toutes les valeurs à 0) — masqués de la fenêtre, et leurs
    /// 365 jours ne sont jamais demandés.
    @Published private(set) var unsupported: Set<String> = []

    private var session: ZendureAppAPI.Session?
    private var exchangeCounter = 0
    private static let exchangeLimit = 50

    static let accountKeychainKey = "appAccount"
    static let passwordKeychainKey = "appPassword"

    /// Pause entre deux appels tdengine (ns) — 365 jours ≈ 1 min de fetch,
    /// mais une seule fois grâce au cache.
    private static let throttleNanoseconds: UInt64 = 150_000_000

    init() {
        if isConfigured { phase = .idle }
    }

    var isConfigured: Bool {
        KeychainHelper.read(account: Self.accountKeychainKey) != nil
            && KeychainHelper.read(account: Self.passwordKeychainKey) != nil
    }

    func saveCredentials(account: String, password: String) {
        KeychainHelper.save(account.trimmingCharacters(in: .whitespacesAndNewlines), account: Self.accountKeychainKey)
        KeychainHelper.save(password, account: Self.passwordKeychainKey)
        session = nil
        devices = []
        phase = .idle
    }

    func forgetCredentials() {
        KeychainHelper.delete(account: Self.accountKeychainKey)
        KeychainHelper.delete(account: Self.passwordKeychainKey)
        session = nil
        devices = []
        days = [:]
        lifetime = [:]
        unsupported = []
        phase = .notConfigured
    }

    /// La base API : celle du Cloud Key si configuré (même région), sinon EU.
    private var base: URL {
        if let token = KeychainHelper.read(account: KeychainHelper.cloudKeyAccount),
           let key = try? CloudKey.decode(token) {
            return key.apiUrl
        }
        return ZendureAppAPI.defaultBase
    }

    /// Charge `rangeDays` jours d'historique pour tous les appareils du
    /// compte app. Idempotent : les jours en cache ne sont pas re-téléchargés
    /// (sauf aujourd'hui, qui évolue en cours de journée).
    func load(rangeDays: Int) async {
        guard isConfigured else {
            phase = .notConfigured
            return
        }
        if case .loading = phase { return }  // déjà en cours

        do {
            let session = try await ensureSession()
            let dates = ZendureAppAPI.dateStrings(back: rangeDays)
            guard let today = dates.last else { return }

            // Plan de travail : jours manquants (ou aujourd'hui) par appareil.
            var plan: [(device: ZendureAppAPI.AppDevice, dates: [String])] = []
            for device in devices {
                if days[device.id] == nil {
                    days[device.id] = HistoryCache.load(deviceId: device.id)
                }
                let known = Set((days[device.id] ?? []).map(\.date))
                let missing = dates.filter { !known.contains($0) || $0 == today }
                plan.append((device, missing))
            }
            guard !plan.isEmpty else {
                phase = .failed(String(localized: "Aucun appareil trouvé sur ce compte Zendure."))
                return
            }

            let total = plan.reduce(0) { $0 + $1.dates.count } + plan.count  // + totaux vie entière
            var done = 0
            phase = .loading(done: done, total: total)

            var lastDeviceError: String?
            for item in plan {
                do {
                    // Sonde d'abord les totaux vie entière : un appareil qui
                    // n'en a pas (SmartMeter…) n'a pas d'historique — inutile
                    // de lui demander 365 jours, et sa carte est masquée.
                    let totalsData = try await send(
                        ZendureAppAPI.energyRequest(session: session, device: item.device, date: nil),
                        label: String(localized: "Totaux vie entière")
                    )
                    let totals = try ZendureAppAPI.parseEnergyFields(totalsData)
                    done += 1
                    // « Aucune donnée » = totaux sans signal ET aucun jour
                    // porteur. Le SmartMeter 3CT renvoie la structure solarFlow
                    // complète avec toutes les valeurs à 0 : des champs
                    // présents mais nuls ne comptent pas — les jours en cache
                    // récoltés avant ce filtre sont purgés.
                    let meaningfulDays = (days[item.device.id] ?? []).contains { ZendureAppAPI.hasEnergySignal($0.fields) }
                    if !ZendureAppAPI.hasEnergySignal(totals), !meaningfulDays {
                        unsupported.insert(item.device.id)
                        days[item.device.id] = []
                        HistoryCache.save([], deviceId: item.device.id)
                        done += item.dates.count
                        phase = .loading(done: done, total: total)
                        continue
                    }
                    unsupported.remove(item.device.id)
                    lifetime[item.device.id] = totals
                    phase = .loading(done: done, total: total)

                    var stored = days[item.device.id] ?? []
                    for date in item.dates {
                        let data = try await send(
                            ZendureAppAPI.energyRequest(session: session, device: item.device, date: date),
                            label: String(localized: "Énergie \(date)")
                        )
                        let fields = try ZendureAppAPI.parseEnergyFields(data)
                        stored.removeAll { $0.date == date }
                        stored.append(EnergyDay(date: date, fields: fields))
                        done += 1
                        phase = .loading(done: done, total: total)
                        try? await Task.sleep(nanoseconds: Self.throttleNanoseconds)
                    }
                    stored.sort { $0.date < $1.date }
                    days[item.device.id] = stored
                    HistoryCache.save(stored, deviceId: item.device.id)
                    // Filet après coup : si même les jours fraîchement
                    // récupérés sont vides et les totaux aussi, l'appareil
                    // n'a réellement pas d'historique.
                    if !ZendureAppAPI.hasEnergySignal(lifetime[item.device.id] ?? [:]),
                       !stored.contains(where: { ZendureAppAPI.hasEnergySignal($0.fields) }) {
                        unsupported.insert(item.device.id)
                    }
                } catch {
                    // Un appareil en échec ne condamne pas les autres.
                    lastDeviceError = error.localizedDescription
                    done += item.dates.count + 1
                    phase = .loading(done: done, total: total)
                }
            }
            if let lastDeviceError {
                phase = .failed(lastDeviceError)
            } else {
                phase = .idle
            }
        } catch {
            session = nil  // jeton possiblement expiré : re-login au prochain essai
            phase = .failed(error.localizedDescription)
        }
    }

    /// Les `rangeDays` derniers jours pour un appareil, prêts à tracer.
    func range(_ rangeDays: Int, deviceId: String) -> [EnergyDay] {
        let wanted = Set(ZendureAppAPI.dateStrings(back: rangeDays))
        return (days[deviceId] ?? []).filter { wanted.contains($0.date) }
    }

    func clearDebugLog() {
        exchanges = []
    }

    // MARK: - Internes

    /// Exécute une requête en journalisant l'échange (débogage) et en
    /// transformant les statuts HTTP non-2xx en erreurs lisibles.
    private func send(_ request: URLRequest, label: String) async throws -> Data {
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            let body = String(decoding: data.prefix(4000), as: UTF8.self)
            record(label: label, request: request, status: status, responseBody: body)
            guard (200..<300).contains(status) else {
                throw ZendureAppAPI.APIError.badResponse(
                    String(localized: "\(label) : HTTP \(status) — \(String(body.prefix(300)))")
                )
            }
            return data
        } catch let error as ZendureAppAPI.APIError {
            throw error
        } catch {
            record(label: label, request: request, status: 0,
                   responseBody: String(localized: "Erreur transport : \(error.localizedDescription)"))
            throw ZendureAppAPI.APIError.badResponse(
                String(localized: "\(label) : \(error.localizedDescription)")
            )
        }
    }

    private func record(label: String, request: URLRequest, status: Int, responseBody: String) {
        exchangeCounter += 1
        exchanges.append(ZendureAppAPI.Exchange(
            id: exchangeCounter,
            date: Date(),
            label: label,
            method: request.httpMethod ?? "POST",
            url: request.url?.absoluteString ?? "?",
            status: status,
            requestBody: ZendureAppAPI.redactedBody(request.httpBody),
            responseBody: responseBody
        ))
        if exchanges.count > Self.exchangeLimit {
            exchanges.removeFirst(exchanges.count - Self.exchangeLimit)
        }
    }

    private func ensureSession() async throws -> ZendureAppAPI.Session {
        if let session { return session }
        guard let account = KeychainHelper.read(account: Self.accountKeychainKey),
              let password = KeychainHelper.read(account: Self.passwordKeychainKey) else {
            throw ZendureAppAPI.APIError.badResponse(String(localized: "Identifiants app absents du trousseau."))
        }
        phase = .connecting
        let loginData = try await send(
            ZendureAppAPI.loginRequest(base: base, account: account, password: password),
            label: String(localized: "Login")
        )
        let new = try ZendureAppAPI.parseLogin(loginData)
        session = new
        let devicesData = try await send(
            ZendureAppAPI.appDeviceListRequest(base: base, session: new),
            label: String(localized: "Liste des appareils (app)")
        )
        devices = try ZendureAppAPI.parseAppDevices(devicesData)
        return new
    }
}
