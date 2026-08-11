import Foundation

/// Client de l'API PRIVÉE de l'app mobile Zendure — la seule voie connue vers
/// l'historique d'énergie (endpoints tdengine). Totalement isolée du chemin
/// Cloud Key (`ZendureAPI`) : auth différente (email/mot de passe → jeton
/// Blade-Auth), base différente (`serverNodeUrl` renvoyé par le login).
///
/// Protocole relevé dans le module FHEM RP-Develop/Zendure et
/// solarflow-statuspage — API non contractuelle. Les constructeurs de
/// requêtes sont `static` et purs pour être testables sans réseau.
/// Module porté depuis l'app exploratoire ZendureCloud.
enum ZendureAppAPI {
    struct Session: Equatable {
        let accessToken: String
        let serverNodeUrl: URL
    }

    /// Appareil tel que renvoyé par `queryDeviceListByConsumerId` — son `id`
    /// (distinct du deviceKey !) est la clé des appels d'historique.
    struct AppDevice: Equatable, Identifiable {
        let id: String
        let idIsNumeric: Bool
        let snNumber: String?
        let name: String?

        var displayName: String {
            if let name, !name.isEmpty { return name }
            if let snNumber, !snNumber.isEmpty { return snNumber }
            return id
        }
    }

    enum APIError: LocalizedError {
        case badResponse(String)

        var errorDescription: String? {
            switch self {
            case .badResponse(let message): message
            }
        }
    }

    /// Un échange HTTP avec l'API app, pour la section Débogage de la fenêtre
    /// Historique — le mot de passe est masqué avant enregistrement.
    struct Exchange: Identifiable, Equatable {
        let id: Int
        let date: Date
        let label: String
        let method: String
        let url: String
        /// 0 = pas de réponse (erreur transport).
        let status: Int
        let requestBody: String
        let responseBody: String
    }

    /// Corps de requête affichable : JSON re-sérialisé avec les champs
    /// sensibles remplacés par « ••• ».
    static func redactedBody(_ body: Data?) -> String {
        guard let body else { return "" }
        guard var object = (try? JSONSerialization.jsonObject(with: body)) as? [String: Any] else {
            return String(decoding: body.prefix(500), as: UTF8.self)
        }
        for key in ["password", "accessToken"] where object[key] != nil {
            object[key] = "•••"
        }
        guard let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]) else {
            return ""
        }
        return String(decoding: data, as: UTF8.self)
    }

    static let defaultBase = URL(string: "https://app.zendure.tech/eu")!

    /// En-têtes imitant l'app iOS (relevés dans FHEM/solarflow-statuspage).
    /// Avant login : Authorization Basic constante ; après : Blade-Auth.
    static func headers(accessToken: String?) -> [String: String] {
        var headers = [
            "Content-Type": "application/json",
            "Accept": "*/*",
            "Accept-Language": "fr-FR",
            "appVersion": "4.3.1",
            "User-Agent": "Zendure/4.3.1 (iPhone; iOS 14.4.2; Scale/3.00)",
        ]
        if let accessToken {
            headers["Blade-Auth"] = "bearer \(accessToken)"
        } else {
            // Avant login, l'app envoie ce couple exact (relevé dans
            // solarflow-statuspage) — y compris le « bearer (null) ».
            headers["Authorization"] = "Basic Q29uc3VtZXJBcHA6NX4qUmRuTnJATWg0WjEyMw=="
            headers["Blade-Auth"] = "bearer (null)"
        }
        return headers
    }

    // MARK: - Login

    static func loginRequest(base: URL, account: String, password: String) -> URLRequest {
        var request = URLRequest(url: base.appending(path: "auth/app/token"))
        request.httpMethod = "POST"
        for (key, value) in headers(accessToken: nil) {
            request.setValue(value, forHTTPHeaderField: key)
        }
        let body: [String: Any] = [
            "password": password,
            "account": account,
            "appId": "121c83f761305d6cf7e",
            "appType": "iOS",
            "grantType": "password",
            "tenantId": "",
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        return request
    }

    static func parseLogin(_ data: Data) throws -> Session {
        let root = try rootObject(data)
        guard let payload = root["data"] as? [String: Any],
              let token = payload["accessToken"] as? String, !token.isEmpty,
              let nodeRaw = payload["serverNodeUrl"] as? String, !nodeRaw.isEmpty
        else {
            throw APIError.badResponse(String(localized: "Réponse de login sans accessToken/serverNodeUrl."))
        }
        let normalized = nodeRaw.hasPrefix("http") ? nodeRaw : "https://\(nodeRaw)"
        guard let node = URL(string: normalized) else {
            throw APIError.badResponse(String(localized: "serverNodeUrl invalide : \(nodeRaw)"))
        }
        return Session(accessToken: token, serverNodeUrl: node)
    }

    // MARK: - Liste des appareils côté app (pour obtenir les `id`)

    static func appDeviceListRequest(base: URL, session: Session) -> URLRequest {
        var request = URLRequest(url: base.appending(path: "productModule/device/queryDeviceListByConsumerId"))
        request.httpMethod = "POST"
        for (key, value) in headers(accessToken: session.accessToken) {
            request.setValue(value, forHTTPHeaderField: key)
        }
        request.httpBody = Data("{}".utf8)
        return request
    }

    static func parseAppDevices(_ data: Data) throws -> [AppDevice] {
        let root = try rootObject(data)
        guard let list = root["data"] as? [[String: Any]] else {
            throw APIError.badResponse(String(localized: "Réponse deviceList sans tableau data."))
        }
        return list.compactMap { entry in
            guard let rawId = entry["id"] else { return nil }
            let isNumeric = rawId is Int || rawId is NSNumber
            return AppDevice(
                id: describe(rawId),
                idIsNumeric: isNumeric,
                snNumber: entry["snNumber"] as? String,
                name: entry["name"] as? String ?? entry["deviceName"] as? String
            )
        }
    }

    // MARK: - Historique tdengine

    /// `date == nil` → totaux vie entière (`type` chaîne vide, dates vides),
    /// sinon données du jour donné (`type` 0, beginDate = endDate = date) —
    /// les deux seuls modes validés en production (FHEM).
    static func energyRequest(session: Session, device: AppDevice, date: String?,
                              endpoint: String = "energy",
                              zone: String = TimeZone.current.identifier) -> URLRequest {
        var request = URLRequest(url: session.serverNodeUrl.appending(path: "tdengine/device/solarFlow/\(endpoint)"))
        request.httpMethod = "POST"
        for (key, value) in headers(accessToken: session.accessToken) {
            request.setValue(value, forHTTPHeaderField: key)
        }
        let idValue: Any
        if device.idIsNumeric, let numeric = Int(device.id) {
            idValue = numeric
        } else {
            idValue = device.id
        }
        let body: [String: Any] = [
            "aceId": "",
            "deviceId": idValue,
            "beginDate": date ?? "",
            "endDate": date ?? "",
            "zone": zone,
            "type": date == nil ? "" : 0,
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        return request
    }

    /// Extrait les champs numériques de `data` (les tableaux `energyVos` et
    /// `data` — séries des graphiques — sont ignorés à ce stade).
    static func parseEnergyFields(_ data: Data) throws -> [String: Double] {
        let root = try rootObject(data)
        guard let payload = root["data"] as? [String: Any] else {
            throw APIError.badResponse(String(localized: "Réponse énergie sans objet data."))
        }
        var fields: [String: Double] = [:]
        for (key, value) in payload where !(value is [Any]) && !(value is [String: Any]) {
            if let number = CloudDeviceState.number(value) {
                fields[key] = number
            }
        }
        return fields
    }

    /// Clés méta renvoyées même par un appareil sans historique — le
    /// SmartMeter 3CT reçoit de tdengine la structure solarFlow complète,
    /// toutes valeurs à 0.
    static let energyMetaKeys: Set<String> = ["type", "productType"]

    /// Vrai si les champs portent un signal réel : au moins une valeur non
    /// nulle hors clés méta. Des champs présents mais tous à zéro (SmartMeter
    /// 3CT) ne comptent pas comme de l'historique.
    static func hasEnergySignal(_ fields: [String: Double]) -> Bool {
        fields.contains { !energyMetaKeys.contains($0.key) && $0.value != 0 }
    }

    // MARK: - Helpers

    /// `id` d'appareil re-présentable en String, qu'il arrive en nombre ou en
    /// chaîne dans le JSON (les deux formes ont été observées).
    static func describe(_ value: Any) -> String {
        if let string = value as? String { return string }
        if let number = value as? NSNumber { return number.stringValue }
        return String(describing: value)
    }

    private static func rootObject(_ data: Data) throws -> [String: Any] {
        guard let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            throw APIError.badResponse(String(localized: "Réponse illisible (JSON attendu)."))
        }
        let success = root["success"] as? Bool ?? false
        let code = (root["code"] as? Int) ?? (root["code"] as? NSNumber)?.intValue ?? 0
        guard success || code == 200 else {
            let message = root["msg"] as? String ?? "code \(code)"
            throw APIError.badResponse(String(localized: "L'API Zendure a refusé la requête : \(message)"))
        }
        return root
    }

    /// Les `count` derniers jours (aujourd'hui inclus), du plus ancien au plus
    /// récent, au format yyyy-MM-dd.
    static func dateStrings(back count: Int, from reference: Date = Date(),
                            calendar: Calendar = .current) -> [String] {
        guard count > 0 else { return [] }
        return (0..<count).reversed().compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: reference) else { return nil }
            return EnergyDay.formatter.string(from: day)
        }
    }
}
