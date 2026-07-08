import XCTest
@testable import BeamDropIOSCore

final class TransferServiceTests: XCTestCase {
    func testEnvelopeUsesSharedWireContract() throws {
        let payload = Data("hello".utf8)
        let envelope = TransferEnvelope(
            transferId: "tx-ios",
            transferType: .text,
            senderDeviceId: "bd-ios-01",
            senderPublicKey: "ios-public-key",
            receiverDeviceId: "bd-windows-01",
            createdAt: ISO8601DateFormatter().date(from: "2026-07-06T14:27:18Z")!,
            payloadMetadata: TransferPayloadMetadata(
                fileName: "Text",
                mimeType: "text/plain",
                sizeBytes: Int64(payload.count),
                sha256: Fingerprint.sha256Hex(data: payload)
            )
        )

        let encoded = try TransferEnvelopeCodec.encode(envelope)
        let decoded = try TransferEnvelopeCodec.decode(encoded)

        XCTAssertEqual(decoded.protocolVersion, "1.0")
        XCTAssertEqual(decoded.transferType, .text)
        XCTAssertEqual(decoded.payloadMetadata.chunkSize, BeamDropProtocol.defaultChunkSizeBytes)
        XCTAssertEqual(decoded.payloadMetadata.totalChunks, 1)
    }

    func testFinalHashVerificationWorks() throws {
        let payload = Data("received file".utf8)
        let peer = trustedPeer()
        let service = try transferService(peer: peer)
        let envelope = TransferEnvelope(
            transferId: "tx-1",
            transferType: .file,
            senderDeviceId: peer.deviceId,
            senderPublicKey: peer.publicKey,
            receiverDeviceId: "bd-ios",
            payloadMetadata: TransferPayloadMetadata(
                fileName: "notes.txt",
                mimeType: "text/plain",
                sizeBytes: Int64(payload.count),
                sha256: Fingerprint.sha256Hex(data: payload)
            )
        )

        let record = try service.verifyReceivedPayload(envelope: envelope, payload: payload, from: peer)

        XCTAssertEqual(record.status, .completed)
    }

    func testHashMismatchFails() throws {
        let peer = trustedPeer()
        let service = try transferService(peer: peer)
        let envelope = TransferEnvelope(
            transferId: "tx-1",
            transferType: .file,
            senderDeviceId: peer.deviceId,
            senderPublicKey: peer.publicKey,
            receiverDeviceId: "bd-ios",
            payloadMetadata: TransferPayloadMetadata(
                fileName: "notes.txt",
                mimeType: "text/plain",
                sizeBytes: 5,
                sha256: String(repeating: "0", count: 64)
            )
        )

        XCTAssertThrowsError(try service.verifyReceivedPayload(envelope: envelope, payload: Data("hello".utf8), from: peer)) { error in
            XCTAssertEqual(error as? TransferServiceError, .hashVerificationFailed)
        }
    }

    func testPathTraversalFileNameRejected() throws {
        let payload = Data("file payload".utf8)
        let envelope = TransferEnvelope(
            transferId: "tx-traversal",
            transferType: .file,
            senderDeviceId: "bd-ios-01",
            senderPublicKey: "ios-public-key",
            receiverDeviceId: "bd-android-01",
            payloadMetadata: TransferPayloadMetadata(
                fileName: "../secret.txt",
                mimeType: "text/plain",
                sizeBytes: Int64(payload.count),
                sha256: Fingerprint.sha256Hex(data: payload)
            )
        )

        XCTAssertThrowsError(try TransferEnvelopeCodec.validate(envelope)) { error in
            XCTAssertEqual(error as? TransferEnvelopeError, .invalidFileName)
        }
    }

    func testUnsafeReceivedFileNamesRejected() {
        let unsafeNames = [
            "../secret.txt",
            "..",
            ".",
            "",
            "   ",
            "/etc/passwd",
            "nested/../../escape.txt",
            "sub/dir.txt",
            "C:\\Windows\\System32\\evil.dll",
            "back\\slash.txt",
            "drive:colon.txt",
            "bell\u{0007}.txt",
            "newline\n.txt",
            "escape\u{001B}.txt"
        ]
        for name in unsafeNames {
            XCTAssertFalse(SafeTransferFileName.isSafe(name), "expected \(name.debugDescription) to be rejected")
        }

        let safeNames = ["notes.txt", "photo 2026.jpg", "über-report.pdf", "..hidden", "a..b.txt", "trailing."]
        for name in safeNames {
            XCTAssertTrue(SafeTransferFileName.isSafe(name), "expected \(name.debugDescription) to be accepted")
        }
    }

    func testEnvelopeEncryptionBlockRoundTrips() throws {
        let payload = Data("sealed".utf8)
        let ephemeralKeyHex = String(repeating: "ab", count: 32)
        let envelope = TransferEnvelope(
            transferId: "tx-encrypted",
            transferType: .file,
            senderDeviceId: "bd-ios-01",
            senderPublicKey: "ios-public-key",
            receiverDeviceId: "bd-android-01",
            encryption: TransferEncryption(ephemeralPublicKey: ephemeralKeyHex),
            payloadMetadata: TransferPayloadMetadata(
                fileName: "notes.txt",
                mimeType: "text/plain",
                sizeBytes: Int64(payload.count),
                sha256: Fingerprint.sha256Hex(data: payload)
            )
        )

        let decoded = try TransferEnvelopeCodec.decode(try TransferEnvelopeCodec.encode(envelope))

        XCTAssertEqual(decoded.encryption?.scheme, TransferEncryption.sessionV1Scheme)
        XCTAssertEqual(decoded.encryption?.ephemeralPublicKey, ephemeralKeyHex)
    }

    func testEnvelopeWithoutEncryptionBlockRemainsLegacyPlaintext() throws {
        let payload = Data("legacy".utf8)
        let envelope = TransferEnvelope(
            transferId: "tx-legacy",
            transferType: .text,
            senderDeviceId: "bd-ios-01",
            senderPublicKey: "ios-public-key",
            receiverDeviceId: "bd-android-01",
            payloadMetadata: TransferPayloadMetadata(
                fileName: "Text",
                mimeType: "text/plain",
                sizeBytes: Int64(payload.count),
                sha256: Fingerprint.sha256Hex(data: payload)
            )
        )

        let encoded = try TransferEnvelopeCodec.encode(envelope)
        XCTAssertFalse(String(decoding: encoded, as: UTF8.self).contains("encryption"))
        XCTAssertNil(try TransferEnvelopeCodec.decode(encoded).encryption)
    }

    func testEnvelopeRejectsUnknownEncryptionScheme() throws {
        var envelope = encryptedEnvelope()
        envelope.encryption = TransferEncryption(scheme: "ROT13", ephemeralPublicKey: String(repeating: "ab", count: 32))

        XCTAssertThrowsError(try TransferEnvelopeCodec.validate(envelope)) { error in
            XCTAssertEqual(error as? TransferEnvelopeError, .unsupportedEncryptionScheme)
        }
    }

    func testEnvelopeRejectsMalformedEphemeralKey() throws {
        for badKey in ["", "abcd", String(repeating: "zz", count: 32), String(repeating: "ab", count: 33)] {
            var envelope = encryptedEnvelope()
            envelope.encryption = TransferEncryption(ephemeralPublicKey: badKey)

            XCTAssertThrowsError(try TransferEnvelopeCodec.validate(envelope), badKey) { error in
                XCTAssertEqual(error as? TransferEnvelopeError, .invalidEphemeralPublicKey)
            }
        }
    }

    private func encryptedEnvelope() -> TransferEnvelope {
        let payload = Data("sealed".utf8)
        return TransferEnvelope(
            transferId: "tx-encrypted",
            transferType: .file,
            senderDeviceId: "bd-ios-01",
            senderPublicKey: "ios-public-key",
            receiverDeviceId: "bd-android-01",
            encryption: TransferEncryption(ephemeralPublicKey: String(repeating: "ab", count: 32)),
            payloadMetadata: TransferPayloadMetadata(
                fileName: "notes.txt",
                mimeType: "text/plain",
                sizeBytes: Int64(payload.count),
                sha256: Fingerprint.sha256Hex(data: payload)
            )
        )
    }

    func testUnknownAndRevokedPeersRejected() throws {
        let service = try transferService(peer: nil)
        XCTAssertThrowsError(try service.requireTrusted(deviceId: "unknown", publicKey: "key"))

        let revoked = trustedPeer(trustState: .revoked)
        let revokedService = try transferService(peer: revoked)
        XCTAssertThrowsError(try revokedService.requireTrusted(deviceId: revoked.deviceId, publicKey: revoked.publicKey)) { error in
            XCTAssertEqual(error as? TransferServiceError, .revokedPeer(revoked.deviceId))
        }
    }

    private func trustedPeer(trustState: TrustState = .trusted) -> TrustedPeer {
        TrustedPeer(
            deviceId: "bd-windows-01",
            deviceName: "Windows",
            platform: .windows,
            publicKey: "windows-public-key",
            fingerprint: "AA:BB",
            trustState: trustState,
            endpoint: EndpointHint(host: "192.0.2.44", port: 49320),
            trustedAt: Date(),
            revokedAt: trustState == .revoked ? Date() : nil,
            lastSeenAt: Date()
        )
    }

    private func transferService(peer: TrustedPeer?) throws -> TransferService {
        let peers = peer.map { [$0] } ?? []
        let trusted = try TrustedPeerRepository(store: InMemoryTrustedPeerStore(peers: peers))
        let history = try TransferHistoryRepository(store: InMemoryTransferHistoryStore())
        return TransferService(trustedPeers: trusted, history: history)
    }
}
