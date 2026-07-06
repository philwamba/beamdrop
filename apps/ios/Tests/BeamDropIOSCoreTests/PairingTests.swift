import XCTest
@testable import BeamDropIOSCore

final class PairingTests: XCTestCase {
    func testDecodesAndroidWindowsCompatiblePairingPayload() throws {
        let raw = """
        {
          "type": "beamdrop_pairing",
          "protocolVersion": "1.0",
          "serviceName": "_beamdrop._tcp",
          "pairingSessionId": "pair-1",
          "deviceId": "bd-windows-01",
          "deviceName": "Windows Workstation",
          "platform": "windows",
          "publicKey": "windows-public-key",
          "endpoint": { "host": "192.0.2.44", "port": 49320, "route": "local" },
          "expiresAtEpochMillis": 1783350000000
        }
        """

        let request = try PairingValidator(
            now: { Date(timeIntervalSince1970: 1_783_000_000) },
            trustLookup: { _, _ in .unknown }
        ).validate(rawPayload: raw)

        XCTAssertEqual(request.remoteIdentity.deviceId, "bd-windows-01")
        XCTAssertEqual(request.remoteIdentity.platform, .windows)
        XCTAssertEqual(request.endpoint?.port, 49320)
    }

    func testRejectsRevokedPeerDuringPairingValidation() throws {
        let payload = PairingQRPayload(
            pairingSessionId: "pair-1",
            deviceId: "bd-android-01",
            deviceName: "Pixel",
            platform: .android,
            publicKey: "android-public-key",
            endpoint: nil,
            expiresAtEpochMillis: 1783350000000
        )

        XCTAssertThrowsError(try PairingValidator(
            now: { Date(timeIntervalSince1970: 1_783_000_000) },
            trustLookup: { _, _ in .revoked }
        ).validate(rawPayload: try PairingCodec.encode(payload))) { error in
            XCTAssertEqual(error as? PairingError, .previouslyRevoked)
        }
    }
}
