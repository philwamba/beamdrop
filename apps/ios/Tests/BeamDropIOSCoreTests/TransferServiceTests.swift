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
