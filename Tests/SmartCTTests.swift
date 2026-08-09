import XCTest

final class SmartCTTests: XCTestCase {
    func testParseRealPayload() throws {
        // Payload réel du SmartMeter3CT (relevé du 2026-08-09).
        let json = """
        {"timestamp": 1786270830, "messageId": 213, "deviceId": "61u1m6E3",
         "a_aprt_power": 0, "b_aprt_power": 0, "c_aprt_power": 2089,
         "total_power": 2089}
        """
        let report = try SmartCTParser.parse(Data(json.utf8))
        XCTAssertEqual(report.totalPower, 2089)
        XCTAssertEqual(report.phases, [0, 0, 2089])
        XCTAssertEqual(report.deviceId, "61u1m6E3")
    }

    func testParseTotalFallsBackToPhaseSum() throws {
        let json = """
        {"a_aprt_power": 100, "b_aprt_power": "200", "c_aprt_power": 50}
        """
        let report = try SmartCTParser.parse(Data(json.utf8))
        XCTAssertEqual(report.totalPower, 350)
    }

    func testParseRejectsPayloadWithoutPower() {
        XCTAssertThrowsError(try SmartCTParser.parse(Data("{\"messageId\": 1}".utf8)))
        XCTAssertThrowsError(try SmartCTParser.parse(Data("[]".utf8)))
    }
}
