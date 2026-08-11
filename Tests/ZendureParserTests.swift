import XCTest

final class ZendureParserTests: XCTestCase {
    func testNestedPayload() throws {
        let json = """
        {
          "sn": "EEB4AEP4P150803",
          "product": "solarFlow2400Pro",
          "properties": {
            "solarInputPower": 287,
            "solarPower1": 148, "solarPower2": 139,
            "electricLevel": 14,
            "outputHomePower": 199,
            "gridInputPower": 0,
            "packInputPower": 0,
            "outputPackPower": 88,
            "gridOffPower": 42,
            "hyperTmp": 3151,
            "remainOutTime": 557,
            "rssi": -52,
            "BatVolt": 4921,
            "socSet": 1000,
            "minSoc": 100,
            "acMode": 2
          },
          "packData": [
            {"sn": "P1", "socLevel": 14, "maxTemp": 3081, "power": 29},
            {"sn": "P2", "socLevel": 15, "maxTemp": 3085, "power": 30}
          ]
        }
        """
        let state = try ZendureParser.parse(Data(json.utf8))
        XCTAssertEqual(state.solarInputPower, 287)
        XCTAssertEqual(state.solarChannels, [148, 139])
        XCTAssertEqual(state.electricLevel, 14)
        XCTAssertEqual(state.outputHomePower, 199)
        XCTAssertEqual(state.outputPackPower, 88)
        XCTAssertEqual(state.offGridPower, 42)
        XCTAssertEqual(state.batteryFlow, 88)
        XCTAssertEqual(state.serialNumber, "EEB4AEP4P150803")
        XCTAssertEqual(state.packs.count, 2)
        XCTAssertEqual(state.packs[0].socLevel, 14)
        XCTAssertEqual(state.remainOutMinutes, 557)
        XCTAssertEqual(state.socMax, 100)
        XCTAssertEqual(state.socMin, 10)
        XCTAssertEqual(try XCTUnwrap(state.batteryVoltage), 49.21, accuracy: 0.001)
        // hyperTmp 3151 (0,1 K) → 41,95 °C
        XCTAssertEqual(try XCTUnwrap(state.deviceTemperature), 41.95, accuracy: 0.2)
    }

    func testFlatPayloadWithStringNumbers() throws {
        let json = """
        {"solarInputPower": "412", "electricLevel": 55.5, "outputHomePower": 120}
        """
        let state = try ZendureParser.parse(Data(json.utf8))
        XCTAssertEqual(state.solarInputPower, 412)
        XCTAssertEqual(state.electricLevel, 55.5)
        XCTAssertEqual(state.outputHomePower, 120)
        XCTAssertEqual(state.offGridPower, 0)
    }

    func testRemainOutTimeSentinelBecomesNil() throws {
        let json = #"{"properties": {"remainOutTime": 59940}}"#
        let state = try ZendureParser.parse(Data(json.utf8))
        XCTAssertNil(state.remainOutMinutes)
    }

    func testDischargeGivesNegativeBatteryFlow() throws {
        let json = #"{"properties": {"packInputPower": 290, "outputPackPower": 0}}"#
        let state = try ZendureParser.parse(Data(json.utf8))
        XCTAssertEqual(state.batteryFlow, -290)
    }

    func testBadPayloadThrows() {
        XCTAssertThrowsError(try ZendureParser.parse(Data("[1,2,3]".utf8)))
        XCTAssertThrowsError(try ZendureParser.parse(Data("not json".utf8)))
    }

    func testSmartCTPayloadIsRejected() {
        // Payload réel d'un SmartMeter 3CT sur la même API zenSDK — avant le
        // garde-fou, il « réussissait » en DeviceState tout à zéro.
        let json = """
        {"sn": "61u1m6E3", "properties": {"a_aprt_power": 0, "b_aprt_power": 0,
         "c_aprt_power": 767, "total_power": 767}}
        """
        XCTAssertThrowsError(try ZendureParser.parse(Data(json.utf8))) { error in
            guard case ZendureError.notASolarFlow = error else {
                return XCTFail("attendu notASolarFlow, reçu \(error)")
            }
        }
    }

    func testPayloadWithoutSolarFlowSignatureIsRejected() {
        let json = #"{"sn": "X", "rssi": -50, "foo": 1}"#
        XCTAssertThrowsError(try ZendureParser.parse(Data(json.utf8))) { error in
            guard case ZendureError.badPayload = error else {
                return XCTFail("attendu badPayload, reçu \(error)")
            }
        }
    }
}
