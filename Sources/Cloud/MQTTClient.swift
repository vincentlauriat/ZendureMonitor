import Foundation
import Network

/// Client MQTT 3.1.1 minimal sur Network.framework — juste ce dont l'app a
/// besoin : CONNECT avec username/password, SUBSCRIBE QoS 0, PUBLISH QoS 0,
/// réception de PUBLISH QoS 0/1 (avec PUBACK), keepalive PINGREQ.
/// Implémentation maison pour rester sans dépendance externe.
///
/// L'encodage/décodage des paquets est exposé en `static` pour être testé
/// unitairement sans réseau (`MQTTPacket`).
final class MQTTClient: @unchecked Sendable {
    enum State: Equatable {
        case idle
        case connecting
        case connected
        case disconnected(reason: String?)
    }

    private let host: String
    private let port: UInt16
    private let clientId: String
    private let username: String
    private let password: String
    private let keepAlive: UInt16 = 60

    private let queue = DispatchQueue(label: "fr.lauriat.ZendureMonitor.mqtt")
    private var connection: NWConnection?
    private var buffer = Data()
    private var packetIdentifier: UInt16 = 0
    private var pingTimer: DispatchSourceTimer?

    /// Callbacks — appelés sur la queue interne ; l'appelant re-dispatch.
    var onMessage: ((_ topic: String, _ payload: Data) -> Void)?
    var onStateChange: ((State) -> Void)?

    private(set) var state: State = .idle {
        didSet { if state != oldValue { onStateChange?(state) } }
    }

    init(host: String, port: UInt16, clientId: String, username: String, password: String) {
        self.host = host
        self.port = port
        self.clientId = clientId
        self.username = username
        self.password = password
    }

    func connect() {
        queue.async { [self] in
            guard connection == nil else { return }
            state = .connecting
            let conn = NWConnection(
                host: NWEndpoint.Host(host),
                port: NWEndpoint.Port(rawValue: port) ?? 1883,
                using: .tcp
            )
            connection = conn
            conn.stateUpdateHandler = { [weak self] nwState in
                guard let self else { return }
                switch nwState {
                case .ready:
                    self.send(MQTTPacket.connect(
                        clientId: self.clientId,
                        username: self.username,
                        password: self.password,
                        keepAlive: self.keepAlive
                    ))
                    self.receiveLoop()
                case .failed(let error):
                    self.teardown(reason: error.localizedDescription)
                case .cancelled:
                    self.teardown(reason: nil)
                default:
                    break
                }
            }
            conn.start(queue: queue)
        }
    }

    func disconnect() {
        queue.async { [self] in
            send(Data([0xE0, 0x00]))  // DISCONNECT
            teardown(reason: nil)
        }
    }

    func subscribe(topics: [String]) {
        queue.async { [self] in
            guard !topics.isEmpty else { return }
            packetIdentifier &+= 1
            if packetIdentifier == 0 { packetIdentifier = 1 }
            send(MQTTPacket.subscribe(topics: topics, packetId: packetIdentifier))
        }
    }

    func publish(topic: String, payload: Data) {
        queue.async { [self] in
            send(MQTTPacket.publish(topic: topic, payload: payload))
        }
    }

    // MARK: - Internes

    private func send(_ data: Data) {
        connection?.send(content: data, completion: .contentProcessed { [weak self] error in
            if let error {
                self?.teardown(reason: error.localizedDescription)
            }
        })
    }

    private func receiveLoop() {
        connection?.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            if let data, !data.isEmpty {
                self.buffer.append(data)
                self.drainBuffer()
            }
            if isComplete || error != nil {
                self.teardown(reason: error?.localizedDescription ?? String(localized: "connexion fermée par le serveur"))
                return
            }
            self.receiveLoop()
        }
    }

    private func drainBuffer() {
        while let packet = MQTTPacket.parse(from: &buffer) {
            handle(packet)
        }
    }

    private func handle(_ packet: MQTTPacket.Incoming) {
        switch packet {
        case .connack(let returnCode):
            if returnCode == 0 {
                state = .connected
                startPingTimer()
            } else {
                teardown(reason: "CONNACK refusé (code \(returnCode))")
            }
        case .publish(let topic, let payload, let packetId):
            if let packetId {
                send(MQTTPacket.puback(packetId: packetId))
            }
            onMessage?(topic, payload)
        case .suback(let returnCodes):
            // Tous les abonnements refusés : sans eux, aucune donnée n'arrivera
            // jamais — remonter une erreur explicite plutôt que rester « live »
            // sur un flux vide.
            if !returnCodes.isEmpty, returnCodes.allSatisfy({ $0 == 0x80 }) {
                teardown(reason: String(localized: "abonnements refusés par le serveur"))
            }
        case .puback, .pingresp:
            break
        }
    }

    private func startPingTimer() {
        pingTimer?.cancel()
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + .seconds(Int(keepAlive) / 2), repeating: .seconds(Int(keepAlive) / 2))
        timer.setEventHandler { [weak self] in
            self?.send(Data([0xC0, 0x00]))  // PINGREQ
        }
        timer.resume()
        pingTimer = timer
    }

    private func teardown(reason: String?) {
        pingTimer?.cancel()
        pingTimer = nil
        connection?.cancel()
        connection = nil
        buffer.removeAll()
        if state != .disconnected(reason: reason) {
            state = .disconnected(reason: reason)
        }
    }
}

/// Encodage/décodage des paquets MQTT 3.1.1 — fonctions pures, testables.
enum MQTTPacket {
    enum Incoming: Equatable {
        case connack(returnCode: UInt8)
        /// Un code par topic demandé : 0x00/0x01/0x02 = QoS accordée,
        /// 0x80 = abonnement refusé par le broker.
        case suback(returnCodes: [UInt8])
        case puback
        case pingresp
        case publish(topic: String, payload: Data, packetId: UInt16?)
    }

    // MARK: Encodage

    static func connect(clientId: String, username: String, password: String, keepAlive: UInt16) -> Data {
        var variable = Data()
        variable.append(encodeString("MQTT"))
        variable.append(0x04)  // niveau de protocole 3.1.1
        variable.append(0xC2)  // flags : username + password + clean session
        variable.append(contentsOf: [UInt8(keepAlive >> 8), UInt8(keepAlive & 0xFF)])
        variable.append(encodeString(clientId))
        variable.append(encodeString(username))
        variable.append(encodeString(password))
        return framed(type: 0x10, body: variable)
    }

    static func subscribe(topics: [String], packetId: UInt16) -> Data {
        var body = Data([UInt8(packetId >> 8), UInt8(packetId & 0xFF)])
        for topic in topics {
            body.append(encodeString(topic))
            body.append(0x00)  // QoS 0 demandé
        }
        return framed(type: 0x82, body: body)
    }

    static func publish(topic: String, payload: Data) -> Data {
        var body = encodeString(topic)
        body.append(payload)  // QoS 0 : pas de packet identifier
        return framed(type: 0x30, body: body)
    }

    static func puback(packetId: UInt16) -> Data {
        Data([0x40, 0x02, UInt8(packetId >> 8), UInt8(packetId & 0xFF)])
    }

    static func encodeString(_ string: String) -> Data {
        let utf8 = Data(string.utf8)
        var data = Data([UInt8(utf8.count >> 8), UInt8(utf8.count & 0xFF)])
        data.append(utf8)
        return data
    }

    static func encodeRemainingLength(_ length: Int) -> Data {
        var data = Data()
        var value = length
        repeat {
            var byte = UInt8(value % 128)
            value /= 128
            if value > 0 { byte |= 0x80 }
            data.append(byte)
        } while value > 0
        return data
    }

    private static func framed(type: UInt8, body: Data) -> Data {
        var data = Data([type])
        data.append(encodeRemainingLength(body.count))
        data.append(body)
        return data
    }

    // MARK: Décodage

    /// Décode la « remaining length » à partir de l'index 1. Retourne
    /// (longueur, taille de l'en-tête complet) ou nil si le buffer est
    /// incomplet.
    static func decodeRemainingLength(_ data: Data) -> (length: Int, headerSize: Int)? {
        var multiplier = 1
        var value = 0
        var index = 1
        while true {
            guard index < data.count, index <= 4 else { return nil }
            let byte = data[data.startIndex + index]
            value += Int(byte & 0x7F) * multiplier
            index += 1
            if byte & 0x80 == 0 { break }
            multiplier *= 128
        }
        return (value, index)
    }

    /// Extrait le premier paquet complet du buffer (et l'en retire), sinon nil.
    static func parse(from buffer: inout Data) -> Incoming? {
        guard buffer.count >= 2 else { return nil }
        guard let (remaining, headerSize) = decodeRemainingLength(buffer) else { return nil }
        let total = headerSize + remaining
        guard buffer.count >= total else { return nil }

        let first = buffer[buffer.startIndex]
        let body = Data(buffer[(buffer.startIndex + headerSize)..<(buffer.startIndex + total)])
        buffer.removeFirst(total)

        switch first & 0xF0 {
        case 0x20:
            return .connack(returnCode: body.count >= 2 ? body[body.startIndex + 1] : 0xFF)
        case 0x90:
            // Corps : packet identifier (2 octets) puis un code de retour par topic.
            return .suback(returnCodes: body.count > 2 ? Array(body.dropFirst(2)) : [])
        case 0x40:
            return .puback
        case 0xD0:
            return .pingresp
        case 0x30:
            let qos = (first >> 1) & 0x03
            guard body.count >= 2 else { return nil }
            let topicLength = Int(body[body.startIndex]) << 8 | Int(body[body.startIndex + 1])
            guard body.count >= 2 + topicLength else { return nil }
            let topicData = body[(body.startIndex + 2)..<(body.startIndex + 2 + topicLength)]
            guard let topic = String(data: topicData, encoding: .utf8) else { return nil }
            var offset = 2 + topicLength
            var packetId: UInt16? = nil
            if qos > 0 {
                guard body.count >= offset + 2 else { return nil }
                packetId = UInt16(body[body.startIndex + offset]) << 8 | UInt16(body[body.startIndex + offset + 1])
                offset += 2
            }
            let payload = Data(body[(body.startIndex + offset)...])
            return .publish(topic: topic, payload: payload, packetId: packetId)
        default:
            // Type non géré (PUBREC…) : ignoré, on continue le drain.
            return parse(from: &buffer)
        }
    }
}
