#!/usr/bin/env swift
// Sonde du cloud Zendure : liste les appareils du compte puis écoute le flux
// MQTT et affiche TOUS les topics et TOUTES les clés JSON reçues — l'outil
// pour découvrir ce que le cloud publie réellement (ex. données du Smart CT :
// consommation globale maison, soutirage réseau), au-delà des champs mappés
// par l'app.
//
// Usage :   swift Scripts/cloud-probe.swift "<Authorization Cloud Key>" [durée-s]
// La clé se copie depuis l'app Zendure (Profil → Authorization Cloud Key,
// compte principal). Durée d'écoute par défaut : 120 s.

import CryptoKit
import Foundation
import Network

guard CommandLine.arguments.count >= 2 else {
    print("Usage: swift Scripts/cloud-probe.swift \"<cloud key>\" [durée-s]")
    exit(1)
}
let token = CommandLine.arguments[1]
let listenSeconds = CommandLine.arguments.count >= 3 ? Int(CommandLine.arguments[2]) ?? 120 : 120

// MARK: - Décodage du Cloud Key (base64 → "<apiUrl>.<appKey>", dernier point)

let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
let padded = trimmed.padding(toLength: ((trimmed.count + 3) / 4) * 4, withPad: "=", startingAt: 0)
guard let keyData = Data(base64Encoded: padded),
      let decoded = String(data: keyData, encoding: .utf8),
      let lastDot = decoded.lastIndex(of: "."), lastDot != decoded.startIndex else {
    print("❌ Cloud Key illisible (base64 attendu, forme <url>.<appKey>)")
    exit(1)
}
let apiUrlString = String(decoded[decoded.startIndex..<lastDot])
let appKey = String(decoded[decoded.index(after: lastDot)...])
guard let apiUrl = URL(string: apiUrlString), apiUrl.scheme?.hasPrefix("http") == true, !appKey.isEmpty else {
    print("❌ Forme décodée inattendue : \(decoded)")
    exit(1)
}
print("→ API \(apiUrlString), appKey \(String(appKey.prefix(4)))…")

// MARK: - deviceList signé SHA1

let timestamp = String(Int(Date().timeIntervalSince1970))
let nonce = String(Int.random(in: 10000...99999))
let signSecret = "C*dafwArEOXK"
let sorted = ["appKey": appKey, "nonce": nonce, "timestamp": timestamp]
    .sorted { $0.key < $1.key }.map { $0.key + $0.value }.joined()
let sign = Insecure.SHA1.hash(data: Data((signSecret + sorted + signSecret).utf8))
    .map { String(format: "%02X", $0) }.joined()

var request = URLRequest(url: apiUrl.appendingPathComponent("api/ha/deviceList"))
request.httpMethod = "POST"
request.setValue("application/json", forHTTPHeaderField: "Content-Type")
request.setValue(timestamp, forHTTPHeaderField: "timestamp")
request.setValue(nonce, forHTTPHeaderField: "nonce")
request.setValue("zenHa", forHTTPHeaderField: "clientid")
request.setValue(sign, forHTTPHeaderField: "sign")
request.httpBody = try? JSONSerialization.data(withJSONObject: ["appKey": appKey])
request.timeoutInterval = 15

struct Device: Decodable { let deviceKey: String; let productKey: String
    let productModel: String?; let deviceName: String?; let snNumber: String? }
struct MQTTInfo: Decodable { let clientId: String; let url: String; let username: String; let password: String }
struct Payload: Decodable { let deviceList: [Device]?; let mqtt: MQTTInfo? }
struct Envelope: Decodable { let code: Int?; let success: Bool?; let msg: String?; let data: Payload? }

let httpDone = DispatchSemaphore(value: 0)
var devices: [Device] = []
var mqttInfo: MQTTInfo?
URLSession.shared.dataTask(with: request) { data, response, error in
    defer { httpDone.signal() }
    if let error { print("❌ HTTP : \(error.localizedDescription)"); return }
    guard let data, let envelope = try? JSONDecoder().decode(Envelope.self, from: data) else {
        print("❌ Réponse illisible : \(String(data: data ?? Data(), encoding: .utf8) ?? "<vide>")")
        return
    }
    guard envelope.code == 200, envelope.success == true, let payload = envelope.data else {
        print("❌ API refusée : code \(envelope.code ?? -1) — \(envelope.msg ?? "?")")
        return
    }
    devices = payload.deviceList ?? []
    mqttInfo = payload.mqtt
}.resume()
httpDone.wait()

guard !devices.isEmpty, let mqtt = mqttInfo else {
    print("❌ Aucun appareil ou pas de credentials MQTT — jeton du compte principal ?")
    exit(1)
}

print("\n=== \(devices.count) appareil(s) sur le compte ===")
for d in devices {
    print("• \(d.deviceName ?? d.productModel ?? d.deviceKey)  [modèle \(d.productModel ?? "?"), productKey \(d.productKey), deviceKey \(d.deviceKey), SN \(d.snNumber ?? "?")]")
}

// MARK: - MQTT minimal (CONNECT / SUBSCRIBE / PUBLISH QoS 0, dump de tout)

func mqttString(_ s: String) -> Data {
    let utf8 = Data(s.utf8)
    var d = Data([UInt8(utf8.count >> 8), UInt8(utf8.count & 0xFF)]); d.append(utf8); return d
}
func remainingLength(_ length: Int) -> Data {
    var d = Data(); var v = length
    repeat { var b = UInt8(v % 128); v /= 128; if v > 0 { b |= 0x80 }; d.append(b) } while v > 0
    return d
}
func framed(_ type: UInt8, _ body: Data) -> Data {
    var d = Data([type]); d.append(remainingLength(body.count)); d.append(body); return d
}

let hostPart: String
let portPart: UInt16
if let idx = mqtt.url.lastIndex(of: ":"), let p = UInt16(mqtt.url[mqtt.url.index(after: idx)...]) {
    hostPart = String(mqtt.url[mqtt.url.startIndex..<idx]); portPart = p
} else { hostPart = mqtt.url; portPart = 1883 }
print("\n→ MQTT \(hostPart):\(portPart) (client \(mqtt.clientId))\n")

let queue = DispatchQueue(label: "probe.mqtt")
let conn = NWConnection(host: NWEndpoint.Host(hostPart), port: NWEndpoint.Port(rawValue: portPart)!, using: .tcp)
var buffer = Data()
var seenKeys: [String: String] = [:]   // clé JSON → "topic : dernière valeur"

func handlePacket(first: UInt8, body: Data) {
    switch first & 0xF0 {
    case 0x20:
        print("✓ CONNACK — abonnement et getAll…")
        var sub = Data([0x00, 0x01])
        for d in devices {
            sub.append(mqttString("/\(d.productKey)/\(d.deviceKey)/#")); sub.append(0x00)
            sub.append(mqttString("iot/\(d.productKey)/\(d.deviceKey)/#")); sub.append(0x00)
        }
        // Filets larges : si les ACL du compte couvrent d'autres appareils
        // (ex. Smart CT absent de deviceList), leurs topics arriveront aussi.
        for wildcard in ["#", "iot/#", "/+/+/#"] {
            sub.append(mqttString(wildcard)); sub.append(0x00)
        }
        conn.send(content: framed(0x82, sub), completion: .contentProcessed { _ in })
        for (i, d) in devices.enumerated() {
            let payload: [String: Any] = ["properties": ["getAll"], "deviceId": d.deviceKey,
                                          "messageId": i + 1, "timestamp": Int(Date().timeIntervalSince1970)]
            if let data = try? JSONSerialization.data(withJSONObject: payload) {
                var pub = mqttString("iot/\(d.productKey)/\(d.deviceKey)/properties/read")
                pub.append(data)
                conn.send(content: framed(0x30, pub), completion: .contentProcessed { _ in })
            }
        }
    case 0x30:
        let qos = (first >> 1) & 0x03
        guard body.count >= 2 else { return }
        let tLen = Int(body[body.startIndex]) << 8 | Int(body[body.startIndex + 1])
        guard body.count >= 2 + tLen,
              let topic = String(data: body[(body.startIndex + 2)..<(body.startIndex + 2 + tLen)], encoding: .utf8) else { return }
        var offset = 2 + tLen
        if qos > 0 { offset += 2 }
        let payload = Data(body[(body.startIndex + offset)...])
        let text = String(data: payload, encoding: .utf8) ?? "<binaire \(payload.count) o>"
        print("[\(topic)]")
        print("  \(text)")
        if let root = (try? JSONSerialization.jsonObject(with: payload)) as? [String: Any] {
            let props = (root["properties"] as? [String: Any]) ?? root
            for (k, v) in props where !(v is [Any]) && !(v is [String: Any]) {
                seenKeys[k] = "\(v)  (\(topic))"
            }
        }
    default: break
    }
}

func drain() {
    while buffer.count >= 2 {
        var value = 0, multiplier = 1, index = 1, ok = false
        while index < buffer.count, index <= 4 {
            let b = buffer[buffer.startIndex + index]
            value += Int(b & 0x7F) * multiplier; index += 1
            if b & 0x80 == 0 { ok = true; break }
            multiplier *= 128
        }
        guard ok, buffer.count >= index + value else { return }
        let first = buffer[buffer.startIndex]
        let body = Data(buffer[(buffer.startIndex + index)..<(buffer.startIndex + index + value)])
        buffer.removeFirst(index + value)
        handlePacket(first: first, body: body)
    }
}

func receiveLoop() {
    conn.receive(minimumIncompleteLength: 1, maximumLength: 65536) { data, _, done, error in
        if let data { buffer.append(data); drain() }
        if done || error != nil { print("✗ connexion fermée (\(error?.localizedDescription ?? "fin"))"); exit(2) }
        receiveLoop()
    }
}

conn.stateUpdateHandler = { state in
    switch state {
    case .ready:
        var body = mqttString("MQTT"); body.append(0x04); body.append(0xC2)
        body.append(contentsOf: [0x00, 0x3C])  // keepAlive 60 s
        body.append(mqttString(mqtt.clientId)); body.append(mqttString(mqtt.username)); body.append(mqttString(mqtt.password))
        conn.send(content: framed(0x10, body), completion: .contentProcessed { _ in })
        receiveLoop()
    case .failed(let error): print("❌ TCP : \(error)"); exit(2)
    default: break
    }
}
conn.start(queue: queue)

// PINGREQ toutes les 30 s pour tenir la connexion pendant l'écoute.
let ping = DispatchSource.makeTimerSource(queue: queue)
ping.schedule(deadline: .now() + 30, repeating: 30)
ping.setEventHandler { conn.send(content: Data([0xC0, 0x00]), completion: .contentProcessed { _ in }) }
ping.resume()

print("… écoute pendant \(listenSeconds) s (rapports spontanés + réponse getAll)\n")
DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(listenSeconds)) {
    print("\n=== Récapitulatif : \(seenKeys.count) clés distinctes vues ===")
    for key in seenKeys.keys.sorted(by: { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }) {
        print("  \(key) = \(seenKeys[key]!)")
    }
    print("\nClés à chercher pour la consommation maison / réseau : homePower, homeUsePower, smartPower, gridPower, ctA/ctB/ctC, phaseA…")
    exit(0)
}
RunLoop.main.run()
