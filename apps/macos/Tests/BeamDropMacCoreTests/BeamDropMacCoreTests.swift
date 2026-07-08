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
        let ephemeralPublicKeyHex = "ff2ee45601ec1b67310c7790404585ae697331eee1c1f8cf2419731c1fff3e6b"
        let envelope = TransferEnvelope(
            transferId: "transfer-123",
            transferType: .file,
            senderDeviceId: "macos-01",
            senderPublicKey: "public-key",
            receiverDeviceId: "windows-01",
            createdAt: "2026-07-06T12:00:00.000Z",
            encryption: TransferEncryption(ephemeralPublicKey: ephemeralPublicKeyHex),
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
        XCTAssertTrue(json.contains("\"encryption\":{\"ephemeralPublicKey\":\"\(ephemeralPublicKeyHex)\",\"scheme\":\"BEAMDROP_SESSION_V1\"}"))

        let decoded = try TransferEnvelopeCodec.decode(json)
        XCTAssertEqual(decoded.transferType, .file)
        XCTAssertEqual(decoded.payloadMetadata.totalChunks, 3)
        XCTAssertEqual(decoded.encryption, TransferEncryption(scheme: "BEAMDROP_SESSION_V1", ephemeralPublicKey: ephemeralPublicKeyHex))
    }

    func testTransferEnvelopeWithoutEncryptionRemainsLegacyCompatible() throws {
        let envelope = TransferEnvelope(
            transferId: "transfer-legacy",
            transferType: .text,
            senderDeviceId: "macos-01",
            senderPublicKey: "public-key",
            receiverDeviceId: "android-01",
            payloadMetadata: PayloadMetadata(
                fileName: "BeamDrop Text",
                mimeType: "text/plain; charset=utf-8",
                sizeBytes: 5,
                sha256: nil
            )
        )
        let json = try TransferEnvelopeCodec.encode(envelope)
        XCTAssertFalse(json.contains("\"encryption\""))
        XCTAssertNil(try TransferEnvelopeCodec.decode(json).encryption)
    }

    func testInvalidEncryptionMetadataRejected() {
        var envelope = TransferEnvelope(
            transferId: "transfer-bad-crypto",
            transferType: .file,
            senderDeviceId: "macos-01",
            senderPublicKey: "public-key",
            receiverDeviceId: "windows-01",
            encryption: TransferEncryption(scheme: "BEAMDROP_SESSION_V2", ephemeralPublicKey: String(repeating: "ab", count: 32)),
            payloadMetadata: PayloadMetadata(
                fileName: "report.pdf",
                mimeType: "application/pdf",
                sizeBytes: 10,
                sha256: String(repeating: "0", count: 64)
            )
        )
        XCTAssertThrowsError(try TransferEnvelopeValidator.validate(envelope)) { error in
            XCTAssertEqual(error as? BeamDropError, .invalidEncryptionMetadata("Unsupported scheme BEAMDROP_SESSION_V2."))
        }

        envelope.encryption = TransferEncryption(ephemeralPublicKey: "not-hex")
        XCTAssertThrowsError(try TransferEnvelopeValidator.validate(envelope)) { error in
            XCTAssertEqual(error as? BeamDropError, .invalidEncryptionMetadata("ephemeralPublicKey must be 64 hex characters."))
        }
    }

    func testReceivedFileNameValidationRejectsPathTraversal() {
        let rejected = [
            "../secret.txt",
            "..",
            ".",
            "/etc/passwd",
            "..\\windows\\system32",
            "notes\\evil.txt",
            "backup:2026",
            "file\u{0000}name",
            "file\u{001F}.txt",
            "\u{0007}bell.txt",
            "   "
        ]
        for name in rejected {
            XCTAssertFalse(FileNameValidator.isSafe(name), "expected \(name.debugDescription) to be rejected")
        }
        XCTAssertTrue(FileNameValidator.isSafe("Quarterly Report.pdf"))
        XCTAssertTrue(FileNameValidator.isSafe("..hidden-but-safe"))
    }

    func testEnvelopeWithTraversalFileNameRejectedOnDecode() throws {
        for fileName in ["../secret.txt", "..", "/etc/passwd", "C:\\Users\\victim", "nul\u{0001}.bin"] {
            let envelope = TransferEnvelope(
                transferId: "transfer-traversal",
                transferType: .file,
                senderDeviceId: "macos-01",
                senderPublicKey: "public-key",
                receiverDeviceId: "windows-01",
                payloadMetadata: PayloadMetadata(
                    fileName: fileName,
                    mimeType: "application/octet-stream",
                    sizeBytes: 10,
                    sha256: String(repeating: "0", count: 64)
                )
            )
            let json = String(decoding: try BeamDropJSON.encoder.encode(envelope), as: UTF8.self)
            XCTAssertThrowsError(try TransferEnvelopeCodec.decode(json), fileName.debugDescription) { error in
                XCTAssertEqual(error as? BeamDropError, .invalidFileName)
            }
        }
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
        XCTAssertNoThrow(try ClipboardPolicy.canSend(text: "hello", settings: ClipboardSettings(sharingEnabled: true)).get())
        XCTAssertThrowsError(try ClipboardPolicy.canSend(text: "hello", settings: ClipboardSettings(sharingEnabled: false)).get())
        XCTAssertThrowsError(try ClipboardPolicy.canSend(text: "api_key = abc123", settings: ClipboardSettings(sharingEnabled: true)).get())
    }
}
