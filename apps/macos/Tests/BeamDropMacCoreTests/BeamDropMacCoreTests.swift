import XCTest
@testable import BeamDropMacCore

final class BeamDropMacCoreTests: XCTestCase {
    func testPairingPayloadUsesSharedAndroidWindowsShape() throws {
        let identity = DeviceIdentity(
            deviceId: "macos-01",
            deviceName: "Fil's MacBook Pro",
            publicKey: "base64-public-key",
            fingerprint: "1111-2222-3333-4444"
        )
        let service = PairingService()
        let payload = service.generatePayload(
            identity: identity,
            endpoint: PairingEndpoint(host: "192.168.1.24", port: 49320),
            lifetime: 600
        )
        let json = try service.encodeForQR(payload)
        XCTAssertTrue(json.contains("\"protocolVersion\":\"1.0\""))
        XCTAssertTrue(json.contains("\"serviceName\":\"_beamdrop._tcp\""))
        XCTAssertTrue(json.contains("\"platform\":\"macos\""))

        let decoded = try service.importPayload(rawText: json)
        XCTAssertEqual(decoded.deviceId, "macos-01")
        XCTAssertEqual(decoded.endpoint?.port, 49320)
    }

    func testExpiredPairingPayloadRejected() throws {
        let payload = PairingPayload(
            pairingSessionId: "pair-expired",
            deviceId: "windows-01",
            deviceName: "Windows PC",
            platform: .windows,
            publicKey: "public",
            fingerprint: nil,
            endpoint: nil,
            expiresAtEpochMillis: 1
        )
        XCTAssertThrowsError(try PairingValidator.validate(payload)) { error in
            XCTAssertEqual(error as? BeamDropError, .expiredPairingPayload)
        }
    }

    func testTransferEnvelopeCodecMatchesMVPWireContract() throws {
        let envelope = TransferEnvelope(
            transferId: "transfer-123",
            transferType: .file,
            senderDeviceId: "macos-01",
            senderPublicKey: "public-key",
            receiverDeviceId: "windows-01",
            createdAt: "2026-07-06T12:00:00.000Z",
            payloadMetadata: PayloadMetadata(
                fileName: "Quarterly Report.pdf",
                mimeType: "application/pdf",
                sizeBytes: 9_000_000,
                sha256: "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
            )
        )

        let json = try TransferEnvelopeCodec.encode(envelope)
        XCTAssertTrue(json.contains("\"transferType\":\"FILE\""))
        XCTAssertTrue(json.contains("\"senderDeviceId\":\"macos-01\""))
        XCTAssertTrue(json.contains("\"payloadMetadata\""))
        XCTAssertTrue(json.contains("\"chunkSize\":4194304"))
        XCTAssertTrue(json.contains("\"totalChunks\":3"))

        let decoded = try TransferEnvelopeCodec.decode(json)
        XCTAssertEqual(decoded.transferType, .file)
        XCTAssertEqual(decoded.payloadMetadata.totalChunks, 3)
    }

    func testInvalidChunkMetadataRejected() {
        let envelope = TransferEnvelope(
            transferId: "bad-chunks",
            transferType: .file,
            senderDeviceId: "macos-01",
            senderPublicKey: "public-key",
            receiverDeviceId: "android-01",
            payloadMetadata: PayloadMetadata(
                fileName: "bad.bin",
                mimeType: "application/octet-stream",
                sizeBytes: 8,
                chunkSize: 4,
                totalChunks: 10,
                sha256: "abc"
            )
        )
        XCTAssertThrowsError(try TransferEnvelopeValidator.validate(envelope)) { error in
            XCTAssertEqual(error as? BeamDropError, .invalidChunkMetadata)
        }
    }

    func testChunkCalculationForSmallAndLargeFiles() {
        XCTAssertEqual(ChunkCalculator.totalChunks(sizeBytes: 10), 1)
        XCTAssertEqual(ChunkCalculator.totalChunks(sizeBytes: BeamDropProtocol.defaultChunkSizeBytes), 1)
        XCTAssertEqual(ChunkCalculator.totalChunks(sizeBytes: BeamDropProtocol.defaultChunkSizeBytes + 1), 2)

        let chunks = ChunkCalculator.chunks(sizeBytes: BeamDropProtocol.defaultChunkSizeBytes + 42)
        XCTAssertEqual(chunks.count, 2)
        XCTAssertEqual(chunks.last?.length, 42)
    }

    func testProgressCalculation() {
        XCTAssertEqual(ProgressCalculator.percent(bytesTransferred: 50, totalBytes: 100), 50)
        XCTAssertEqual(ProgressCalculator.percent(bytesTransferred: 150, totalBytes: 100), 100)
        XCTAssertEqual(ProgressCalculator.percent(bytesTransferred: 0, totalBytes: 0), 100)
    }

    func testSHA256Verification() {
        let data = Data("BeamDrop".utf8)
        let hash = SHA256Hashing.hash(data: data)
        XCTAssertTrue(SHA256Hashing.verify(data: data, expectedHex: hash))
        XCTAssertFalse(SHA256Hashing.verify(data: data, expectedHex: String(repeating: "0", count: 64)))
    }

    func testTrustedPeerApprovalAndRevocation() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let store = TrustedPeerStore(url: directory.appendingPathComponent("peers.json"))
        let payload = PairingPayload(
            pairingSessionId: "pair-android",
            deviceId: "android-01",
            deviceName: "Pixel 9",
            platform: .android,
            publicKey: "android-public",
            fingerprint: "aaaa-bbbb",
            endpoint: PairingEndpoint(host: "192.168.1.50", port: 49320),
            expiresAtEpochMillis: Date().addingTimeInterval(600).epochMillis
        )

        let peer = try store.approve(payload)
        XCTAssertEqual(peer.endpointHost, "192.168.1.50")
        XCTAssertNoThrow(try PeerTrustPolicy.requireTrusted(deviceId: "android-01", store: store))
        try store.revoke(deviceId: "android-01")
        XCTAssertThrowsError(try PeerTrustPolicy.requireTrusted(deviceId: "android-01", store: store)) { error in
            XCTAssertEqual(error as? BeamDropError, .revokedPeer("android-01"))
        }
    }

    func testUnknownPeerRejected() {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = TrustedPeerStore(url: directory.appendingPathComponent("peers.json"))
        XCTAssertThrowsError(try PeerTrustPolicy.requireTrusted(deviceId: "windows-unknown", store: store)) { error in
            XCTAssertEqual(error as? BeamDropError, .unknownPeer("windows-unknown"))
        }
    }

    func testClipboardPolicyRequiresUserControlledSharingAndBlocksSensitiveText() {
        XCTAssertThrowsNoError(try ClipboardPolicy.canSend(text: "hello", settings: ClipboardSettings(sharingEnabled: true)).get())
        XCTAssertThrowsError(try ClipboardPolicy.canSend(text: "hello", settings: ClipboardSettings(sharingEnabled: false)).get())
        XCTAssertThrowsError(try ClipboardPolicy.canSend(text: "api_key = abc123", settings: ClipboardSettings(sharingEnabled: true)).get())
    }
}
