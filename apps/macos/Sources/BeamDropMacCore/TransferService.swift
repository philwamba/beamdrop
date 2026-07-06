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
}

public typealias TransferProgressHandler = @Sendable (TransferProgress) -> Void
public typealias ReceiveApprovalHandler = @Sendable (TransferEnvelope, TrustedPeer) -> Bool

public final class TransferService {
    private let identity: DeviceIdentity
    private let peerStore: TrustedPeerStore
    private let historyStore: TransferHistoryStore
    private let auditLog: AuditLog
    private let queue = DispatchQueue(label: "com.beamdrop.mac.transfer")
    private var cancelledTransferIds = Set<String>()
    private let lock = NSLock()

    public init(
        identity: DeviceIdentity,
        peerStore: TrustedPeerStore,
        historyStore: TransferHistoryStore,
        auditLog: AuditLog
    ) {
        self.identity = identity
        self.peerStore = peerStore
        self.historyStore = historyStore
        self.auditLog = auditLog
    }

    public func cancel(transferId: String) {
        lock.withLock { cancelledTransferIds.insert(transferId) }
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
        try record(envelope: envelope, peer: peer, direction: .sent, status: .queued)
        let endpoint = try endpoint(for: peer)
        let connection = try connect(to: endpoint)
        defer { connection.cancel() }

        let header = try TransferEnvelopeCodec.encode(envelope) + "\n"
        try sendData(Data(header.utf8), on: connection)
        try sendData(data, on: connection)
        try finishSend(envelope: envelope, peer: peer, bytes: Int64(data.count), progress: progress)
    }

    private func send(fileURL: URL, envelope: TransferEnvelope, to peer: TrustedPeer, progress: TransferProgressHandler?) throws {
        try requireSendAllowed(peer)
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
        for chunk in ChunkCalculator.chunks(sizeBytes: envelope.payloadMetadata.sizeBytes) {
            if isCancelled(envelope.transferId) {
                try record(envelope: envelope, peer: peer, direction: .sent, status: .cancelled, error: BeamDropError.cancelled.localizedDescription)
                throw BeamDropError.cancelled
            }
            try handle.seek(toOffset: UInt64(chunk.offset))
            let data = try handle.read(upToCount: Int(chunk.length)) ?? Data()
            try sendData(data, on: connection)
            sent += Int64(data.count)
            progress?(makeProgress(envelope: envelope, peer: peer, status: .transferring, bytes: sent, startedAt: startedAt))
        }
        try finishSend(envelope: envelope, peer: peer, bytes: sent, progress: progress)
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
        readHeader(connection: connection, buffer: Data()) { [weak self] result in
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
                )
                completion(.success(envelope))
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
        progress: TransferProgressHandler?
    ) throws {
        try record(envelope: envelope, peer: peer, direction: .received, status: .transferring)
        let destination = envelope.transferType == .file
            ? safeDestinationURL(directory: receiveDirectory, fileName: envelope.payloadMetadata.fileName)
            : receiveDirectory.appendingPathComponent(".beamdrop-\(envelope.transferId).tmp")
        FileManager.default.createFile(atPath: destination.path, contents: nil)
        let handle = try FileHandle(forWritingTo: destination)
        let group = DispatchGroup()
        var received: Int64 = 0
        var receiveError: Error?
        let startedAt = Date()
        group.enter()
        receiveBytes(connection: connection, remaining: envelope.payloadMetadata.sizeBytes) { chunk, done, error in
            if let error {
                receiveError = error
                group.leave()
                return
            }
            if let chunk, !chunk.isEmpty {
                do {
                    try handle.write(contentsOf: chunk)
                    received += Int64(chunk.count)
                    progress?(self.makeProgress(envelope: envelope, peer: peer, status: .transferring, bytes: received, startedAt: startedAt))
                } catch {
                    receiveError = error
                }
            }
            if done {
                group.leave()
            }
        }
        group.wait()
        try handle.close()
        if let receiveError { throw receiveError }
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

    private func receiveBytes(
        connection: NWConnection,
        remaining: Int64,
        onChunk: @escaping @Sendable (Data?, Bool, Error?) -> Void
    ) {
        guard remaining > 0 else {
            onChunk(nil, true, nil)
            return
        }
        let maxLength = Int(min(BeamDropProtocol.defaultChunkSizeBytes, remaining))
        connection.receive(minimumIncompleteLength: 1, maximumLength: maxLength) { data, _, isComplete, error in
            if let error {
                onChunk(nil, true, error)
                return
            }
            guard let data, !data.isEmpty else {
                onChunk(nil, isComplete, isComplete ? nil : BeamDropError.transferRejected("Connection closed during payload."))
                return
            }
            let nextRemaining = remaining - Int64(data.count)
            onChunk(data, nextRemaining == 0, nil)
            if nextRemaining > 0 {
                self.receiveBytes(connection: connection, remaining: nextRemaining, onChunk: onChunk)
            }
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
        let sanitized = fileName
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
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

private extension NSLock {
    func withLock<T>(_ body: () throws -> T) rethrows -> T {
        lock()
        defer { unlock() }
        return try body()
    }
}
