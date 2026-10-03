import XCTest

final class DeviceCombineTests: XCTestCase {
    private func device(sn: String, solar: Double, soc: Double?, packs: Int,
                        home: Double = 0, grid: Double = 0,
                        packIn: Double = 0, packOut: Double = 0, offGrid: Double = 0,
                        at date: Date = Date(timeIntervalSince1970: 1_000)) -> DeviceState {
        var state = DeviceState()
        state.serialNumber = sn
        state.solarInputPower = solar
        state.solarChannels = [solar / 2, solar / 2]
        state.electricLevel = soc
        state.outputHomePower = home
        state.gridInputPower = grid
        state.packInputPower = packIn
        state.outputPackPower = packOut
        state.offGridPower = offGrid
        state.packs = (0..<packs).map { PackInfo(serialNumber: "\(sn)-P\($0)", socLevel: soc, temperature: 30, power: 10) }
        state.acMode = 2
        state.inputLimit = 1200
        state.outputLimit = 800
        state.deviceTemperature = 35
        state.remainOutMinutes = 300
        state.rssi = -50
        state.batteryVoltage = 51.8
        state.socMax = 100
        state.socMin = 10
        state.gridReverse = 2
        state.updatedAt = date
        return state
    }

    func testEmptyIsNil() {
        XCTAssertNil(DeviceState.combine([]))
    }

    /// Invariant : un utilisateur à un seul appareil ne voit rien changer.
    func testSingleDeviceIsUnchanged() throws {
        let one = device(sn: "A", solar: 496, soc: 44, packs: 2, home: 120, packOut: 376)
        let combined = try XCTUnwrap(DeviceState.combine([one]))
        XCTAssertEqual(combined.serialNumber, "A")
        XCTAssertEqual(combined.solarChannels, one.solarChannels)
        XCTAssertEqual(combined.acMode, 2)
        XCTAssertEqual(combined.outputLimit, 800)
        XCTAssertEqual(combined.socMax, 100)
        XCTAssertEqual(combined.remainOutMinutes, 300)
        XCTAssertEqual(combined.electricLevel, 44)
        XCTAssertEqual(combined.packs.count, 2)
    }

    func testPowersAreSummed() throws {
        let a = device(sn: "A", solar: 496, soc: 44, packs: 2, home: 100, grid: 5, packIn: 0, packOut: 396, offGrid: 30)
        let b = device(sn: "B", solar: 489, soc: 96, packs: 2, home: 200, grid: 0, packIn: 50, packOut: 339, offGrid: 0)
        let combined = try XCTUnwrap(DeviceState.combine([a, b]))
        XCTAssertEqual(combined.solarInputPower, 985)
        XCTAssertEqual(combined.outputHomePower, 300)
        XCTAssertEqual(combined.gridInputPower, 5)
        XCTAssertEqual(combined.packInputPower, 50)
        XCTAssertEqual(combined.outputPackPower, 735)
        XCTAssertEqual(combined.offGridPower, 30)
        XCTAssertEqual(combined.batteryFlow, 685)
        XCTAssertEqual(combined.packs.map { $0.serialNumber }, ["A-P0", "A-P1", "B-P0", "B-P1"])
    }

    /// SOC pondéré par le nombre de packs (packs supposés de même capacité).
    func testSocWeightedByPackCount() throws {
        let a = device(sn: "A", solar: 0, soc: 40, packs: 1)
        let b = device(sn: "B", solar: 0, soc: 100, packs: 3)
        let combined = try XCTUnwrap(DeviceState.combine([a, b]))
        XCTAssertEqual(try XCTUnwrap(combined.electricLevel), 85, accuracy: 0.001)
    }

    func testSocIgnoresDevicesWithoutLevel() throws {
        let a = device(sn: "A", solar: 0, soc: nil, packs: 2)
        let b = device(sn: "B", solar: 0, soc: 70, packs: 2)
        XCTAssertEqual(DeviceState.combine([a, b])?.electricLevel, 70)
        XCTAssertNil(DeviceState.combine([a, a])?.electricLevel)
    }

    /// Les valeurs propres à un appareil n'ont pas de sens sur l'agrégat —
    /// surtout le SN, qui ne doit jamais servir à piloter une batterie.
    func testDeviceSpecificFieldsAreDropped() throws {
        let a = device(sn: "A", solar: 496, soc: 44, packs: 2)
        let b = device(sn: "B", solar: 489, soc: 96, packs: 2)
        let combined = try XCTUnwrap(DeviceState.combine([a, b]))
        XCTAssertNil(combined.serialNumber)
        XCTAssertEqual(combined.solarChannels, [])
        XCTAssertNil(combined.acMode)
        XCTAssertNil(combined.inputLimit)
        XCTAssertNil(combined.outputLimit)
        XCTAssertNil(combined.deviceTemperature)
        XCTAssertNil(combined.remainOutMinutes)
        XCTAssertNil(combined.rssi)
        XCTAssertNil(combined.batteryVoltage)
        XCTAssertNil(combined.socMax)
        XCTAssertNil(combined.socMin)
        XCTAssertNil(combined.gridReverse)
    }

    /// L'agrégat est aussi vieux que sa mesure la plus ancienne.
    func testUpdatedAtIsOldest() throws {
        let a = device(sn: "A", solar: 0, soc: 50, packs: 1, at: Date(timeIntervalSince1970: 2_000))
        let b = device(sn: "B", solar: 0, soc: 50, packs: 1, at: Date(timeIntervalSince1970: 1_500))
        XCTAssertEqual(DeviceState.combine([a, b])?.updatedAt, Date(timeIntervalSince1970: 1_500))
    }
}
