import XCTest
@testable import BeamDropIOSCore

final class KeychainAndTrustTests: XCTestCase {
    func testInMemoryKeychainStoresAndDeletesSecret() throws {
        let store = InMemoryKeychainStore()
        try store.save(key: "private", data: Data("secret".utf8))

        XCTAssertEqual(try store.load(key: "private"), Data("secret".utf8))

        try store.delete(key: "private")
        XCTAssertNil(try store.load(key: "private"))
    }

    func testDeviceIdentityCreatesStableKeychainIdentity() throws {
        let keychain = InMemoryKeychainStore()
        let service = DeviceIdentityService(keychain: keychain)

        let first = try service.getOrCreate(deviceName: "Will's iPhone")
        let second = try service.getOrCreate(deviceName: "Will's iPhone")

        XCTAssertEqual(first.deviceId, second.deviceId)
        XCTAssertEqual(first.publicKey, second.publicKey)
        XCTAssertEqual(first.platform, .ios)
    }

    func testTrustedPeerApproveAndRevoke() throws {
        let repository = try TrustedPeerRepository(store: InMemoryTrustedPeerStore())
        let request = PairingRequest(
            remoteIdentity: DeviceIdentity(deviceId: "bd-android-01", deviceName: "Pixel", platform: .android, publicKey: "android-key"),
            endpoint: EndpointHint(host: "192.0.2.20", port: 49320),
            fingerprint: "AA:BB"
        )

        let peer = try repository.approve(request)
        XCTAssertTrue(peer.canTransfer(publicKey: "android-key"))

        try repository.revoke(deviceId: "bd-android-01")
        XCTAssertEqual(repository.peer(deviceId: "bd-android-01")?.trustState, .revoked)
        XCTAssertFalse(repository.peer(deviceId: "bd-android-01")!.canTransfer(publicKey: "android-key"))
    }
}
