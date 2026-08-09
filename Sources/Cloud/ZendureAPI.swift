import Foundation
import CryptoKit

/// Client HTTP de l'API « HA » du Cloud Zendure — un seul endpoint utile :
/// `POST {apiUrl}/api/ha/deviceList`, signé SHA1.
enum ZendureAPI {
    /// Clé de signature constante, identique dans l'intégration Home Assistant
    /// officielle de Zendure et l'adaptateur ioBroker.
    private static let signSecret = "C*dafwArEOXK"

    enum APIError: LocalizedError {
        case badHTTPStatus(Int)
        case apiRejected(code: Int?, message: String?)
        case emptyDeviceList
        case missingMQTT
        case malformedResponse

        var errorDescription: String? {
            switch self {
            case .badHTTPStatus(let s):
                return String(localized: "Le serveur Zendure a répondu HTTP \(s).")
            case .apiRejected(let code, let msg):
                let codeText = code.map(String.init) ?? "?"
                let detail = msg.map { " : \($0)" } ?? ""
                return String(localized: "L'API Zendure a refusé la requête (code \(codeText)\(detail)).")
            case .emptyDeviceList:
                return String(localized: "Aucun appareil sur ce compte — le jeton doit venir du compte principal Zendure.")
            case .missingMQTT:
                return String(localized: "Réponse sans identifiants MQTT — temps réel indisponible.")
            case .malformedResponse:
                return String(localized: "Réponse illisible du serveur Zendure.")
            }
        }
    }

    /// Signature : paramètres triés par clé croissante, concaténés `clé+valeur`
    /// sans séparateur, encadrés par la clé secrète, SHA1 hex MAJUSCULES.
    static func sign(parameters: [String: String]) -> String {
        let body = parameters.keys.sorted().map { "\($0)\(parameters[$0]!)" }.joined()
        let digest = Insecure.SHA1.hash(data: Data((signSecret + body + signSecret).utf8))
        return digest.map { String(format: "%02X", $0) }.joined()
    }

    /// Construit la requête signée deviceList — séparé de l'appel réseau pour
    /// être testable sans serveur.
    static func deviceListRequest(cloudKey: CloudKey, now: Date = Date(), nonce: Int = Int.random(in: 10000...99999)) -> URLRequest {
        let timestamp = String(Int(now.timeIntervalSince1970))
        let nonceString = String(nonce)
        let parameters = [
            "appKey": cloudKey.appKey,
            "nonce": nonceString,
            "timestamp": timestamp,
        ]

        var request = URLRequest(url: cloudKey.apiUrl.appendingPathComponent("api/ha/deviceList"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(timestamp, forHTTPHeaderField: "timestamp")
        request.setValue(nonceString, forHTTPHeaderField: "nonce")
        request.setValue("zenHa", forHTTPHeaderField: "clientid")
        request.setValue(sign(parameters: parameters), forHTTPHeaderField: "sign")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["appKey": cloudKey.appKey])
        request.timeoutInterval = 15
        return request
    }

    /// Appelle deviceList et retourne appareils + credentials MQTT.
    /// Les causes d'échec restent distinctes (diagnostic utilisateur).
    static func fetchDeviceList(cloudKey: CloudKey) async throws -> (devices: [ZendureDevice], mqtt: MQTTCredentials) {
        let (data, response) = try await URLSession.shared.data(for: deviceListRequest(cloudKey: cloudKey))
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw APIError.badHTTPStatus(http.statusCode)
        }
        guard let decoded = try? JSONDecoder().decode(DeviceListResponse.self, from: data) else {
            throw APIError.malformedResponse
        }
        guard decoded.code == 200, decoded.success == true, let payload = decoded.data else {
            throw APIError.apiRejected(code: decoded.code, message: decoded.msg)
        }
        guard let devices = payload.deviceList, !devices.isEmpty else {
            throw APIError.emptyDeviceList
        }
        guard let mqtt = payload.mqtt else {
            throw APIError.missingMQTT
        }
        return (devices, mqtt)
    }
}
