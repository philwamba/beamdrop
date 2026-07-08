import Foundation

/// Payload bytes for an outgoing transfer, either in memory or streamed from disk.
public enum TransferPayloadSource: Sendable {
    case data(Data)
    case file(URL)

    public func sizeBytes() throws -> Int64 {
        switch self {
        case .data(let data):
            return Int64(data.count)
        case .file(let url):
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            return (attributes[.size] as? NSNumber)?.int64Value ?? 0
        }
    }

    public func sha256Hex() throws -> String {
        switch self {
        case .data(let data): Fingerprint.sha256Hex(data: data)
        case .file(let url): try Fingerprint.sha256Hex(fileURL: url)
        }
    }
}

/// Derives the per-transfer session on both sides of the wire. Senders fall back
/// to legacy plaintext only when the paired peer key predates X25519 pairing;
/// receivers always honor whatever the validated envelope declares.
public enum TransferSessionResolver {
    /// Sender side. Returns the envelope encryption block plus the sealing session,
    /// or `(nil, nil)` when the peer's stored key cannot support session encryption.
    public static func initiate(
        identity: DeviceIdentity,
        senderSecretKey: Data,
        peer: TrustedPeer,
        transferId: String
    ) throws -> (encryption: TransferEncryption?, session: TransferSession?) {
        guard X25519KeyCodec.isBase64SPKI(peer.publicKey) else { return (nil, nil) }
        let receiverPublicKey = try X25519KeyCodec.rawKey(fromBase64SPKI: peer.publicKey)
        let context = TransferSessionContext(
            senderDeviceId: identity.deviceId,
            receiverDeviceId: peer.deviceId,
            transferId: transferId
        )
        let (ephemeralPublicKey, session) = try TransferSession.initiate(
            senderSecretKey: senderSecretKey,
            receiverPublicKey: receiverPublicKey,
            context: context
        )
        return (TransferEncryption(ephemeralPublicKey: HexEncoding.hex(from: ephemeralPublicKey)), session)
    }

    /// Receiver side. Returns nil for legacy plaintext envelopes. The sender's
    /// static public key always comes from the trusted-peer store, never the wire.
    public static func accept(
        envelope: TransferEnvelope,
        peer: TrustedPeer,
        receiverSecretKey: Data
    ) throws -> TransferSession? {
        guard let encryption = envelope.encryption else { return nil }
        guard encryption.scheme == TransferEncryption.sessionV1Scheme else { throw TransferEnvelopeError.unsupportedEncryptionScheme }
        guard let ephemeralPublicKey = HexEncoding.data(fromHex: encryption.ephemeralPublicKey), ephemeralPublicKey.count == TransferSession.keyLength else {
            throw TransferEnvelopeError.invalidEphemeralPublicKey
        }
        let senderPublicKey = try X25519KeyCodec.rawKey(fromBase64SPKI: peer.publicKey)
        let context = TransferSessionContext(
            senderDeviceId: envelope.senderDeviceId,
            receiverDeviceId: envelope.receiverDeviceId,
            transferId: envelope.transferId
        )
        return try TransferSession.accept(
            receiverSecretKey: receiverSecretKey,
            senderPublicKey: senderPublicKey,
            ephemeralPublicKey: ephemeralPublicKey,
            context: context
        )
    }
}

/// Runs one foreground transfer over an established connection. Chunks are sealed
/// per the session protocol when a session is present; legacy transfers stream the
/// raw payload bytes exactly as older BeamDrop builds do.
public enum ForegroundTransferEngine {
    public static func send(
        payload: TransferPayloadSource,
        envelope: TransferEnvelope,
        session: TransferSession?,
        over connection: any TransferConnecting,
        onBytesSent: @escaping @Sendable (Int64) -> Void = { _ in }
    ) async throws {
        try await connection.send(try TransferEnvelopeCodec.encodeLine(envelope))

        let metadata = envelope.payloadMetadata
        var handle: FileHandle?
        if case .file(let url) = payload {
            handle = try FileHandle(forReadingFrom: url)
        }
        defer { try? handle?.close() }

        var bytesSent: Int64 = 0
        for chunkIndex in 0..<metadata.totalChunks {
            try Task.checkCancellation()
            let chunk = try nextChunk(payload: payload, handle: handle, metadata: metadata, chunkIndex: chunkIndex)
            if let session {
                let sealed = try session.sealChunk(index: chunkIndex, plaintext: chunk)
                try await connection.send(TransferWire.encodeFrame(sealed))
            } else if !chunk.isEmpty {
                try await connection.send(chunk)
            }
            bytesSent += Int64(chunk.count)
            onBytesSent(bytesSent)
        }
    }

    public static func receive(
        envelope: TransferEnvelope,
        session: TransferSession?,
        reader: TransferStreamReader,
        onBytesReceived: @escaping @Sendable (Int64) -> Void = { _ in }
    ) async throws -> Data {
        let metadata = envelope.payloadMetadata
        guard let session else {
            // Legacy plaintext peer: SHA-256 integrity only.
            var payload = Data()
            let readChunk = 64 * 1024
            while payload.count < Int(metadata.sizeBytes) {
                try Task.checkCancellation()
                let remaining = Int(metadata.sizeBytes) - payload.count
                payload.append(try await reader.read(exactly: min(readChunk, remaining)))
                onBytesReceived(Int64(payload.count))
            }
            return payload
        }

        var payload = Data()
        for chunkIndex in 0..<metadata.totalChunks {
            try Task.checkCancellation()
            let sealed = try await reader.readFrame()
            let plaintext = try session.openChunk(index: chunkIndex, sealed: sealed)
            payload.append(plaintext)
            onBytesReceived(Int64(payload.count))
        }
        return payload
    }

    private static func nextChunk(
        payload: TransferPayloadSource,
        handle: FileHandle?,
        metadata: TransferPayloadMetadata,
        chunkIndex: Int64
    ) throws -> Data {
        let offset = chunkIndex * Int64(metadata.chunkSize)
        let length = Int(min(Int64(metadata.chunkSize), metadata.sizeBytes - offset))
        guard length >= 0 else { return Data() }
        switch payload {
        case .data(let data):
            guard offset <= Int64(data.count) else { return Data() }
            return data.subdata(in: Int(offset)..<Int(offset) + min(length, data.count - Int(offset)))
        case .file:
            guard let handle else { return Data() }
            try handle.seek(toOffset: UInt64(offset))
            return try handle.read(upToCount: max(length, 0)) ?? Data()
        }
    }
}
