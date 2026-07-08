import Foundation
import Network

public struct TransferEndpoint: Equatable, Sendable {
    public let host: String
    public let port: Int

    public init(host: String, port: Int = BeamDropProtocol.defaultTransferPort) {
        self.host = host
        self.port = port
    }
}

public struct TransferProgress: Equatable, Sendable {
    public let transferId: String
    public let status: TransferStatus
    public let bytesTransferred: Int64
    public let totalBytes: Int64
    public let percent: Double
    public let speedBytesPerSecond: Double
    public let fileName: String
    public let peerDeviceName: String

    public init(
        transferId: String,
        status: TransferStatus,
        bytesTransferred: Int64,
        totalBytes: Int64,
        percent: Double,
        speedBytesPerSecond: Double,
        fileName: String,
        peerDeviceName: String
    ) {
        self.transferId = transferId
        self.status = status
        self.bytesTransferred = bytesTransferred
        self.totalBytes = totalBytes
        self.percent = percent
        self.speedBytesPerSecond = speedBytesPerSecond
        self.fileName = fileName
        self.peerDeviceName = peerDeviceName
    }
}

public typealias TransferProgressHandler = @Sendable (TransferProgress) -> Void
public typealias ReceiveApprovalHandler = @Sendable (TransferEnvelope, TrustedPeer) -> Bool

public final class TransferService {
    private let identity: DeviceIdentity
    private let sessionPrivateKey: Data?
    private let peerStore: TrustedPeerStore
    private let historyStore: TransferHistoryStore
    private let auditLog: AuditLog
    private let queue = DispatchQueue(label: "com.beamdrop.mac.transfer")
    private var cancelledTransferIds = Set<String>()
    private let lock = NSLock()

    public init(
        identity: DeviceIdentity,
        sessionPrivateKey: Data? = nil,
        peerStore: TrustedPeerStore,
        historyStore: TransferHistoryStore,
        auditLog: AuditLog
    ) {
        self.identity = identity
        self.sessionPrivateKey = sessionPrivateKey
        self.peerStore = peerStore
        self.historyStore = historyStore
        self.auditLog = auditLog
    }

    public func cancel(transferId: String) {
        _ = lock.withLock { cancelledTransferIds.insert(transferId) }
    }

    public func sendText(_ text: String, to peer: TrustedPeer, progress: TransferProgressHandler? = nil) throws {
        let data = Data(text.utf8)
        let envelope = TransferEnvelope(
            transferId: UUID().uuidString,
            transferType: .text,
            senderDeviceId: identity.deviceId,
            senderPublicKey: identity.publicKey,
            receiverDeviceId: peer.deviceId,
            payloadMetadata: PayloadMetadata(
                fileName: "BeamDrop Text",
                mimeType: "text/plain; charset=utf-8",
                sizeBytes: Int64(data.count),
                sha256: SHA256Hashing.hash(data: data)
            )
        )
        try send(data: data, envelope: envelope, to: peer, progress: progress)
    }

    public func sendClipboardText(_ text: String, to peer: TrustedPeer, settings: ClipboardSettings, progress: TransferProgressHandler? = nil) throws {
        switch ClipboardPolicy.canSend(text: text, settings: settings) {
        case .success:
            let data = Data(text.utf8)
            let envelope = TransferEnvelope(
                transferId: UUID().uuidString,
                transferType: .clipboardText,
                senderDeviceId: identity.deviceId,
                senderPublicKey: identity.publicKey,
                receiverDeviceId: peer.deviceId,
                payloadMetadata: PayloadMetadata(
                    fileName: "Clipboard Text",
                    mimeType: "text/plain; charset=utf-8",
                    sizeBytes: Int64(data.count),
                    sha256: SHA256Hashing.hash(data: data)
                )
            )
            try send(data: data, envelope: envelope, to: peer, progress: progress)
        case .failure(let error):
            throw error
        }
    }

    public func sendFile(_ fileURL: URL, to peer: TrustedPeer, progress: TransferProgressHandler? = nil) throws {
        let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey, .nameKey, .contentTypeKey])
        guard resourceValues.isRegularFile == true else {
            throw BeamDropError.fileAccessFailed("Only regular files can be sent in the MVP.")
        }
        let size = Int64(resourceValues.fileSize ?? 0)
        let sha256 = try SHA256Hashing.hash(fileURL: fileURL)
        let envelope = TransferEnvelope(
            transferId: UUID().uuidString,
            transferType: .file,
            senderDeviceId: identity.deviceId,
            senderPublicKey: identity.publicKey,
            receiverDeviceId: peer.deviceId,
            payloadMetadata: PayloadMetadata(
                fileName: resourceValues.name ?? fileURL.lastPathComponent,
                mimeType: resourceValues.contentType?.preferredMIMEType ?? "application/octet-stream",
                sizeBytes: size,
                sha256: sha256
            )
        )
        try send(fileURL: fileURL, envelope: envelope, to: peer, progress: progress)
    }

    private func send(data: Data, envelope: TransferEnvelope, to peer: TrustedPeer, progress: TransferProgressHandler?) throws {
        try requireSendAllowed(peer)
        var envelope = envelope
        let session = try initiateSession(for: &envelope, peer: peer)
        try record(envelope: envelope, peer: peer, direction: .sent, status: .queued)
        let endpoint = try endpoint(for: peer)
        let connection = try connect(to: endpoint)
        defer { connection.cancel() }

        let header = try TransferEnvelopeCodec.encode(envelope) + "\n"
        try sendData(Data(header.utf8), on: connection)
        if let session {
            for chunk in ChunkCalculator.chunks(sizeBytes: envelope.payloadMetadata.sizeBytes, chunkSize: envelope.payloadMetadata.chunkSize) {
                let plaintext = data.subdata(in: Int(chunk.offset)..<Int(chunk.offset + chunk.length))
                try sendData(Self.frameSealed(session.sealChunk(plaintext, index: chunk.index)), on: connection)
            }
        } else {
            try sendData(data, on: connection)
        }
        try finishSend(envelope: envelope, peer: peer, bytes: Int64(data.count), progress: progress)
    }

    private func send(fileURL: URL, envelope: TransferEnvelope, to peer: TrustedPeer, progress: TransferProgressHandler?) throws {
        try requireSendAllowed(peer)
        var envelope = envelope
        let session = try initiateSession(for: &envelope, peer: peer)
        try record(envelope: envelope, peer: peer, direction: .sent, status: .queued)
        let endpoint = try endpoint(for: peer)
        let connection = try connect(to: endpoint)
        defer { connection.cancel() }

        let header = try TransferEnvelopeCodec.encode(envelope) + "\n"
        try sendData(Data(header.utf8), on: connection)

        let handle = try FileHandle(forReadingFrom: fileURL)
        defer { try? handle.close() }

        let startedAt = Date()
        var sent: Int64 = 0
        for chunk in ChunkCalculator.chunks(sizeBytes: envelope.payloadMetadata.sizeBytes, chunkSize: envelope.payloadMetadata.chunkSize) {
            if isCancelled(envelope.transferId) {
                try record(envelope: envelope, peer: peer, direction: .sent, status: .cancelled, error: BeamDropError.cancelled.localizedDescription)
                throw BeamDropError.cancelled
            }
            try handle.seek(toOffset: UInt64(chunk.offset))
            let data = try handle.read(upToCount: Int(chunk.length)) ?? Data()
            try sendData(session.map { Self.frameSealed(try $0.sealChunk(data, index: chunk.index)) } ?? data, on: connection)
            sent += Int64(data.count)
            progress?(makeProgress(envelope: envelope, peer: peer, status: .transferring, bytes: sent, startedAt: startedAt))
        }
        try finishSend(envelope: envelope, peer: peer, bytes: sent, progress: progress)
    }

    private func initiateSession(for envelope: inout TransferEnvelope, peer: TrustedPeer) throws -> SessionCrypto? {
        guard let sessionPrivateKey, let receiverStaticPublic = try? X25519PublicKeyCodec.rawKey(spkiBase64: peer.publicKey) else {
            try? auditLog.record(type: "legacy_plaintext_send", message: "Sending transfer \(envelope.transferId) to \(peer.deviceName) without session encryption.")
            return nil
        }
        let session = try SessionCrypto.initiate(
            senderStaticSecret: sessionPrivateKey,
            receiverStaticPublic: receiverStaticPublic,
            senderDeviceId: identity.deviceId,
            receiverDeviceId: peer.deviceId,
            transferId: envelope.transferId
        )
        envelope.encryption = TransferEncryption(ephemeralPublicKey: session.ephemeralPublicKey.hexEncodedString)
        return session
    }

    private func finishSend(envelope: TransferEnvelope, peer: TrustedPeer, bytes: Int64, progress: TransferProgressHandler?) throws {
        try record(envelope: envelope, peer: peer, direction: .sent, status: .completed)
        progress?(TransferProgress(
            transferId: envelope.transferId,
            status: .completed,
            bytesTransferred: bytes,
            totalBytes: envelope.payloadMetadata.sizeBytes,
            percent: 100,
            speedBytesPerSecond: 0,
            fileName: envelope.payloadMetadata.fileName,
            peerDeviceName: peer.deviceName
        ))
    }

    public func handleIncomingConnection(
        _ connection: NWConnection,
        receiveDirectory: URL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!,
        approve: ReceiveApprovalHandler? = nil,
        progress: TransferProgressHandler? = nil,
        completion: @escaping @Sendable (Result<TransferEnvelope, Error>) -> Void
    ) {
        connection.start(queue: queue)
        readHeader(connection, buffer: Data()) { [weak self] result in
            guard let self else { return }
            do {
                let header = try result.get()
                let envelope = try TransferEnvelopeCodec.decode(String(decoding: header, as: UTF8.self))
                let peer = try PeerTrustPolicy.requireTrusted(deviceId: envelope.senderDeviceId, store: self.peerStore)
                guard peer.publicKey == envelope.senderPublicKey || envelope.senderPublicKey.isEmpty else {
                    throw BeamDropError.transferRejected("Sender public key does not match trusted device.")
                }
                if !peer.autoAcceptTransfers {
                    guard approve?(envelope, peer) == true else {
                        try self.record(envelope: envelope, peer: peer, direction: .received, status: .rejected, error: "Receiver approval required.")
                        throw BeamDropError.transferRejected("Receiver approval required.")
                    }
                }
                try self.receivePayload(
                    envelope: envelope,
                    peer: peer,
                    connection: connection,
                    receiveDirectory: receiveDirectory,
                    progress: progress
                ) { result in
                    switch result {
                    case .success:
                        completion(.success(envelope))
                    case .failure(let error):
                        connection.cancel()
                        completion(.failure(error))
                    }
                }
            } catch {
                connection.cancel()
                completion(.failure(error))
            }
        }
    }

    private func receivePayload(
        envelope: TransferEnvelope,
        peer: TrustedPeer,
        connection: NWConnection,
        receiveDirectory: URL,
        progress: TransferProgressHandler?,
        completion: @escaping @Sendable (Result<Void, Error>) -> Void
    ) throws {
        try record(envelope: envelope, peer: peer, direction: .received, status: .transferring)
        let session = try acceptSession(for: envelope, peer: peer)
        if session == nil {
            try? auditLog.record(type: "legacy_plaintext_receive", message: "Received unencrypted transfer \(envelope.transferId) from \(peer.deviceName).")
        }
        let destination = envelope.transferType == .file
            ? safeDestinationURL(directory: receiveDirectory, fileName: envelope.payloadMetadata.fileName)
            : safeDestinationURL(directory: receiveDirectory, fileName: ".beamdrop-\(envelope.transferId).tmp")
        FileManager.default.createFile(atPath: destination.path, contents: nil)
        let sink = try PayloadSink(handle: FileHandle(forWritingTo: destination))
        let startedAt = Date()
        let finish: @Sendable (Result<Int64, Error>) -> Void = { [weak self] result in
            guard let self else { return }
            self.finalizeReceive(envelope: envelope, peer: peer, destination: destination, sink: sink, result: result, completion: completion)
        }
        if let session {
            let chunks = ChunkCalculator.chunks(sizeBytes: envelope.payloadMetadata.sizeBytes, chunkSize: envelope.payloadMetadata.chunkSize)
            receiveSealedChunks(connection: connection, chunks: chunks[...], session: session, sink: sink, envelope: envelope, peer: peer, startedAt: startedAt, progress: progress, completion: finish)
        } else {
            receivePlainBytes(connection: connection, remaining: envelope.payloadMetadata.sizeBytes, sink: sink, envelope: envelope, peer: peer, startedAt: startedAt, progress: progress, completion: finish)
        }
    }

    private func acceptSession(for envelope: TransferEnvelope, peer: TrustedPeer) throws -> SessionCrypto? {
        guard let encryption = envelope.encryption else { return nil }
        guard encryption.scheme == BeamDropProtocol.sessionEncryptionScheme else {
            throw BeamDropError.invalidEncryptionMetadata("Unsupported scheme \(encryption.scheme).")
        }
        guard let sessionPrivateKey else {
            throw BeamDropError.encryptionFailure("No session private key is available to decrypt this transfer.")
        }
        guard let ephemeralPublic = Data(hexEncoded: encryption.ephemeralPublicKey), ephemeralPublic.count == 32 else {
            throw BeamDropError.invalidEncryptionMetadata("ephemeralPublicKey must be 64 hex characters.")
        }
        return try SessionCrypto.accept(
            receiverStaticSecret: sessionPrivateKey,
            senderStaticPublic: try X25519PublicKeyCodec.rawKey(spkiBase64: peer.publicKey),
            ephemeralPublic: ephemeralPublic,
            senderDeviceId: envelope.senderDeviceId,
            receiverDeviceId: envelope.receiverDeviceId,
            transferId: envelope.transferId
        )
    }

    private func finalizeReceive(
        envelope: TransferEnvelope,
        peer: TrustedPeer,
        destination: URL,
        sink: PayloadSink,
        result: Result<Int64, Error>,
        completion: @escaping @Sendable (Result<Void, Error>) -> Void
    ) {
        try? sink.close()
        do {
            let received = try result.get()
            guard received == envelope.payloadMetadata.sizeBytes else {
                try record(envelope: envelope, peer: peer, direction: .received, status: .incomplete, error: "Expected \(envelope.payloadMetadata.sizeBytes) bytes, received \(received).")
                throw BeamDropError.transferRejected("Transfer incomplete.")
            }
            if let expectedHash = envelope.payloadMetadata.sha256 {
                guard try SHA256Hashing.verify(fileURL: destination, expectedHex: expectedHash) else {
                    let actual = try SHA256Hashing.hash(fileURL: destination)
                    try record(envelope: envelope, peer: peer, direction: .received, status: .corrupted, error: "SHA-256 mismatch.")
                    throw BeamDropError.hashMismatch(expected: expectedHash, actual: actual)
                }
            }
            if envelope.transferType == .text || envelope.transferType == .clipboardText {
                let text = try String(contentsOf: destination, encoding: .utf8)
                try? FileManager.default.removeItem(at: destination)
                try record(envelope: envelope, peer: peer, direction: .received, status: .completed)
                try auditLog.record(type: "receive_text", message: "Received text from \(peer.deviceName): \(text.prefix(80))")
            } else {
                try record(envelope: envelope, peer: peer, direction: .received, status: .completed)
            }
            completion(.success(()))
        } catch {
            if case BeamDropError.encryptionFailure = error {
                try? record(envelope: envelope, peer: peer, direction: .received, status: .failed, error: error.localizedDescription)
            }
            completion(.failure(error))
        }
    }

    private func receiveSealedChunks(
        connection: NWConnection,
        chunks: ArraySlice<ChunkMetadata>,
        session: SessionCrypto,
        sink: PayloadSink,
        envelope: TransferEnvelope,
        peer: TrustedPeer,
        startedAt: Date,
        progress: TransferProgressHandler?,
        completion: @escaping @Sendable (Result<Int64, Error>) -> Void
    ) {
        guard let chunk = chunks.first else {
            completion(.success(sink.totalBytes))
            return
        }
        readExactly(connection, count: MemoryLayout<UInt32>.size, buffer: Data()) { [weak self] headerResult in
            guard let self else { return }
            do {
                let sealedLength = try Self.sealedFrameLength(fromHeader: headerResult.get())
                let expectedLength = Int(chunk.length) + SessionCrypto.sealedOverheadBytes
                guard sealedLength == expectedLength else {
                    throw BeamDropError.encryptionFailure("Sealed chunk \(chunk.index) frame is \(sealedLength) bytes but the manifest expects \(expectedLength).")
                }
                self.readExactly(connection, count: sealedLength, buffer: Data()) { [weak self] result in
                    guard let self else { return }
                    do {
                        let plaintext = try session.openChunk(result.get(), index: chunk.index)
                        let total = try sink.write(plaintext)
                        progress?(self.makeProgress(envelope: envelope, peer: peer, status: .transferring, bytes: total, startedAt: startedAt))
                        self.receiveSealedChunks(connection: connection, chunks: chunks.dropFirst(), session: session, sink: sink, envelope: envelope, peer: peer, startedAt: startedAt, progress: progress, completion: completion)
                    } catch {
                        completion(.failure(error))
                    }
                }
            } catch {
                completion(.failure(error))
            }
        }
    }

    /// Cross-platform sealed frame: bigEndian32(sealedLength) || sealed bytes.
    static func frameSealed(_ sealed: Data) -> Data {
        var frame = withUnsafeBytes(of: UInt32(sealed.count).bigEndian) { Data($0) }
        frame.append(sealed)
        return frame
    }

    static func sealedFrameLength(fromHeader header: Data) throws -> Int {
        guard header.count == MemoryLayout<UInt32>.size else {
            throw BeamDropError.encryptionFailure("Sealed chunk frame header is truncated.")
        }
        return Int(header.withUnsafeBytes { $0.load(as: UInt32.self) }.bigEndian)
    }

    private func receivePlainBytes(
        connection: NWConnection,
        remaining: Int64,
        sink: PayloadSink,
        envelope: TransferEnvelope,
        peer: TrustedPeer,
        startedAt: Date,
        progress: TransferProgressHandler?,
        completion: @escaping @Sendable (Result<Int64, Error>) -> Void
    ) {
        guard remaining > 0 else {
            completion(.success(sink.totalBytes))
            return
        }
        let maxLength = Int(min(BeamDropProtocol.defaultChunkSizeBytes, remaining))
        connection.receive(minimumIncompleteLength: 1, maximumLength: maxLength) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            if let error {
                completion(.failure(error))
                return
            }
            guard let data, !data.isEmpty else {
                if isComplete {
                    completion(.success(sink.totalBytes))
                } else {
                    completion(.failure(BeamDropError.transferRejected("Connection closed during payload.")))
                }
                return
            }
            do {
                let total = try sink.write(data)
                progress?(self.makeProgress(envelope: envelope, peer: peer, status: .transferring, bytes: total, startedAt: startedAt))
                let nextRemaining = remaining - Int64(data.count)
                if nextRemaining > 0 {
                    self.receivePlainBytes(connection: connection, remaining: nextRemaining, sink: sink, envelope: envelope, peer: peer, startedAt: startedAt, progress: progress, completion: completion)
                } else {
                    completion(.success(total))
                }
            } catch {
                completion(.failure(error))
            }
        }
    }

    private func readExactly(_ connection: NWConnection, count: Int, buffer: Data, completion: @escaping @Sendable (Result<Data, Error>) -> Void) {
        guard buffer.count < count else {
            completion(.success(buffer))
            return
        }
        connection.receive(minimumIncompleteLength: 1, maximumLength: count - buffer.count) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            if let error {
                completion(.failure(error))
                return
            }
            guard let data, !data.isEmpty else {
                completion(.failure(BeamDropError.transferRejected("Connection closed during payload.")))
                return
            }
            var next = buffer
            next.append(data)
            if next.count >= count {
                completion(.success(next))
            } else if isComplete {
                completion(.failure(BeamDropError.transferRejected("Connection closed during payload.")))
            } else {
                self.readExactly(connection, count: count, buffer: next, completion: completion)
            }
        }
    }

    private func connect(to endpoint: TransferEndpoint) throws -> NWConnection {
        let port = NWEndpoint.Port(rawValue: UInt16(endpoint.port))!
        let connection = NWConnection(host: NWEndpoint.Host(endpoint.host), port: port, using: .tcp)
        let semaphore = DispatchSemaphore(value: 0)
        var connectionError: Error?
        connection.stateUpdateHandler = { state in
            switch state {
            case .ready:
                semaphore.signal()
            case .failed(let error):
                connectionError = error
                semaphore.signal()
            default:
                break
            }
        }
        connection.start(queue: queue)
        if semaphore.wait(timeout: .now() + 10) == .timedOut {
            connection.cancel()
            throw BeamDropError.networkUnavailable("Timed out connecting to \(endpoint.host):\(endpoint.port).")
        }
        if let connectionError {
            connection.cancel()
            throw connectionError
        }
        return connection
    }

    private func sendData(_ data: Data, on connection: NWConnection) throws {
        let semaphore = DispatchSemaphore(value: 0)
        var sendError: Error?
        connection.send(content: data, completion: .contentProcessed { error in
            sendError = error
            semaphore.signal()
        })
        semaphore.wait()
        if let sendError { throw sendError }
    }

    private func readHeader(_ connection: NWConnection, buffer: Data, completion: @escaping @Sendable (Result<Data, Error>) -> Void) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 1) { data, _, isComplete, error in
            if let error {
                completion(.failure(error))
                return
            }
            guard let data, !data.isEmpty else {
                if isComplete {
                    completion(.failure(BeamDropError.transferRejected("Connection closed before transfer envelope.")))
                } else {
                    self.readHeader(connection, buffer: buffer, completion: completion)
                }
                return
            }
            if data == Data([0x0A]) {
                completion(.success(buffer))
                return
            }
            var next = buffer
            next.append(data)
            if next.count > 64 * 1024 {
                completion(.failure(BeamDropError.transferRejected("Transfer envelope is too large.")))
                return
            }
            self.readHeader(connection, buffer: next, completion: completion)
        }
    }

    private func requireSendAllowed(_ peer: TrustedPeer) throws {
        _ = try PeerTrustPolicy.requireTrusted(deviceId: peer.deviceId, store: peerStore)
    }

    private func endpoint(for peer: TrustedPeer) throws -> TransferEndpoint {
        guard let host = peer.endpointHost, let port = peer.endpointPort else {
            throw BeamDropError.networkUnavailable("No endpoint is known for \(peer.deviceName). Pair again with QR or use manual connection.")
        }
        return TransferEndpoint(host: host, port: port)
    }

    private func record(envelope: TransferEnvelope, peer: TrustedPeer, direction: TransferDirection, status: TransferStatus, error: String? = nil) throws {
        try historyStore.upsert(TransferRecord(
            transferId: envelope.transferId,
            direction: direction,
            peerDeviceId: peer.deviceId,
            peerDeviceName: peer.deviceName,
            fileName: envelope.payloadMetadata.fileName,
            transferType: envelope.transferType,
            sizeBytes: envelope.payloadMetadata.sizeBytes,
            status: status,
            errorMessage: error,
            completedAt: status == .completed || status == .failed || status == .cancelled || status == .rejected || status == .corrupted ? Date() : nil
        ))
    }

    private func makeProgress(envelope: TransferEnvelope, peer: TrustedPeer, status: TransferStatus, bytes: Int64, startedAt: Date) -> TransferProgress {
        let elapsed = max(0.001, Date().timeIntervalSince(startedAt))
        return TransferProgress(
            transferId: envelope.transferId,
            status: status,
            bytesTransferred: bytes,
            totalBytes: envelope.payloadMetadata.sizeBytes,
            percent: ProgressCalculator.percent(bytesTransferred: bytes, totalBytes: envelope.payloadMetadata.sizeBytes),
            speedBytesPerSecond: Double(bytes) / elapsed,
            fileName: envelope.payloadMetadata.fileName,
            peerDeviceName: peer.deviceName
        )
    }

    private func isCancelled(_ transferId: String) -> Bool {
        lock.withLock { cancelledTransferIds.contains(transferId) }
    }

    private func safeDestinationURL(directory: URL, fileName: String) -> URL {
        let scalars = fileName
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: "\\", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .unicodeScalars
            .filter { !CharacterSet.controlCharacters.contains($0) }
        let sanitized = String(String.UnicodeScalarView(scalars))
        var candidate = directory.appendingPathComponent(sanitized)
        let ext = candidate.pathExtension
        let base = candidate.deletingPathExtension().lastPathComponent
        var counter = 1
        while FileManager.default.fileExists(atPath: candidate.path) {
            let nextName = ext.isEmpty ? "\(base) \(counter)" : "\(base) \(counter).\(ext)"
            candidate = directory.appendingPathComponent(nextName)
            counter += 1
        }
        return candidate
    }
}

private final class PayloadSink: @unchecked Sendable {
    private let lock = NSLock()
    private let handle: FileHandle
    private var bytesWritten: Int64 = 0

    init(handle: FileHandle) {
        self.handle = handle
    }

    var totalBytes: Int64 {
        lock.withLock { bytesWritten }
    }

    func write(_ data: Data) throws -> Int64 {
        try lock.withLock {
            try handle.write(contentsOf: data)
            bytesWritten += Int64(data.count)
            return bytesWritten
        }
    }

    func close() throws {
        try lock.withLock { try handle.close() }
    }
}

private extension NSLock {
    func withLock<T>(_ body: () throws -> T) rethrows -> T {
        lock()
        defer { unlock() }
        return try body()
    }
}
