import XCTest

/// Tests de la couche cloud, portés de ZendureCloud (où le protocole a été
/// validé en réel) : décodage du Cloud Key, signature deviceList, paquets
/// MQTT, fusion des rapports partiels et mapping vers `DeviceState`.
final class CloudKeyTests: XCTestCase {
    func testDecodeValidToken() throws {
        // "https://app.zendure.tech/eu.myAppKey123" en base64
        let token = Data("https://app.zendure.tech/eu.myAppKey123".utf8).base64EncodedString()
        let key = try CloudKey.decode(token)
        XCTAssertEqual(key.apiUrl.absoluteString, "https://app.zendure.tech/eu")
        XCTAssertEqual(key.appKey, "myAppKey123")
    }

    func testDecodeSplitsOnLastDot() throws {
        let token = Data("https://api.zendure.example.com.abc123".utf8).base64EncodedString()
        let key = try CloudKey.decode(token)
        XCTAssertEqual(key.apiUrl.absoluteString, "https://api.zendure.example.com")
        XCTAssertEqual(key.appKey, "abc123")
    }

    func testDecodeTokenWithoutPadding() throws {
        var token = Data("https://a.io.key".utf8).base64EncodedString()
        token = token.replacingOccurrences(of: "=", with: "")
        let key = try CloudKey.decode(token)
        XCTAssertEqual(key.appKey, "key")
    }

    func testDecodeRejectsGarbage() {
        XCTAssertThrowsError(try CloudKey.decode("%%%non-base64%%%"))
        XCTAssertThrowsError(try CloudKey.decode(Data("pas-de-point-du-tout".utf8).base64EncodedString()))
    }
}

final class CloudSignatureTests: XCTestCase {
    func testSignSortsKeysAndUppercases() {
        let sign = ZendureAPI.sign(parameters: [
            "timestamp": "1700000000",
            "appKey": "A",
            "nonce": "12345",
        ])
        XCTAssertEqual(sign.count, 40)
        XCTAssertEqual(sign, sign.uppercased())
        // La même entrée doit toujours produire la même signature (déterminisme,
        // indépendamment de l'ordre du dictionnaire).
        let again = ZendureAPI.sign(parameters: ["appKey": "A", "nonce": "12345", "timestamp": "1700000000"])
        XCTAssertEqual(sign, again)
    }

    func testDeviceListRequestHeaders() throws {
        let key = CloudKey(apiUrl: URL(string: "https://app.zendure.tech/eu")!, appKey: "abc")
        let request = ZendureAPI.deviceListRequest(cloudKey: key, now: Date(timeIntervalSince1970: 1_700_000_000), nonce: 54321)
        XCTAssertEqual(request.url?.absoluteString, "https://app.zendure.tech/eu/api/ha/deviceList")
        XCTAssertEqual(request.value(forHTTPHeaderField: "clientid"), "zenHa")
        XCTAssertEqual(request.value(forHTTPHeaderField: "timestamp"), "1700000000")
        XCTAssertEqual(request.value(forHTTPHeaderField: "nonce"), "54321")
        XCTAssertEqual(request.value(forHTTPHeaderField: "sign")?.count, 40)
        let body = try XCTUnwrap(request.httpBody)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: String])
        XCTAssertEqual(json, ["appKey": "abc"])
    }
}

final class MQTTPacketTests: XCTestCase {
    func testRemainingLengthRoundTrip() {
        for length in [0, 1, 127, 128, 16383, 16384, 2_097_151] {
            var data = Data([0x30])
            data.append(MQTTPacket.encodeRemainingLength(length))
            let decoded = MQTTPacket.decodeRemainingLength(data)
            XCTAssertEqual(decoded?.length, length, "longueur \(length)")
        }
    }

    func testConnectPacketShape() {
        let packet = MQTTPacket.connect(clientId: "cid", username: "user", password: "pass", keepAlive: 60)
        XCTAssertEqual(packet[0], 0x10)
        XCTAssertTrue(packet.contains(0x04))
        let raw = String(decoding: packet, as: UTF8.self)
        XCTAssertTrue(raw.contains("cid"))
        XCTAssertTrue(raw.contains("user"))
        XCTAssertTrue(raw.contains("pass"))
    }

    func testParsePublishQoS0() {
        var buffer = MQTTPacket.publish(topic: "iot/pk/dk/properties/report", payload: Data("{\"a\":1}".utf8))
        let incoming = MQTTPacket.parse(from: &buffer)
        guard case .publish(let topic, let payload, let packetId) = incoming else {
            return XCTFail("attendu un PUBLISH, reçu \(String(describing: incoming))")
        }
        XCTAssertEqual(topic, "iot/pk/dk/properties/report")
        XCTAssertEqual(String(decoding: payload, as: UTF8.self), "{\"a\":1}")
        XCTAssertNil(packetId)
        XCTAssertTrue(buffer.isEmpty)
    }

    func testParsePublishQoS1CarriesPacketId() {
        // PUBLISH QoS1 construit à la main : header 0x32, topic "t", packetId 7, payload "x"
        var body = MQTTPacket.encodeString("t")
        body.append(contentsOf: [0x00, 0x07])
        body.append(Data("x".utf8))
        var buffer = Data([0x32])
        buffer.append(MQTTPacket.encodeRemainingLength(body.count))
        buffer.append(body)
        let incoming = MQTTPacket.parse(from: &buffer)
        guard case .publish(_, _, let packetId) = incoming else {
            return XCTFail("attendu un PUBLISH")
        }
        XCTAssertEqual(packetId, 7)
    }

    func testParseIncompleteBufferReturnsNilAndKeepsBytes() {
        let full = MQTTPacket.publish(topic: "topic", payload: Data(repeating: 0x41, count: 50))
        let cut = full.count - 10
        var partial = Data(full.prefix(cut))
        XCTAssertNil(MQTTPacket.parse(from: &partial))
        XCTAssertEqual(partial.count, cut)  // rien consommé
        partial.append(full.suffix(10))
        XCTAssertNotNil(MQTTPacket.parse(from: &partial))
    }

    func testParseConnack() {
        var buffer = Data([0x20, 0x02, 0x00, 0x00])
        XCTAssertEqual(MQTTPacket.parse(from: &buffer), .connack(returnCode: 0))
    }

    func testParseTwoPacketsInOneBuffer() {
        var buffer = Data([0x20, 0x02, 0x00, 0x00, 0xD0, 0x00])
        XCTAssertEqual(MQTTPacket.parse(from: &buffer), .connack(returnCode: 0))
        XCTAssertEqual(MQTTPacket.parse(from: &buffer), .pingresp)
        XCTAssertNil(MQTTPacket.parse(from: &buffer))
    }
}

final class CloudDeviceStateTests: XCTestCase {
    func testMergeFlatAndNestedPayloads() {
        var state = CloudDeviceState()
        state.merge(payload: ["properties": ["electricLevel": 82, "solarInputPower": 340]])
        XCTAssertEqual(state.electricLevel, 82)
        state.merge(payload: ["outputHomePower": "215"])  // à plat + nombre en chaîne
        XCTAssertEqual(state.outputHomePower, 215)
        // La fusion garde les champs précédents (rapports partiels).
        XCTAssertEqual(state.solarInputPower, 340)
    }

    func testUnitConversions() {
        var state = CloudDeviceState()
        state.merge(payload: [
            "hyperTmp": 2981,          // 25,0 °C
            "BatVolt": 5230,           // 52,30 V
            "socSet": 800,             // échelle dixièmes → 80 %
            "minSoc": 20,              // échelle directe → 20 %
            "remainOutTime": 59940,    // sentinelle "indisponible"
        ])
        XCTAssertEqual(state.deviceTemperature!, 25.0, accuracy: 0.01)
        XCTAssertEqual(state.batteryVoltage!, 52.30, accuracy: 0.001)
        XCTAssertEqual(state.socMax, 80)
        XCTAssertEqual(state.socMin, 20)
        XCTAssertNil(state.remainOutMinutes)
    }

    func testPackDataMergeBySn() {
        var state = CloudDeviceState()
        state.merge(payload: [
            "packData": [
                ["sn": "P1", "socLevel": 90, "maxTemp": 2985, "power": 0],
            ],
        ])
        XCTAssertEqual(state.packs.count, 1)
        XCTAssertEqual(state.packs[0].socLevel, 90)
        XCTAssertEqual(state.packs[0].temperature!, 25.4, accuracy: 0.01)

        // Second rapport partiel : fusion par sn, pas remplacement.
        state.merge(payload: ["packData": [["sn": "P1", "power": 120]]])
        XCTAssertEqual(state.packs.count, 1)
        XCTAssertEqual(state.packs[0].power, 120)
        XCTAssertEqual(state.packs[0].socLevel, 90)
    }

    func testSolarChannels() {
        var state = CloudDeviceState()
        state.merge(payload: ["solarPower1": 120, "solarPower2": 95])
        XCTAssertEqual(state.solarChannels, [120, 95])
    }

    func testDeviceStateMapping() {
        var cloud = CloudDeviceState()
        cloud.merge(payload: [
            "properties": [
                "electricLevel": 64,
                "solarInputPower": 410,
                "outputHomePower": 300,
                "outputPackPower": 110,
                "packInputPower": 0,
                "socSet": 800,
                "minSoc": 100,
            ],
            "packData": [["sn": "P1", "socLevel": 64]],
        ], at: Date(timeIntervalSince1970: 1_700_000_000))

        let state = cloud.deviceState(fallbackSerial: "SN-FALLBACK")
        XCTAssertEqual(state.solarInputPower, 410)
        XCTAssertEqual(state.electricLevel, 64)
        XCTAssertEqual(state.outputHomePower, 300)
        XCTAssertEqual(state.batteryFlow, 110)   // charge - décharge
        XCTAssertEqual(state.socMax, 80)
        XCTAssertEqual(state.socMin, 10)
        XCTAssertEqual(state.serialNumber, "SN-FALLBACK")  // pas de sn dans le payload
        XCTAssertEqual(state.packs.count, 1)
        XCTAssertEqual(state.packs[0].serialNumber, "P1")
        XCTAssertEqual(state.updatedAt, Date(timeIntervalSince1970: 1_700_000_000))

        // Les champs jamais reçus restent aux valeurs par défaut « zéro » du
        // DeviceState local, pas des optionnels surprises.
        XCTAssertEqual(state.gridInputPower, 0)
        XCTAssertEqual(state.offGridPower, 0)
    }

    func testDeviceSerialFromPayloadWinsOverFallback() {
        var cloud = CloudDeviceState()
        cloud.merge(payload: ["sn": "SN-REAL", "solarInputPower": 10])
        XCTAssertEqual(cloud.deviceState(fallbackSerial: "SN-FALLBACK").serialNumber, "SN-REAL")
    }
}

final class MQTTCredentialsTests: XCTestCase {
    private func creds(_ url: String) -> MQTTCredentials {
        MQTTCredentials(clientId: "c", url: url, username: "u", password: "p")
    }

    func testHostPortSplit() {
        XCTAssertEqual(creds("mqtt.zen-iot.com:1883").host, "mqtt.zen-iot.com")
        XCTAssertEqual(creds("mqtt.zen-iot.com:1883").port, 1883)
        XCTAssertEqual(creds("mqtt.zen-iot.com").host, "mqtt.zen-iot.com")
        XCTAssertEqual(creds("mqtt.zen-iot.com").port, 1883)
        XCTAssertEqual(creds("broker:8883").port, 8883)
    }
}
