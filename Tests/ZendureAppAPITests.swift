import XCTest

/// Tests du client de l'API privée de l'app Zendure (historique tdengine) —
/// constructeurs de requêtes et parseurs purs, sans réseau.
final class ZendureAppAPITests: XCTestCase {
    private let session = ZendureAppAPI.Session(
        accessToken: "tok123",
        serverNodeUrl: URL(string: "https://node.zendure.tech/eu")!
    )
    private let device = ZendureAppAPI.AppDevice(id: "4242", idIsNumeric: true, snNumber: "SN1", name: "Hyper")

    func testLoginRequestShape() throws {
        let request = ZendureAppAPI.loginRequest(base: ZendureAppAPI.defaultBase, account: "a@b.c", password: "pw")
        XCTAssertEqual(request.url?.absoluteString, "https://app.zendure.tech/eu/auth/app/token")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Basic Q29uc3VtZXJBcHA6NX4qUmRuTnJATWg0WjEyMw==")
        XCTAssertEqual(request.value(forHTTPHeaderField: "appVersion"), "4.3.1")
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(request.httpBody)) as? [String: Any])
        XCTAssertEqual(body["account"] as? String, "a@b.c")
        XCTAssertEqual(body["grantType"] as? String, "password")
        XCTAssertEqual(body["appId"] as? String, "121c83f761305d6cf7e")
    }

    func testLoginRequestSendsNullBladeAuth() {
        let request = ZendureAppAPI.loginRequest(base: ZendureAppAPI.defaultBase, account: "a", password: "b")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Blade-Auth"), "bearer (null)")
    }

    func testParseLoginNormalizesServerNodeUrl() throws {
        let json = #"{"code":200,"success":true,"data":{"accessToken":"tok","serverNodeUrl":"node.zendure.tech/eu"}}"#
        let parsed = try ZendureAppAPI.parseLogin(Data(json.utf8))
        XCTAssertEqual(parsed.accessToken, "tok")
        XCTAssertEqual(parsed.serverNodeUrl.absoluteString, "https://node.zendure.tech/eu")
    }

    func testParseLoginRejectsFailure() {
        let json = #"{"code":401,"success":false,"msg":"bad credentials"}"#
        XCTAssertThrowsError(try ZendureAppAPI.parseLogin(Data(json.utf8)))
    }

    func testParseAppDevicesNumericId() throws {
        let json = #"{"code":200,"success":true,"data":[{"id":4242,"snNumber":"SN1","name":"Hyper"},{"noId":true}]}"#
        let devices = try ZendureAppAPI.parseAppDevices(Data(json.utf8))
        XCTAssertEqual(devices.count, 1)
        XCTAssertEqual(devices[0].id, "4242")
        XCTAssertTrue(devices[0].idIsNumeric)
        XCTAssertEqual(devices[0].snNumber, "SN1")
    }

    func testEnergyRequestDayMode() throws {
        let request = ZendureAppAPI.energyRequest(session: session, device: device, date: "2026-08-10", zone: "Europe/Paris")
        XCTAssertEqual(request.url?.absoluteString, "https://node.zendure.tech/eu/tdengine/device/solarFlow/energy")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Blade-Auth"), "bearer tok123")
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(request.httpBody)) as? [String: Any])
        XCTAssertEqual(body["beginDate"] as? String, "2026-08-10")
        XCTAssertEqual(body["endDate"] as? String, "2026-08-10")
        XCTAssertEqual(body["type"] as? Int, 0)
        XCTAssertEqual(body["deviceId"] as? Int, 4242)  // id numérique re-sérialisé en nombre
        XCTAssertEqual(body["zone"] as? String, "Europe/Paris")
    }

    func testEnergyRequestLifetimeMode() throws {
        let request = ZendureAppAPI.energyRequest(session: session, device: device, date: nil)
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(request.httpBody)) as? [String: Any])
        XCTAssertEqual(body["beginDate"] as? String, "")
        XCTAssertEqual(body["endDate"] as? String, "")
        XCTAssertEqual(body["type"] as? String, "")
    }

    func testParseEnergyFieldsSkipsSeries() throws {
        let json = #"{"code":200,"success":true,"data":{"solar":1234,"home":"567","energyVos":[{"x":1}],"data":[1,2],"nested":{"a":1}}}"#
        let fields = try ZendureAppAPI.parseEnergyFields(Data(json.utf8))
        XCTAssertEqual(fields["solar"], 1234)
        XCTAssertEqual(fields["home"], 567)  // nombre en chaîne toléré
        XCTAssertNil(fields["energyVos"])
        XCTAssertNil(fields["nested"])
    }

    func testRedactedBodyMasksPassword() throws {
        let body = try JSONSerialization.data(withJSONObject: ["account": "a@b.c", "password": "secret123"])
        let redacted = ZendureAppAPI.redactedBody(body)
        XCTAssertFalse(redacted.contains("secret123"))
        XCTAssertTrue(redacted.contains("•••"))
        XCTAssertTrue(redacted.contains("a@b.c"))
        // Corps non-JSON : renvoyé tronqué tel quel, sans crash.
        XCTAssertEqual(ZendureAppAPI.redactedBody(Data("brut".utf8)), "brut")
        XCTAssertEqual(ZendureAppAPI.redactedBody(nil), "")
    }

    func testDateStrings() {
        let reference = EnergyDay.formatter.date(from: "2026-08-10")!
        let dates = ZendureAppAPI.dateStrings(back: 3, from: reference)
        XCTAssertEqual(dates, ["2026-08-08", "2026-08-09", "2026-08-10"])
        XCTAssertEqual(ZendureAppAPI.dateStrings(back: 365, from: reference).count, 365)
        XCTAssertEqual(ZendureAppAPI.dateStrings(back: 0).count, 0)
    }

    func testAppDeviceDisplayName() {
        XCTAssertEqual(ZendureAppAPI.AppDevice(id: "1", idIsNumeric: true, snNumber: "SN", name: "Hub").displayName, "Hub")
        XCTAssertEqual(ZendureAppAPI.AppDevice(id: "1", idIsNumeric: true, snNumber: "SN", name: nil).displayName, "SN")
        XCTAssertEqual(ZendureAppAPI.AppDevice(id: "1", idIsNumeric: true, snNumber: nil, name: "").displayName, "1")
    }
}
