import XCTest
@testable import BeamDropIOSCore

/// One direction of an in-memory duplex byte stream.
private actor ByteStreamBuffer {
    private var buffer = Data()
    private var closed = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func write(_ data: Data) {
        buffer.append(data)
        resumeWaiters()
    }

    func close() {
        closed = true
        resumeWaiters()
    }

    func read(maxLength: Int) async -> Data? {
        while buffer.isEmpty {
            if closed { return nil }
            await withCheckedContinuation { waiters.append($0) }
        }
        let chunk = buffer.prefix(min(maxLength, buffer.count))
        buffer.removeFirst(chunk.count)
        return Data(chunk)
    }

    private func resumeWaiters() {
        let pending = waiters
        waiters = []
        pending.forEach { $0.resume() }
    }
}

/// In-memory `TransferConnecting` pair so transfers can be exercised without sockets.
private final class InMemoryTransferConnection: TransferConnecting {
    private let inbound: ByteStreamBuffer
    private let outbound: ByteStreamBuffer

    private init(inbound: ByteStreamBuffer, outbound: ByteStreamBuffer) {
        self.inbound = inbound
        self.outbound = outbound
    }

    static func pair() -> (InMemoryTransferConnection, InMemoryTransferConnection) {
        let aToB = ByteStreamBuffer()
        let bToA = ByteStreamBuffer()
        return (
            InMemoryTransferConnection(inbound: bToA, outbound: aToB),
            InMemoryTransferConnection(inbound: aToB, outbound: bToA)
        )
    }

    func send(_ data: Data) async throws {
        await outbound.write(data)
    }

    func receive(maxLength: Int) async throws -> Data? {
        await inbound.read(maxLength: maxLength)
    }

    func close() {
        let outbound = self.outbound
        Task { await outbound.close() }
    }
}

private struct InMemoryDialer: TransferDialing {
    let connection: InMemoryTransferConnection

    func connect(to endpoint: EndpointHint) async throws -> any TransferConnecting {
        connection
    }
}

@MainActor
final class ForegroundTransferTests: XCTestCase {
    private struct Device {
        let identity: DeviceIdentity
        let sessionSecretKey: Data
        let trustedPeers: TrustedPeerRepository
        let history: TransferHistoryRepository
        let receiveDirectory: URL

        @MainActor
        func coordinator(dialer: any TransferDialing) -> TransferCoordinator {
            TransferCoordinator(
                identity: identity,
                sessionSecretKey: sessionSecretKey,
                trustedPeers: trustedPeers,
                history: history,
                dialer: dialer,
                receiveDirectory: receiveDirectory
            )
        }
    }

    private func makeDevice(name: String) throws -> Device {
        let service = DeviceIdentityService(keychain: InMemoryKeychainStore())
        let identity = try service.getOrCreate(deviceName: name)
        return Device(
            identity: identity,
            sessionSecretKey: try service.sessionSecretKey(),
            trustedPeers: try TrustedPeerRepository(store: InMemoryTrustedPeerStore()),
            history: try TransferHistoryRepository(store: InMemoryTransferHistoryStore()),
            receiveDirectory: FileManager.default.temporaryDirectory
                .appendingPathComponent("beamdrop-tests-\(UUID().uuidString)", isDirectory: true)
        )
    }

    private func trust(_ remote: DeviceIdentity, in device: Device) throws -> TrustedPeer {
        try device.trustedPeers.approve(
            PairingRequest(
                remoteIdentity: remote,
                endpoint: EndpointHint(host: "192.0.2.10", port: BeamDropProtocol.defaultPort),
                fingerprint: Fingerprint.publicKeyFingerprint(remote.publicKey)
            )
        )
    }

    func testEncryptedTextTransferEndToEnd() async throws {
        let sender = try makeDevice(name: "iPhone A")
        let receiver = try makeDevice(name: "iPhone B")
        let receiverPeer = try trust(receiver.identity, in: sender)
        _ = try trust(sender.identity, in: receiver)

        let (senderEnd, receiverEnd) = InMemoryTransferConnection.pair()
        let senderCoordinator = sender.coordinator(dialer: InMemoryDialer(connection: senderEnd))
        let receiverCoordinator = receiver.coordinator(dialer: InMemoryDialer(connection: receiverEnd))

        async let receiving: Void = receiverCoordinator.handleIncomingConnection(receiverEnd)
        let record = await senderCoordinator.sendText("hello encrypted beam", to: receiverPeer)
        await receiving

        XCTAssertEqual(record?.status, .completed)
        XCTAssertEqual(senderCoordinator.history.first?.status, .completed)
        XCTAssertEqual(receiverCoordinator.receivedItems.first?.text, "hello encrypted beam")
        XCTAssertEqual(receiverCoordinator.history.first?.status, .completed)
        XCTAssertEqual(receiverCoordinator.history.first?.direction, .received)
        XCTAssertNil(receiverCoordinator.errorMessage)
    }

    func testEncryptedFileTransferEndToEndWritesVerifiedFile() async throws {
        let sender = try makeDevice(name: "iPhone A")
        let receiver = try makeDevice(name: "iPhone B")
        let receiverPeer = try trust(receiver.identity, in: sender)
        _ = try trust(sender.identity, in: receiver)

        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("beamdrop-send-\(UUID().uuidString).bin")
        let payload = Data((0..<200_000).map { UInt8(truncatingIfNeeded: $0) })
        try payload.write(to: fileURL)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let (senderEnd, receiverEnd) = InMemoryTransferConnection.pair()
        let senderCoordinator = sender.coordinator(dialer: InMemoryDialer(connection: senderEnd))
        let receiverCoordinator = receiver.coordinator(dialer: InMemoryDialer(connection: receiverEnd))

        async let receiving: Void = receiverCoordinator.handleIncomingConnection(receiverEnd)
        let record = await senderCoordinator.sendFile(at: fileURL, to: receiverPeer)
        await receiving

        XCTAssertEqual(record?.status, .completed)
        let receivedURL = try XCTUnwrap(receiverCoordinator.receivedItems.first?.fileURL)
        XCTAssertEqual(try Data(contentsOf: receivedURL), payload)
        XCTAssertEqual(receiverCoordinator.history.first?.status, .completed)
    }

    func testTamperedChunkFailsTransferAuthentication() async throws {
        let sender = try makeDevice(name: "iPhone A")
        let receiver = try makeDevice(name: "iPhone B")
        let receiverPeer = try trust(receiver.identity, in: sender)
        _ = try trust(sender.identity, in: receiver)

        let (senderEnd, receiverEnd) = InMemoryTransferConnection.pair()
        let receiverCoordinator = receiver.coordinator(dialer: InMemoryDialer(connection: receiverEnd))

        // Craft a valid encrypted envelope, then flip a ciphertext bit in flight.
        let payload = Data("secret payload".utf8)
        let transferId = "tx-tampered"
        let (encryption, session) = try TransferSessionResolver.initiate(
            identity: sender.identity,
            senderSecretKey: sender.sessionSecretKey,
            peer: receiverPeer,
            transferId: transferId
        )
        let envelope = TransferEnvelope(
            transferId: transferId,
            transferType: .text,
            senderDeviceId: sender.identity.deviceId,
            senderPublicKey: sender.identity.publicKey,
            receiverDeviceId: receiver.identity.deviceId,
            encryption: encryption,
            payloadMetadata: TransferPayloadMetadata(
                fileName: "BeamDrop Text",
                mimeType: "text/plain; charset=utf-8",
                sizeBytes: Int64(payload.count),
                sha256: Fingerprint.sha256Hex(data: payload)
            )
        )
        var sealed = try XCTUnwrap(session).sealChunk(index: 0, plaintext: payload)
        sealed[sealed.count - 1] ^= 0xFF

        async let receiving: Void = receiverCoordinator.handleIncomingConnection(receiverEnd)
        try await senderEnd.send(try TransferEnvelopeCodec.encodeLine(envelope))
        try await senderEnd.send(TransferWire.encodeFrame(sealed))
        await receiving

        XCTAssertTrue(receiverCoordinator.receivedItems.isEmpty)
        XCTAssertEqual(receiverCoordinator.history.first?.status, .corrupted)
        XCTAssertNotNil(receiverCoordinator.errorMessage)
    }

    func testLegacyPlaintextEnvelopeStillReceived() async throws {
        let receiver = try makeDevice(name: "iPhone B")
        let legacyIdentity = DeviceIdentity(
            deviceId: "bd-legacy-01",
            deviceName: "Old Laptop",
            platform: .windows,
            publicKey: "legacy-opaque-key"
        )
        _ = try trust(legacyIdentity, in: receiver)

        let (senderEnd, receiverEnd) = InMemoryTransferConnection.pair()
        let receiverCoordinator = receiver.coordinator(dialer: InMemoryDialer(connection: receiverEnd))

        let payload = Data("plain legacy text".utf8)
        let envelope = TransferEnvelope(
            transferId: "tx-legacy",
            transferType: .text,
            senderDeviceId: legacyIdentity.deviceId,
            senderPublicKey: legacyIdentity.publicKey,
            receiverDeviceId: receiver.identity.deviceId,
            payloadMetadata: TransferPayloadMetadata(
                fileName: "BeamDrop Text",
                mimeType: "text/plain; charset=utf-8",
                sizeBytes: Int64(payload.count),
                sha256: Fingerprint.sha256Hex(data: payload)
            )
        )

        async let receiving: Void = receiverCoordinator.handleIncomingConnection(receiverEnd)
        try await senderEnd.send(try TransferEnvelopeCodec.encodeLine(envelope))
        try await senderEnd.send(payload)
        await receiving

        XCTAssertEqual(receiverCoordinator.receivedItems.first?.text, "plain legacy text")
        XCTAssertEqual(receiverCoordinator.history.first?.status, .completed)
    }

    func testUntrustedSenderIsRejectedBeforePayload() async throws {
        let receiver = try makeDevice(name: "iPhone B")
        let (senderEnd, receiverEnd) = InMemoryTransferConnection.pair()
        let receiverCoordinator = receiver.coordinator(dialer: InMemoryDialer(connection: receiverEnd))

        let payload = Data("nope".utf8)
        let envelope = TransferEnvelope(
            transferId: "tx-unknown",
            transferType: .text,
            senderDeviceId: "bd-unknown-01",
            senderPublicKey: "unknown-key",
            receiverDeviceId: receiver.identity.deviceId,
            payloadMetadata: TransferPayloadMetadata(
                fileName: "BeamDrop Text",
                mimeType: "text/plain; charset=utf-8",
                sizeBytes: Int64(payload.count),
                sha256: Fingerprint.sha256Hex(data: payload)
            )
        )

        async let receiving: Void = receiverCoordinator.handleIncomingConnection(receiverEnd)
        try await senderEnd.send(try TransferEnvelopeCodec.encodeLine(envelope))
        await receiving

        XCTAssertTrue(receiverCoordinator.receivedItems.isEmpty)
        XCTAssertTrue(receiverCoordinator.history.isEmpty)
        XCTAssertNotNil(receiverCoordinator.errorMessage)
    }

    func testEngineSealsEveryChunkAcrossMultipleChunks() async throws {
        let sender = try makeDevice(name: "iPhone A")
        let receiver = try makeDevice(name: "iPhone B")

        let payload = Data((0..<50).map { UInt8($0) })
        let chunkSize = 16
        let transferId = "tx-multichunk"
        let context = TransferSessionContext(
            senderDeviceId: sender.identity.deviceId,
            receiverDeviceId: receiver.identity.deviceId,
            transferId: transferId
        )
        let (ephemeralPublicKey, senderSession) = try TransferSession.initiate(
            senderSecretKey: sender.sessionSecretKey,
            receiverPublicKey: try X25519KeyCodec.rawKey(fromBase64SPKI: receiver.identity.publicKey),
            context: context
        )
        let receiverSession = try TransferSession.accept(
            receiverSecretKey: receiver.sessionSecretKey,
            senderPublicKey: try X25519KeyCodec.rawKey(fromBase64SPKI: sender.identity.publicKey),
            ephemeralPublicKey: ephemeralPublicKey,
            context: context
        )

        let envelope = TransferEnvelope(
            transferId: transferId,
            transferType: .file,
            senderDeviceId: sender.identity.deviceId,
            senderPublicKey: sender.identity.publicKey,
            receiverDeviceId: receiver.identity.deviceId,
            encryption: TransferEncryption(ephemeralPublicKey: HexEncoding.hex(from: ephemeralPublicKey)),
            payloadMetadata: TransferPayloadMetadata(
                fileName: "multi.bin",
                mimeType: "application/octet-stream",
                sizeBytes: Int64(payload.count),
                chunkSize: chunkSize,
                sha256: Fingerprint.sha256Hex(data: payload)
            )
        )
        XCTAssertEqual(envelope.payloadMetadata.totalChunks, 4)

        let (senderEnd, receiverEnd) = InMemoryTransferConnection.pair()
        let reader = TransferStreamReader(connection: receiverEnd)
        async let received = { () async throws -> Data in
            let line = try await reader.readEnvelopeLine()
            let decoded = try TransferEnvelopeCodec.decode(line)
            return try await ForegroundTransferEngine.receive(envelope: decoded, session: receiverSession, reader: reader)
        }()

        try await ForegroundTransferEngine.send(payload: .data(payload), envelope: envelope, session: senderSession, over: senderEnd)

        let receivedPayload = try await received
        XCTAssertEqual(receivedPayload, payload)
    }
}
