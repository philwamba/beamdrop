import XCTest
@testable import BeamDropIOSCore

@MainActor
final class ViewModelTests: XCTestCase {
    func testPairDeviceViewModelCreatesQrAndApprovesPeer() throws {
        let repository = try TrustedPeerRepository(store: InMemoryTrustedPeerStore())
        let identity = DeviceIdentity(deviceId: "bd-ios-01", deviceName: "iPhone", platform: .ios, publicKey: "ios-public")
        let model = PairDeviceViewModel(identity: identity, endpoint: EndpointHint(host: "192.0.2.10", port: 49320), repository: repository)

        XCTAssertFalse(model.qrPayload.isEmpty)

        let remote = PairingQRPayload(
            pairingSessionId: "pair-remote",
            deviceId: "bd-windows-01",
            deviceName: "Windows",
            platform: .windows,
            publicKey: "windows-public",
            endpoint: EndpointHint(host: "192.0.2.44", port: 49320),
            expiresAtEpochMillis: Int64(Date().addingTimeInterval(300).timeIntervalSince1970 * 1000)
        )
        model.importScannedPayload(try PairingCodec.encode(remote))
        XCTAssertNotNil(model.pendingRequest)

        model.approvePending()
        XCTAssertEqual(repository.peer(deviceId: "bd-windows-01")?.trustState, .trusted)
    }

    func testTransferProgressViewModelCancellation() throws {
        let history = try TransferHistoryRepository(store: InMemoryTransferHistoryStore())
        let model = TransferProgressViewModel(historyRepository: history)
        model.progress = TransferProgressState(transferId: "tx-1", currentItem: "movie.mov", bytesTransferred: 10, totalBytes: 100, status: .transferring)

        model.cancelCurrentTransfer()

        XCTAssertEqual(model.progress?.status, .cancelled)
    }
}
