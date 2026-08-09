import XCTest

final class DiscoveryTests: XCTestCase {
    private func sockaddrData(ipv4 text: String, port: UInt16 = 80) -> Data {
        var addr = sockaddr_in()
        addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = port.bigEndian
        inet_pton(AF_INET, text, &addr.sin_addr)
        return withUnsafeBytes(of: &addr) { Data($0) }
    }

    private func sockaddrDataIPv6() -> Data {
        var addr = sockaddr_in6()
        addr.sin6_len = UInt8(MemoryLayout<sockaddr_in6>.size)
        addr.sin6_family = sa_family_t(AF_INET6)
        return withUnsafeBytes(of: &addr) { Data($0) }
    }

    func testPicksFirstIPv4AndSkipsIPv6() {
        let addresses = [sockaddrDataIPv6(), sockaddrData(ipv4: "192.168.68.46"), sockaddrData(ipv4: "10.0.0.9")]
        XCTAssertEqual(DeviceDiscovery.ipv4Address(from: addresses), "192.168.68.46")
    }

    func testNoIPv4ReturnsNil() {
        XCTAssertNil(DeviceDiscovery.ipv4Address(from: [sockaddrDataIPv6()]))
        XCTAssertNil(DeviceDiscovery.ipv4Address(from: []))
        XCTAssertNil(DeviceDiscovery.ipv4Address(from: nil))
        // Données tronquées : ignorées proprement.
        XCTAssertNil(DeviceDiscovery.ipv4Address(from: [Data([0x10, 0x02])]))
    }
}
