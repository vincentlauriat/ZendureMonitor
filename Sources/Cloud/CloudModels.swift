import Foundation

/// Entrée de la liste d'appareils renvoyée par `POST {apiUrl}/api/ha/deviceList`.
struct ZendureDevice: Identifiable, Equatable, Decodable {
    let deviceKey: String
    let productKey: String
    let productModel: String?
    let deviceName: String?
    let snNumber: String?
    let ip: String?

    var id: String { deviceKey }

    /// Nom affichable : nom donné par l'utilisateur, sinon modèle, sinon clé.
    var displayName: String {
        if let deviceName, !deviceName.isEmpty { return deviceName }
        if let productModel, !productModel.isEmpty { return productModel }
        return deviceKey
    }
}

/// Credentials MQTT renvoyés par deviceList (`data.mqtt`).
struct MQTTCredentials: Equatable, Decodable {
    let clientId: String
    let url: String
    let username: String
    let password: String

    /// `url` est `host` ou `host:port` — découper sur le DERNIER `:`,
    /// port 1883 par défaut.
    var host: String {
        guard let idx = url.lastIndex(of: ":"), Int(url[url.index(after: idx)...]) != nil else { return url }
        return String(url[url.startIndex..<idx])
    }

    var port: UInt16 {
        guard let idx = url.lastIndex(of: ":"),
              let p = UInt16(url[url.index(after: idx)...]) else { return 1883 }
        return p
    }
}

/// Enveloppe de réponse de l'API HA.
struct DeviceListResponse: Decodable {
    struct Payload: Decodable {
        let deviceList: [ZendureDevice]?
        let mqtt: MQTTCredentials?
    }

    let code: Int?
    let success: Bool?
    let msg: String?
    let data: Payload?
}
